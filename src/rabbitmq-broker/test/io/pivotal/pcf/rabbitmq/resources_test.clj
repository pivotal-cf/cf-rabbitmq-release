(ns io.pivotal.pcf.rabbitmq.resources-test
  (:require [clojure.test :refer :all]
            [langohr.http :as hc]
            [io.pivotal.pcf.rabbitmq.test-helpers :refer [load-config has-policy-with-definition? has-no-policy?]]
            [io.pivotal.pcf.rabbitmq.config :as cfg]
            [io.pivotal.pcf.rabbitmq.resources :as rs]))

(deftest test-add-operator-set-policy
  (testing "when the policy-definition is set"
    (let [vhost "unit-test-vhost"
          policy-name "cf-test-mirrored-queue-policy"
          policy-definition {:ha-mode "exactly" :ha-params 2 :ha-sync-mode "automatic"}
          policy-priority 50]
      (hc/add-vhost vhost)
      (hc/set-permissions vhost "guest" {:configure ".*" :read ".*" :write ".*"})
      (rs/add-operator-set-policy vhost policy-name policy-definition policy-priority)
      (has-policy-with-definition? vhost policy-name policy-definition policy-priority)
      (hc/delete-vhost vhost)))
  (testing "when the policy-definition is not set"
    (let [vhost "unit-test-vhost"
          policy-name "cf-test-mirrored-queue-policy"
          policy-definition nil
          policy-priority 50]
      (hc/add-vhost vhost)
      (hc/set-permissions vhost "guest" {:configure ".*" :read ".*" :write ".*"})
      (rs/add-operator-set-policy vhost policy-name policy-definition policy-priority)
      (has-no-policy? vhost policy-name)
      (hc/delete-vhost vhost))))

(deftest test-dashboard-url
  (testing "returns a formatted dashboard url"
    (let [m (load-config "config/valid.yml")]
      (is (= (rs/dashboard-url m)
             "https://pivotal-rabbitmq.127.0.0.1/#/login/"))))
  (testing "returns a formatted dashboard url with credentials"
    (let [m (load-config "config/valid.yml")]
      (is (= (rs/dashboard-url m "user" "password")
             "https://pivotal-rabbitmq.127.0.0.1/#/login/user/password")))))

(deftest test-uri-for
  (are [m uri] (is (= uri (rs/uri-for (:scheme m)
                                      (:username m)
                                      (:password m)
                                      (:node-host m)
                                      (:vhost m))))
       {:scheme "amqp"
        :username "guest"
        :password "guest"
        :node-host "mercurio.local"
        :vhost     "/abc"}
       "amqp://guest:guest@mercurio.local/%2Fabc"

       {:scheme "amqps"
        :username "d786c13c-799d-45f7-b9c0-eb8aeb03e468"
        :password "4d2f58c0-6c03-49a3-82b1-1f6a109b249b"
        :node-host "rmq.pcf.megacorp.internal"
        :vhost     "df7a77c5-4f63-4a05-b587-43b9a04e4bc2"}
       "amqps://d786c13c-799d-45f7-b9c0-eb8aeb03e468:4d2f58c0-6c03-49a3-82b1-1f6a109b249b@rmq.pcf.megacorp.internal/df7a77c5-4f63-4a05-b587-43b9a04e4bc2"))

(deftest test-http-api-uri-for
  (are [m uri] (is (= uri (rs/http-api-uri-for (:username m)
                                               (:password m)
                                               (:node-host m))))
       {:username "guest"
        :password "guest"
        :node-host "mercurio.local"}
       "http://guest:guest@mercurio.local:15672/api/"))

(deftest test-https-api-uri-for
  (are [m uri] (is (= uri (rs/https-api-uri-for (:username m)
                                               (:password m)
                                               (:node-host m))))
       {:username "guest"
        :password "guest"
        :node-host "mercurio.local"}
       "https://guest:guest@mercurio.local/api/"))

(deftest test-protocol-ports
  (let [m (-> (rs/protocol-ports) keys set)]
    (= m "amqp")
    (not (= m "clustering"))))

