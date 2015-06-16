(ns io.pivotal.pcf.rabbitmq.server
  (:require [taoensso.timbre :as log]
            [io.pivotal.pcf.rabbitmq.config :as cfg]
            [io.pivotal.pcf.rabbitmq.resources :as rs]
            [clojure.java.io :as io]
            beckon
            [ring.adapter.jetty9 :refer [run-jetty]]
            [compojure.core :refer [defroutes GET PUT DELETE]]
            [compojure.route :as rt]
            [ring.util.response :refer [response status]]
            [cheshire.core :as json]
            [ring.middleware.json :refer [wrap-json-response]]
            [ring.middleware.basic-authentication :refer [wrap-basic-authentication]]
            [langohr.http :as hc])
  (:import java.io.File
           java.lang.management.ManagementFactory))

;;
;; Implementation
;;

(defn ^{:private true} log-exception
  [config ^Exception e]
  (log/errorf "Caught an exception during boot: %s (%s)" (.getMessage e) (.getClass e))
  (when (cfg/print-stack-traces? config)
    (.printStackTrace e))
  e)

(defn initialize-logger
  [config]
  (log/set-level! (keyword (cfg/log-level config))))

(defn own-pid
  "Returns PID of the current OS process"
  []
  (let [^String name (-> (ManagementFactory/getRuntimeMXBean) .getName)]
    (Long/valueOf ^String (first (.split name "@")))))

(defn drop-pid
  "Writes PID of the current OS process to file at path.
   The file will be created if it does not exists."
  [^String path]
  (let [f  (File. path)]
    (with-open [wr (io/writer f)]
      (doto f
        .createNewFile
        .deleteOnExit)
      (.write wr (String/valueOf (own-pid))))))

(defn announce-start
  [config]
  (log/infof "Starting. PID: %s, PID path: %s, CC endpoint: %s, UAA username: %s"
             (own-pid)
             (cfg/pid-path config)
             (cfg/cc-endpoint config)
             (cfg/uaa-username config)))

(defn log-if-using-tls
  [config]
  (if (cfg/using-tls? config)
    (log/infof "Will use HTTPS to talk to RabbitMQ HTTP API as %s..." (cfg/rabbitmq-administrator))
    (log/infof "Will use HTTP (not HTTPS) to talk to RabbitMQ HTTP API as %s..." (cfg/rabbitmq-administrator))))

