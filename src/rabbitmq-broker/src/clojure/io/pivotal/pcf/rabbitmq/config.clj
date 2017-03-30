(ns io.pivotal.pcf.rabbitmq.config

  (:require [clj-yaml.core :as yaml]
            [clojure.data.json :as json]
            [clojure.string :as string]
            [validateur.validation :as vdt :refer [validation-set
                                                   presence-of
                                                   inclusion-of
                                                   validate-with-predicate]]
            [io.pivotal.pcf.rabbitmq.constants :refer [management-ui-port]]))

;;
;; Implementation
;;

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
     ;; logging
     (presence-of [:logging :level] :message missing-msg)
     (inclusion-of [:logging :level] :in #{"debug" "info" "warn" "error" "fatal"})
     ;; CC/broker authentication
     (presence-of [:service :username] :message missing-msg)
     (presence-of [:service :password] :message missing-msg)
     ;; Broker catalog
     (presence-of [:service :name] :message missing-msg)
     (presence-of [:service :uuid] :message missing-msg)
     (presence-of [:service :plan_uuid] :message missing-msg)
     ;; public management UI route
     (presence-of [:rabbitmq :management_domain] :message missing-msg)
     ;; rabbitmq info
     (presence-of [:rabbitmq :hosts] :message missing-msg)
     (presence-of [:rabbitmq :regular_user_tags] :message missing-msg)
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

(defn ^String cc-endpoint
  [m]
  (get m :cc_endpoint))

(defn service-info
  [m]
  (let [svs           (get m :service)
        service-uuid  (get-in m [:service :uuid])
        service-name  (get-in m [:service :name])
        desc          (get-in m [:service :offering_description])
        plan-uuid     (get-in m [:service :plan_uuid])
        display-name  (get-in m [:service :display_name])
        long-desc     (get-in m [:service :long_description])
        ;; displayed in Console
        img-url       (string/join "," ["data:image/png;base64" (get-in m [:service :icon_image])])
        provider-name (get-in m [:service :provider_display_name])
        documentation-url (get-in m [:service :documentation_url])
        support-url (get-in m [:service :support_url])
        ]
    {:id          service-uuid
     :name        service-name
     :description desc
     :bindable    true
     :requires    []
     :tags        ["rabbitmq" "messaging" "message-queue" "amqp" "stomp" "mqtt" "pivotal"]
     :metadata    {"displayName"         display-name
                   "longDescription"     long-desc
                   "imageUrl"            img-url
                   ;; backwards compatibility
                   "listing"             {"blurb"    long-desc
                                          "imageUrl" img-url}
                   "providerDisplayName" provider-name
                   "documentationUrl"    documentation-url
                   "supportUrl"          support-url }
     :plans       [{:id plan-uuid
                    :name "standard"
                    :description "Provides a multi-tenant RabbitMQ cluster"
                    :metadata    {"displayName" "Standard"
                                  "costs"       [pcf-product-cost]
                                  "bullets"     ["RabbitMQ 3.6.9" "Multi-tenant"]}}]}))

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
     (if (using-tls? m) "amqps" "amqp")))

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
    (if-let [dns-host (get-in m [:rabbitmq :dns_host])]
      [dns-host]
      (vec (get-in m [:rabbitmq :hosts])))))

(defn rabbitmq-administrator-uris
  ([]
     (rabbitmq-administrator-uris final-config))
  ([m]
     (mapv
       #(format "http://%s:%d" % management-ui-port)
       (node-hosts m))))

(defn regular-user-tags
  ([]
    (regular-user-tags final-config))
  ([m]
    (get-in m [:rabbitmq :regular_user_tags])))