(deftest test-protocol-key-for
  (testing "with TLS disabled"
    (are [in out] (is (= out (rs/protocol-key-for in false)))
         "amqp"            "amqp"
         "AMQP"            "amqp"
         "mqtt"            "mqtt"
         "MQTT"            "mqtt"
         "stomp"           "stomp"
         "STOMP"           "stomp"
         "http/web-stomp"  "ws"
         "http/web-mqtt"   "ws"
         "amqps"           "amqp+ssl"
         "amqp/ssl"        "amqp+ssl"
         "amqp+ssl"        "amqp+ssl"
         "proto"           "proto"))
  (testing "with TLS enabled"
    (are [in out] (is (= out (rs/protocol-key-for in true)))
         "amqp"            "amqp"
         "AMQP"            "amqp"
         "http/web-stomp"  "ws"
         "http/web-mqtt"   "ws"
         "mqtt"            "mqtt"
         "MQTT"            "mqtt"
         "stomp"           "stomp"
         "STOMP"           "stomp"
         "amqps"           "amqp+ssl"
         "amqp/ssl"        "amqp+ssl"
         "amqp+ssl"        "amqp+ssl"
         "proto"           "proto+ssl")))

(deftest test-username-for-protocol
  (are [in out] (is (= (rs/username-for-protocol (:proto in)
                                                 (:username in)
                                                 (:vhost in)) out))
    {:proto    "amqp"
     :vhost    "my-app"
     :username "guest"} "guest"
     {:proto    "stomp"
     :vhost    "my-app"
     :username "guest"} "guest"
     {:proto    "mqtt"
     :vhost    "my-app"
     :username "guest"} "my-app:guest"))

(deftest test-maybe-encode-username
  (testing "for mqtt"
    (are [in out] (is (= (rs/maybe-encode-username "mqtt" in) out))
    "/:guest"    "%2F%3Aguest"
    "lala:guest" "lala%3Aguest")))

(deftest test-build-uri-for
  (testing "amqp without TLS"
    (is (= (rs/build-uri-for "mercurio.local" 5672 "my-app" "amqp" "guest" "guest" false)
           "amqp://guest:guest@mercurio.local:5672/my-app")))
  (testing "amqp with TLS"
    (is (= (rs/build-uri-for "mercurio.local" 5671 "my-app" "amqps" "guest" "guest" true)
           "amqps://guest:guest@mercurio.local:5671/my-app")))
  (testing "mqtt without TLS"
    (is (= (rs/build-uri-for "mercurio.local" 1883 "my-app" "mqtt" "my-app:guest" "guest" false)
           "mqtt://my-app%3Aguest:guest@mercurio.local:1883")))
  (testing "mqtt with TLS"
    (is (= (rs/build-uri-for "mercurio.local" 1883 "my-app" "mqtt" "my-app:guest" "guest" true)
           "mqtt+ssl://my-app%3Aguest:guest@mercurio.local:1883"))))

