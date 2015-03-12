(ns io.pivotal.pcf.rabbitmq.config
  (:require [clj-yaml.core :as yaml]
            [clojure.data.json :as json]
            [validateur.validation :as vdt :refer [validation-set
                                                   presence-of
                                                   inclusion-of
                                                   validate-with-predicate]]
            [io.pivotal.pcf.rabbitmq.constants :refer [management-ui-port]]))

;;
;; Implementation
;;

(def ^:const service-uuid "163b47c6-a2f3-43b1-97f7-b83b37ec8ad3")
(def pcf-product-cost {:amount {:usd  0.0}
                       :unit "MONTHLY"})

(defn ^:private present-and-non-empty?
  [v]
  (not (empty? (or v []))))

(def config-validator
  (let [missing-msg "must be present"]
    (validation-set
     ;; CC
     (presence-of :cc_endpoint :message missing-msg)
     ;; PID file location
     (presence-of :pid :message missing-msg)
     ;; logging
     (presence-of [:logging :level] :message missing-msg)
     (inclusion-of [:logging :level] :in #{"debug" "info" "warn" "error" "fatal"})
     ;; UAA authentication
     (presence-of [:uaa_client :username] :message missing-msg)
     (presence-of [:uaa_client :password] :message missing-msg)
     (presence-of [:uaa_client :client_id] :message missing-msg)
     ;; CC/broker authentication
     (presence-of [:service :username] :message missing-msg)
     (presence-of [:service :password] :message missing-msg)
     ;; public management UI route
     (presence-of [:rabbitmq :management_domain] :message missing-msg)
     ;; rabbitmq info
     (presence-of [:rabbitmq :hosts] :message missing-msg)
     (validate-with-predicate [:rabbitmq :hosts] present-and-non-empty? :message "must have at least one entry")
     (presence-of [:rabbitmq :administrator :username] :message missing-msg)
     (presence-of [:rabbitmq :administrator :password] :message missing-msg))))

(def ^{:private true} final-config)

;;
;; API
;;

(defn init!
  [m]
  (alter-var-root #'final-config (constantly m)))

(defn valid?
  "Returns true if provided configuration is valid, false otherwise"
  [m]
  (vdt/valid? config-validator m))

(defn validate
  "Validates provided configuration, returning a map of errors
   (attribute name to a set of error messages)"
  [m]
  (config-validator m))

(defn from-path
  "Loads config from specified local file system path"
  [^String path]
  (yaml/parse-string (slurp path)))

(defn serializable-config
  []
  (dissoc final-config :cf-client))

(defn log-level
  [m]
  (get-in m [:logging :level] "info"))

(defn print-stack-traces?
  [m]
  (true? (get-in m [:logging :print_stack_traces] false)))

(defn ^String pid-path
  [m]
  (get m :pid))

(defn ^String cc-endpoint
  [m]
  (get m :cc_endpoint))

(defn ^String uaa-client-id
  [m]
  (get-in m [:uaa_client :client_id]))

(defn ^String uaa-username
  [m]
  (get-in m [:uaa_client :username]))

(defn ^String uaa-password
  [m]
  (get-in m [:uaa_client :password]))

(defn service-info
  [m]
  (let [svs           (get m :service)
        long-desc     "RabbitMQ is a robust and scalable high-performance multi-protocol messaging broker."
        ;; displayed in Console
        img-url       "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAACXBIWXMAAAsTAAALEwEAmpwYAAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAABDdJREFUeNrsW01oE1EQfgk5NKeN3sRDo/QkSKOFeijYgB4UhAbRi0Ibf29tUwXBS0l7ETxI2rs2FfSi1C0WvKhsxR4s1CZnizZg661uT/Ug1Jl2Ul7S3e3uZl92s8+BYdltuvvmm5nvzfuLbG9vM5klJvwDD4eTcElxmqCrUvfTTdASqE7XHf37aGJVZPsiIiIAjEYDs6AZ0PYGX1cG1UCLAEYpsACA0QkyOO+B0VZgFEBVAEMPBABkeI5UaVLqYroUAIS8rwCA8RnySDvzRyoIPAChNhUA8noRtC8gZD6LnOMmLRwDQASn+uh1q2jIOCXKqEPjkdmXA2g8ozZp1EbvI4BePNUi9c0NiISiZxHQYsajTNmNhGgIjXcEgmUKEOEtt3i5f8qKGE0BoK5utYnFjciiKWnWRVqlgBoC4xnZUHTEAZQ7vSEa9fZR1XpwCoQo9G2lgtF8gKNBTaItzmb6b7OzxzoM//786yK7+erF3v1A1xnQbsPfjrydYeVfayJTIUejVeMIcOP93uMd7MOdQVbRN1jl90bN3zqPHGUKAATv3btfGnpg7qI/W6xr8jFbrXuPyCiINeJ9XqaXFtn4+3c1zz7eHayJjEQ8vnOdXJhn9+Zman775NJlNtTTy9oPHRYJwL4oiBoAIFx08LSdZ4Ika9gLEEuGjfgMB018j8BHQIbJI/8BqAGAan5FIgAUsnkvAtJMPknzAKQkBCDF1wFJkV8aPX9x9yPQxwdIkjwAQgc+o+cu2P4tVpV25Nbrl1B8ffEsAoQI1vbV6o+XikGlh88+/Vix9V4sqZ9eucZK6z8bGTsowgFw0jj0pl2PYkphVBmB61Si1e5AVsFeICE1ADA01GQGIBakxiC51ef1/PcVOQAwmyy5P/eGTSxowgHAjQedfgJQ9Xx19ggFJ1QUD5jeROb5UliXMP11HgAZibDEp0ApKK3CsOd5QRNHghoPgO8RgGyPhMfnPBo/+VlM06rdf4xudCAf3Gbi65YXkWxfJ7N8JVgVVaL8V2UGYNMQAFotmZbB+1YrQ3nQATdvzZw4CUT2TXzB1BZnwz0Nzd/k+Ruj1WHVKRk+u3qd9Z/ubqob6xdd7U47gPezB40Fck4BwIaU19dElq21Sby15bbHyNc/MNwiA1GA21+HQ5b7Y0Z7i6MWSFVCZDzaUjCcEDGpkpAlw7RUlnG8SYq2lo2EwPgRV9vkOD4ouu0aAyD7WN92BHCRkG3RAulA420B0KIg2DLeNgAtBoJt4x0BwIEwFnDCyzr5B7dHZtJsd/tpUA5OYD+fdbPGEXXzNfoQLqlNBMB4bEPK7QKPF8fm0lQ5NntvMU5r5xo9TOnlwcm0m4GUC8HprIJXS3qeH52ls8JYRiMZebXYUibOUb0+SxwReXqcwEiTJh2kCYY3Gope1kQeoI74cXye0sWMXJsq/wQYAC3YsLNLNOCbAAAAAElFTkSuQmCC"
        provider-name "Pivotal"]
    {:id          service-uuid
     :name        "p-rabbitmq"
     :description long-desc
     :bindable    true
     :requires    []
     :tags        ["rabbitmq" "messaging" "message-queue" "amqp" "stomp" "mqtt" "pivotal"]
     :metadata    {"displayName"         "RabbitMQ for Pivotal CF"
                   "longDescription"     long-desc
                   "imageUrl"            img-url
                   ;; backwards compatibility
                   "listing"             {"blurb"    long-desc
                                          "imageUrl" img-url}
                   "providerDisplayName" provider-name
                   "documentationUrl"    "http://docs.pivotal.io"
                   "supportUrl"          "https://support.pivotal.io"
                   "provider"            {"name" provider-name}}
     :plans       [{:id "4e816145-4e71-4e24-a402-0c686b868e2d"
                    :name "standard"
                    :description "Provides a multi-tenant RabbitMQ cluster, suitable for production workloads"
                    :metadata    {"displayName" "Production"
                                  "costs"       [pcf-product-cost]
                                  "bullets"     ["RabbitMQ 3.3.5" "Multi-tenant"]}}]}))

(defn using-tls?
  ([]
     (using-tls? final-config))
  ([m]
     (not (not (or (get-in m [:rabbitmq :ssl])
                   (get-in m [:rabbitmq :tls]))))))

(defn operator-set-policy-enabled?
  ([]
   (operator-set-policy-enabled? final-config))
  ([m]
   (true? (get-in m [:rabbitmq :operator_set_policy :enabled] false))))

(defn operator-set-policy-name
  ([]
   (operator-set-policy-name final-config))
  ([m]
   (get-in m [:rabbitmq :operator_set_policy :policy_name] "operator_set_policy")))

(defn operator-set-policy-definition
  ([]
    (operator-set-policy-definition final-config))
  ([m]
    (try
      (json/read-str
        (get-in m [:rabbitmq :operator_set_policy :policy_definition])
        :key-fn keyword)
      (catch Exception e
        (.printStackTrace e)))))

(defn operator-set-policy-priority
  ([]
   (operator-set-policy-priority final-config))
  ([m]
   (get-in m [:rabbitmq :operator_set_policy :policy_priority] 50)))

(defn management-domain
  ([]
     (management-domain final-config))
  ([m]
     (get-in m [:rabbitmq :management_domain])))

(defn authenticated?
  ([^String username ^String password]
     (authenticated? final-config username password))
  ([m ^String username ^String password]
     (let [u (get-in m [:service :username])
           p (get-in m [:service :password])]
       (and (= u username)
            (= p password)))))


(defn ^String http-scheme
  ([]
     (http-scheme final-config))
  ([m]
     (if (using-tls? m)
       "https"
       "http")))

(defn ^String amqp-scheme
  ([]
     (amqp-scheme final-config))
  ([m]
     (if (using-tls? m)
       "amqps"
       "amqp")))

(defn rabbitmq-administrator
  ([]
     (rabbitmq-administrator final-config))
  ([m]
     (get-in m [:rabbitmq :administrator :username])))

(defn rabbitmq-administrator-password
  ([]
     (rabbitmq-administrator-password final-config))
  ([m]
     (get-in m [:rabbitmq :administrator :password])))

(defn node-hosts
  ([]
     (node-hosts final-config))
  ([m]
     (vec (get-in m [:rabbitmq :hosts]))))


(defn rabbitmq-administrator-uris
  ([]
     (rabbitmq-administrator-uris final-config))
  ([m]
     (let [scheme (http-scheme m)]
       (mapv
          (fn
            [host]
            (format "%s://%s:%d" scheme host management-ui-port))
          (node-hosts m)))))
