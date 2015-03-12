(ns io.pivotal.pcf.rabbitmq.resources
  (:require [langohr.http :as hc]
            [taoensso.timbre :as log]
            [io.pivotal.pcf.rabbitmq.config :as cfg]
            [io.pivotal.pcf.rabbitmq.gen :as gen]
            [io.pivotal.pcf.rabbitmq.constants :refer [management-ui-port]])
  (:import java.net.URLEncoder))

(def ^{:private true} full-permissions
  {:configure ".*" :write ".*" :read ".*"})

;;
;; API
;;


(defn vhost-exists?
  [^String name]
  (hc/vhost-exists? name))

(defn add-vhost
  [^String name]
  (hc/add-vhost name))

(defn delete-vhost
  [^String name]
  (hc/delete-vhost name))


(defn add-operator-set-policy
  ([^String vhost]
   (add-operator-set-policy vhost (cfg/operator-set-policy-name) (cfg/operator-set-policy-definition) (cfg/operator-set-policy-priority)))
  ([^String vhost ^String policy-name policy-definition ^long policy-priority]
    (log/infof (format "Adding policy '%s' to vhost '%s'." policy-name vhost))
    (hc/set-policy vhost policy-name {:pattern ".*" :apply-to "all" :definition policy-definition :priority policy-priority})))

;; policymaker implies management but we include it anyway
;; to make it more obvious for ops.
(def ^{:const true} regular-user-tags "policymaker,management")

(defn add-user
  ([^String name ^String password]
     (add-user name password regular-user-tags))
  ([^String name ^String password ^String tags]
     (hc/add-user name password tags)))

(defn delete-user
  [^String name]
  (hc/delete-user name))

(defn list-users
  []
  (hc/list-users))

(defn close-connections-from
  [^String name]
  (hc/close-connections-from name))

(defn user-exists?
  [^String username]
  (hc/user-exists? username))

(defn generate-credentials
  [^String username-prefix ^String vhost]
  (loop [s (gen/next-string)
         u (format "%s-%s-%s" username-prefix vhost s)]
    (if-not (user-exists? u)
      ;; radix 48 produces slightly longer results
      [u (gen/next-string 48)]
      (recur (gen/next-string)
             (format "%s-%s-%s" username-prefix vhost s)))))

(defn ^String generate-password
  []
  (gen/next-string))

(defn grant-permissions
  [^String username ^String vhost]
  (hc/set-permissions vhost username full-permissions))

(defn grant-broker-administrator-permissions
  [^String vhost]
  (hc/set-permissions vhost (cfg/rabbitmq-administrator) full-permissions))

(defn ^String dashboard-url
  ([m ^String scheme ^String username ^String password]
    (let [host (cfg/management-domain m)]
      (format "%s://%s/#/login/%s/%s" scheme host username password)))
  ([^String scheme ^String username ^String password]
    (let [host (cfg/management-domain)]
      (format "%s://%s/#/login/%s/%s" scheme host username password))))

(defn ^String uri-for
  [^String scheme ^String username ^String password ^String node-host ^String vhost]
  (format "%s://%s:%s@%s/%s" scheme username password node-host (URLEncoder/encode vhost)))

(defn ^String http-api-uri-for
  [^String scheme ^String username ^String password ^String node-host]
  (format "%s://%s:%s@%s:15672/api" scheme username password node-host))

(defn filter-protocol-ports
  [[k v]]
  (or (= k "clustering")))

(defn protocol-ports
  []
  (let [m  (hc/protocol-ports)]
    (into {}
          (remove filter-protocol-ports m))))

(defn ^String protocol-key-for
  [proto tls?]
  (case (.toLowerCase ^String (name proto))
    "amqp"      "amqp"
    "mqtt"      "mqtt"
    "stomp"     "stomp"
    "amqp/ssl"  "amqp+ssl"
    "amqps"     "amqp+ssl"
    "amqp+ssl"  "amqp+ssl"
    "mqtt/ssl"  "mqtt+ssl"
    "mqtt+ssl"  "mqtt+ssl"
    "mqtts"     "mqtt+ssl"
    "stomp/ssl" "stomp+ssl"
    "stomp+ssl" "stomp+ssl"
    (if tls?
      (format "%s+ssl" (name proto))
      proto)))

(defn maybe-inject-vhost
  [m ^String proto ^String vhost]
  (case (.toLowerCase proto)
    "mqtt"     m
    "mqtt/ssl" m
    (assoc m :vhost vhost)))