(deftest test-protocol-info-for
  (testing "without TLS"
    (let [protos {"stomp" 61613 "mqtt" 1883  "amqp" 5672 "http" 15672}
          ssl?   false
          out    {"amqp"       {:uri      "amqp://guest:guest@mercurio.local:5672/my-app"
                                :uris     ["amqp://guest:guest@mercurio.local:5672/my-app" "amqp://guest:guest@other.local:5672/my-app"]
                                :username "guest"
                                :password "guest"
                                :vhost    "my-app"
                                :host     "mercurio.local"
                                :hosts    ["mercurio.local" "other.local"]
                                :port     5672
                                :ssl      ssl?}
                  "mqtt"       {:uri      "mqtt://my-app%3Aguest:guest@mercurio.local:1883"
                                :uris     ["mqtt://my-app%3Aguest:guest@mercurio.local:1883" "mqtt://my-app%3Aguest:guest@other.local:1883"]
                                :username "my-app:guest"
                                :password "guest"
                                :host     "mercurio.local"
                                :hosts    ["mercurio.local" "other.local"]
                                :port     1883
                                :ssl      ssl?}
                  "stomp"      {:uri      "stomp://guest:guest@mercurio.local:61613"
                                :uris     ["stomp://guest:guest@mercurio.local:61613" "stomp://guest:guest@other.local:61613"]
                                :username "guest"
                                :password "guest"
                                :vhost    "my-app"
                                :host     "mercurio.local"
                                :hosts    ["mercurio.local" "other.local"]
                                :port     61613
                                :ssl      ssl?}
                  "management" {:uri      "http://guest:guest@mercurio.local:15672/api/"
                                :uris     ["http://guest:guest@mercurio.local:15672/api/" "http://guest:guest@other.local:15672/api/"]
                                :username "guest"
                                :password "guest"
                                :host     "mercurio.local"
                                :hosts    ["mercurio.local" "other.local"]
                                :port     15672
                                :path     "/api/"
                                :ssl      ssl?}}]
    (is (= (rs/protocol-info-for ["mercurio.local" "other.local"] "my-app" "guest" "guest"
                                 protos
                                 ssl?)
           out))))
  (testing "with TLS"
    (let [protos {"stomp/ssl" 61614 "mqtt/ssl" 8883  "amqp/ssl" 5671}
          ssl?   true
          out    {"amqp+ssl"       {:uri      "amqps://guest:guest@mercurio.local:5671/my-app"
                                    :uris     ["amqps://guest:guest@mercurio.local:5671/my-app" "amqps://guest:guest@other.local:5671/my-app"]
                                    :username "guest"
                                    :password "guest"
                                    :vhost    "my-app"
                                    :host     "mercurio.local"
                                    :hosts    ["mercurio.local" "other.local"]
                                    :port     5671
                                    :ssl      ssl?}
                  "mqtt+ssl"       {:uri      "mqtt+ssl://my-app%3Aguest:guest@mercurio.local:8883"
                                    :uris     ["mqtt+ssl://my-app%3Aguest:guest@mercurio.local:8883" "mqtt+ssl://my-app%3Aguest:guest@other.local:8883"]
                                    :username "my-app:guest"
                                    :password "guest"
                                    :host     "mercurio.local"
                                    :hosts    ["mercurio.local" "other.local"]
                                    :port     8883
                                    :ssl      ssl?}
                  "stomp+ssl"      {:uri      "stomp+ssl://guest:guest@mercurio.local:61614"
                                    :uris     ["stomp+ssl://guest:guest@mercurio.local:61614" "stomp+ssl://guest:guest@other.local:61614"]
                                    :username "guest"
                                    :password "guest"
                                    :vhost    "my-app"
                                    :host     "mercurio.local"
                                    :hosts    ["mercurio.local" "other.local"]
                                    :port     61614
                                    :ssl      ssl?}
                  "management+ssl" {:uri      "http://guest:guest@mercurio.local:15672/api/"
                                    :uris     ["http://guest:guest@mercurio.local:15672/api/" "http://guest:guest@other.local:15672/api/"]
                                    :username "guest"
                                    :password "guest"
                                    :host     "mercurio.local"
                                    :hosts    ["mercurio.local" "other.local"]
                                    :port     15672
                                    :path     "/api/"
                                    :ssl      false}}]
    (is (= (rs/protocol-info-for ["mercurio.local" "other.local"] "my-app" "guest" "guest"
                                 protos
                                 ssl?)
           out)))))

(deftest test-credentials-for
  (testing "works"
    (with-redefs [rs/protocol-info-for (fn [node-hosts ^String vhost ^String username ^String password protos tls?] "fake-protocol-info")]
      (let [m (load-config "config/valid.yml")]
        (cfg/init! m)
        (is (= (rs/credentials-for ["host-1" "host-2"]
                                  "vhost-1"
                                  "user"
                                  "password"
                                  {"stomp/ssl" 61614 "mqtt/ssl" 8883  "amqp/ssl" 5671}
                                  true)
            {:uri           "amqp://user:password@host-1/vhost-1"
             :uris          ["amqp://user:password@host-1/vhost-1" "amqp://user:password@host-2/vhost-1"]
             :username      "user"
             :ssl           true
             :password      "password"
             :vhost         "vhost-1"
             :hostname      "host-1"
             :hostnames     ["host-1" "host-2"]
             :http_api_uri  "https://user:password@pivotal-rabbitmq.127.0.0.1/api/"
             :http_api_uris ["https://user:password@pivotal-rabbitmq.127.0.0.1/api/"]
             :protocols     "fake-protocol-info"
             :dashboard_url "https://pivotal-rabbitmq.127.0.0.1/#/login/user/password"}))))))