(declare shutdown)
(defn install-signal-traps
  []
  (let [xs #{shutdown}]
    (reset! (beckon/signal-atom "INT")  xs)
    (reset! (beckon/signal-atom "TERM") xs)))

(def catalog {:services [{:name "p-rabbitmq"
                          :provider "pivotal"
                          :description "RabbitMQ version 3.3.x"
                          :tags ["rabbitmq" "rabbit" "messaging" "message-queue" "amqp"]}]})

(defn init-catalog!
  [config]
  (let [svs (cfg/service-info config)]
    (alter-var-root #'catalog (constantly {:services [svs]}))
    config))

(defn init-rabbitmq-connection!
  [config]
  (let [uri    (get (cfg/rabbitmq-administrator-uris config) 0)
        uname  (cfg/rabbitmq-administrator config)
        pwd    (cfg/rabbitmq-administrator-password config)
        opts   (if (cfg/using-tls?)
                 ;; don't perform peer verification with RabbitMQ nodes
                 {:insecure? true}
                 {})]
    (hc/connect! uri uname pwd opts)))

(defn wrap-request-logging
  [f]
  (fn [{:keys [request-method uri] :as req}]
    (let [start (System/currentTimeMillis)
          res   (f req)
          end   (System/currentTimeMillis)
          t     (- end start)]
      (log/infof "%s %s %d %d (in %d ms)"
                 (.toUpperCase ^String (name request-method))
                 uri
                 (:status res)
                 (count (:body res))
                 t)
      res)))

(defmacro defresponder
  "Defines a response helper function that has 2 arities:

   * 0-arity responds with an empty body
   * 1-arity responds with the argument as body"
  [name status]
  `(defn ~name
     ([]
        (~name {}))
     ([body#]
        (-> (response body#)
            (status ~status)))))

(defresponder ok             200)
(defresponder created        201)
(defresponder bad-request    400)
(defresponder conflict       409)
(defresponder gone           410)
(defresponder internal-error 500)

;;
;; Routes
;;

(defn show-catalog
  [req]
  (response catalog))

(defn create-service
  [{:keys [params] :as req}]
  ;; (slurp (:body req)) provides access to:
  ;;  * service_id
  ;;  * plan_id
  ;;  * organization_guid
  ;;  * space_guid
  (log/infof "Asked to provision a service: %s" (:id params))
  (if-let [^String id (:id params)]
    (if (rs/vhost-exists? id)
      (do (log/warnf "Vhost %s already exists" id)
          (conflict))
      (let [[mu mp] (rs/generate-credentials "mu" id)]
        (try
          (rs/add-vhost id)
          (log/infof "Created vhost %s" id)
          (rs/add-user mu mp)
          (rs/grant-permissions mu id)
          (log/infof "Created special user for dashboard access: %s" mu)
          (rs/grant-broker-administrator-permissions id)
          (log/infof "Granted system administrator access to vhost %s" id)
          (if (cfg/operator-set-policy-enabled?) (rs/add-operator-set-policy id))
          (catch Exception e
            (.printStackTrace e)
            (log-exception e)
            (rs/delete-vhost id)
            (rs/delete-user mu mp)))
        (created {:dashboard_url (rs/dashboard-url (cfg/http-scheme))})))
    (conflict)))

(defn delete-service
  [{:keys [params] :as req}]
  (log/infof "Asked to deprovision a service: %s" (:id params))
  (if-let [^String id (:id params)]
    (if (rs/vhost-exists? id)
      (do (rs/delete-vhost id)
          (log/infof "Deleted vhost %s" id)
          (ok))
      (do (log/warnf "Vhost %s does not exist" id)
          (gone)))
    (gone)))

(defn bind-service
  [{:keys [params] :as req}]
  ;; (slurp (:body req)) provides access to:
  ;;  * service_id
  ;;  * plan_id
  ;;  * app_guid
  (log/infof "Asked to bind service %s, RabbitMQ user id: %s" (:instance_id params) (:id params))
  (let [^String virtual-host (:instance_id params) ; Instance ID in CF = Virtual Host ID in Rabbit
        ^String user-id  (:id params)]             ; Binding ID in CF = User ID in Rabbit
    (if (and virtual-host user-id (rs/vhost-exists? virtual-host))
      (if (rs/user-exists? user-id)
        (conflict)
        (let [password (rs/generate-password)]
          (try
            (rs/add-user user-id password)
            (rs/grant-permissions user-id virtual-host)
            (ok {:credentials (rs/credentials-for (cfg/node-hosts)
                                                  virtual-host
                                                  user-id
                                                  password
                                                  (rs/protocol-ports)
                                                  (cfg/using-tls?))})
            (catch Exception e
              (log/errorf "Failed to grant user %s permissions to vhost %s: %s" user-id virtual-host (.getMessage e))
              (rs/delete-user user-id)
              (internal-error)))))
      (gone))))

(defn unbind-service
  [{:keys [params] :as req}]
  (log/infof "Asked to unbind service %s, RabbitMQ user id: %s" (:instance_id params) (:id params))
  (let [^String vh (:instance_id params)
        ^String u  (:id params)]
    (if (and vh u)
      (let [xs (rs/close-connections-from u)]
        (rs/delete-user u)
        (log/infof "Deleted use %s" u)
        (log/infof "Forcing connections from %s to close" u)
        (rs/close-connections-from u)
        (log/infof "Force-closed %d connections" (count xs))
        (ok))
      (gone))))

(defn show-raw-config
  [_]
  (let [pretty-printed (json/generate-string (cfg/serializable-config) {:pretty true})]
    (ok pretty-printed)))

(defn show-cf-api-version
  [_]
  (ok "2.0"))

(defroutes broker-v2-routes
  (GET    "/v2/catalog"               req show-catalog)
  (PUT    "/v2/service_instances/:id" req create-service)
  (DELETE "/v2/service_instances/:id" req delete-service)
  (PUT    "/v2/service_instances/:instance_id/service_bindings/:id" req bind-service)
  (DELETE "/v2/service_instances/:instance_id/service_bindings/:id" req unbind-service)
  (GET    "/ops/config"               req show-raw-config)
  (GET    "/ops/cf/api/version"       req show-cf-api-version))

(defn start-http-server
  [config]
  (run-jetty (-> broker-v2-routes
                 wrap-json-response
                 (wrap-basic-authentication cfg/authenticated?)
                 wrap-request-logging)
             {:port 4567
              :join? false}))

;;
;; API
;;

(defn start
  [config]
  (initialize-logger config)
  (drop-pid (cfg/pid-path config))
  (announce-start config)
  (install-signal-traps)
  (init-catalog! config)
  (log/infof "Initialized service catalog")
  (cfg/init! config)
  (log/infof "Finalized own configuration")
  (log-if-using-tls config)
  (init-rabbitmq-connection! config)
  (start-http-server config))

(defn shutdown
  []
  (log/infof "Asked to shut down...")
  (System/exit 0))