(defn ^String scheme-for-protocol
  [^String proto tls?]
  (let [s (.toLowerCase proto)]
    (if tls?
      (case s
      "amqp"      "amqp"
      "amqps"     "amqps"
      "amqp/ssl"  "amqps"
      "amqp+ssl"  "amqps"
      "mqtt/ssl"  "mqtt+ssl"
      "mqtt+ssl"  "mqtt+ssl"
      "stomp/ssl" "stomp+ssl"
      "stomp+ssl" "stomp+ssl"
      (format "%s+ssl" s))
      s)))

(defn ^String proto-with-tls?
  [^String proto]
  (let [s (.toLowerCase proto)]
    (case s
      "amqp"      false
      "mqtt"      false
      "stomp"     false
      "amqps"     true
      "amqp/ssl"  true
      "mqtt+ssl"  true
      "mqtt/ssl"  true
      "stomp+ssl" true
      "stomp/ssl" true)))

(defn ^String username-for-protocol
  [^String proto ^String username ^String vhost]
  (case (.toLowerCase proto)
    "mqtt"     (format "%s:%s" vhost username)
    "mqtt/ssl" (format "%s:%s" vhost username)
    username))

(defn ^String path-for-protocol
  [^String proto ^String vhost]
  (let [s (.toLowerCase proto)]
    (case s
      "mqtt"      ""
      "mqtt/ssl"  ""
      "stomp"     ""
      "stomp/ssl" ""
      (format "/%s" vhost))))

(defn maybe-encode-username
  [^String proto ^String username]
  (if (= (#{"mqtt" "mqtt/ssl"} proto))
    (URLEncoder/encode username)
    username))

(defn ^String build-uri-for
  [^String node-host port ^String vhost ^String proto ^String username ^String password tls?]
  (format "%s://%s:%s@%s:%d%s"
          (scheme-for-protocol proto tls?)
          (maybe-encode-username proto username)
          password
          node-host
          port
          (path-for-protocol proto vhost)))

(defn inject-http-protocol
  [m node-hosts ^String username ^String password tls?]
  (let [first-node-host (get node-hosts 0)
        k (protocol-key-for "management" tls?)]
    (assoc m k {:uri      (http-api-uri-for (if tls?
                                              "https"
                                              "http") username password first-node-host)
                :uris     (map (fn [node-host] (http-api-uri-for (if tls? "https" "http") username password node-host)) node-hosts)
                :username username
                :password password
                :host     first-node-host
                :hosts    node-hosts
                :port     management-ui-port
                :path     "/api"
                :ssl      (not (not tls?))})))

(defn protocol-info-for
  [node-hosts ^String vhost ^String username ^String password protos tls?]
  (-> (reduce (fn [acc [proto port]]
                (let [first-node-host (get node-hosts 0)
                      username'       (username-for-protocol proto username vhost)
                      proto-tls?      (proto-with-tls? proto)
                      m               {:username username'
                                       :password password
                                       :port     port
                                       :host     first-node-host
                                       :hosts    node-hosts
                                       :ssl      proto-tls?
                                       :uri      (build-uri-for first-node-host port vhost proto username' password proto-tls?)
                                       :uris     (map (fn [node-host] (build-uri-for node-host port vhost proto username' password proto-tls?)) node-hosts)}]
                  (assoc acc (protocol-key-for proto (proto-with-tls? proto))
                         (-> m
                             (maybe-inject-vhost proto vhost)))))
              {}
              protos)
      (inject-http-protocol node-hosts username password tls?)))

(defn credentials-for
  [node-hosts ^String vhost ^String username ^String password protos tls?]
  (let [first-node-host (get node-hosts 0)]
    {:uri           (uri-for (cfg/amqp-scheme) (URLEncoder/encode username) password first-node-host vhost)
     :uris          (map (fn [node-host] (uri-for (cfg/amqp-scheme) (URLEncoder/encode username) password node-host vhost)) node-hosts)
     :vhost         vhost
     :username      username
     :ssl           tls?
     :password      password
     :hostname      first-node-host
     :hostnames     node-hosts
     :http_api_uri  (http-api-uri-for (cfg/http-scheme) username password first-node-host)
     :http_api_uris (map (fn [node-host] (http-api-uri-for (cfg/http-scheme) username password node-host)) node-hosts)
     :protocols     (protocol-info-for node-hosts vhost username password protos tls?)
     :dashboard_url (dashboard-url (cfg/http-scheme) username password)}))
