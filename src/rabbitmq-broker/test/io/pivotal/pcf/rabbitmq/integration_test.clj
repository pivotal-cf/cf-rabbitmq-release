(ns io.pivotal.pcf.rabbitmq.integration-test
  (:require [clojure.test :refer :all]
            [io.pivotal.pcf.rabbitmq.test-helpers :refer [load-config has-policy? has-no-policy?] :as th]
            [io.pivotal.pcf.rabbitmq.config :as cfg]
            [io.pivotal.pcf.rabbitmq.server :as srv]
            [io.pivotal.pcf.rabbitmq.resources :as rs]
            [cheshire.core :as json])
  (:import org.eclipse.jetty.server.Server
           java.util.UUID))

;;
;; Helpers
;;

(defn ^{:private true :tag Server} start-server
  ([]
     (start-server "config/valid.yml"))
  ([^String config-path]
     (let [m (load-config config-path)]
       (srv/start m))))

(defmacro ^{:private true} provided-vhost-exists
  [^String name & body]
  `(try
     (when (not (rs/vhost-exists? ~name))
       (rs/add-vhost ~name))
     (is (rs/vhost-exists? ~name))
     ~@body
     (finally
       (rs/delete-vhost ~name))))

(defmacro ^{:private true} provided-vhost-does-not-exist
  [^String name & body]
  `(try
     (when (rs/vhost-exists? ~name)
       (rs/delete-vhost ~name))
     (is (not (rs/vhost-exists? ~name)))
     ~@body
     (finally
       (rs/delete-vhost ~name))))

(defmacro ^{:private true} provided-user-exists
  [^String name & body]
  `(try
     (when (not (rs/user-exists? ~name))
       (rs/add-user ~name ~(str (UUID/randomUUID))))
     (is (rs/user-exists? ~name))
     ~@body
     (finally
       (rs/delete-user ~name))))

(defmacro ^{:private true} provided-user-does-not-exist
  [^String name & body]
  `(try
     (when (rs/user-exists? ~name)
       (rs/delete-user ~name))
     (is (not (rs/user-exists? ~name)))
     ~@body
     (finally
       (cfg/init! nil)
       (rs/delete-user ~name))))

(defmacro ^{:private true} with-server-running
  [& body]
  `(let [^Server s# (start-server)]
     (try
       ~@body
       (finally
         (cfg/init! nil)
         (.stop s#)))))

(defmacro ^{:private true} with-server-running-operator-set-policy-config
  [& body]
  `(let [^Server s# (start-server "config/valid_with_operator_set_policy.yml")]
    (try
      ~@body
      (finally
        (cfg/init! nil)
        (.stop s#)))))


;;
;; Tests
;;

(deftest test-catalog-info
  (testing "with valid credentials"
    (with-server-running
      (let [res (th/get "v2/catalog")
            s1  (-> res :services first)]
        (are [k v] (is (= v (get s1 k)))
             :id       "163b47c6-a2f3-43b1-97f7-b83b37ec8ad3"
             :name     "p-rabbitmq"
             :bindable true)))))

(deftest test-create-service-with-operater-set-policy
  (testing "with provided service id that is NOT taken"
    (let [id (.toLowerCase ^String (str (UUID/randomUUID)))]
      (with-server-running-operator-set-policy-config "config/valid_with_operator_set_policy.yml"
        (provided-vhost-does-not-exist id
                                       (let [res         (th/put (format "v2/service_instances/%s" id))
                                             ^String dbu (:dashboard_url res)]
                                         (is dbu)
                                         (is (.startsWith dbu "http://pivotal-rabbitmq.127.0.0.1/#/login/")))
                                       (is (rs/vhost-exists? id))
                                       (th/has-policy? id (cfg/operator-set-policy-name)))))))

(deftest test-create-service-without-operator-set-policy
  (testing "with provided service id that is NOT taken"
    (let [id (.toLowerCase ^String (str (UUID/randomUUID)))]
      (with-server-running
        (provided-vhost-does-not-exist id
                                       (let [res         (th/put (format "v2/service_instances/%s" id))
                                             ^String dbu (:dashboard_url res)]
                                         (is dbu)
                                         (is (.startsWith dbu "http://pivotal-rabbitmq.127.0.0.1/#/login/")))
                                       (is (rs/vhost-exists? id))
                                       (is (th/has-no-policy? id (cfg/operator-set-policy-name)))))))
  (testing "with provided service id that IS taken"
    (let [id (.toLowerCase ^String (str (UUID/randomUUID)))]
      (try
        (with-server-running
          (provided-vhost-exists id
                                 (let [{:keys [status]} (th/raw-put (format "v2/service_instances/%s" id))]
                                   (is (= 409 status)))))
        (finally
          (rs/delete-vhost id)))))
  (testing "WITHOUT provided service id"
    (with-server-running
      (let [{:keys [status]} (th/raw-put "v2/service_instances/")]
        (is (= 404 status))))))

(deftest test-delete-service
  (testing "with provided service id that IS valid"
    (let [id (.toLowerCase ^String (str (UUID/randomUUID)))]
      (with-server-running
        (provided-vhost-exists id
                               (th/delete (format "v2/service_instances/%s" id))
                               (is (not (rs/vhost-exists? id)))))))
  (testing "with provided service id that is NOT valid"
    (let [id (.toLowerCase ^String (str (UUID/randomUUID)))]
      (try
        (with-server-running
          (provided-vhost-does-not-exist id
                                         (let [{:keys [status]} (th/raw-delete (format "v2/service_instances/%s" id))]
                                           (is (= 410 status)))))
        (finally
          (rs/delete-vhost id)))))
  (testing "WITHOUT provided service id"
    (with-server-running
      (let [{:keys [status]} (th/raw-delete "v2/service_instances/")]
        (is (= 404 status))))))

(deftest test-bind-service
  (testing "with provided service id and binding id that ARE valid"
    (let [sid (.toLowerCase ^String (str (UUID/randomUUID)))
          bid (.toLowerCase ^String (str (UUID/randomUUID)))
          n   (count (rs/list-users))]
      (with-server-running
        (provided-vhost-exists sid
                               (let [{:keys [status body]} (th/raw-put (format "v2/service_instances/%s/service_bindings/%s" sid bid))
                                     res                   (json/decode body false)
                                     n'                    (count (rs/list-users))
                                     ^String dbu           (get-in res ["credentials" "dashboard_url"])]
                                 (is dbu)
                                 (is (= 200 status))
                                 (is (= (inc n) n'))
                                 (is (get res "credentials"))
                                 (is (.startsWith dbu "http://pivotal-rabbitmq.127.0.0.1/#/login/"))
                                 (are [k] (get-in res ["credentials" k])
                                      "uri"
                                      "uris"
                                      "vhost"
                                      "username"
                                      "password"
                                      "hostname"
                                      "hostnames"
                                      "http_api_uri"
                                      "http_api_uris"
                                      "protocols")
                                 (rs/delete-user bid))))))
  (testing "with provided service id that IS NOT valid (missing)"
    (let [sid (.toLowerCase ^String (str (UUID/randomUUID)))
          bid (.toLowerCase ^String (str (UUID/randomUUID)))
          n   (count (rs/list-users))]
      (with-server-running
        (provided-vhost-does-not-exist sid
                                       (let [{:keys [status body]} (th/raw-put (format "v2/service_instances/%s/service_bindings/%s" sid bid))
                                             res                   (json/decode body true)
                                             n'                    (count (rs/list-users))]
                                         (is (= 410 status))
                                         (is (= {} res))
                                         (is (= n n')))))))
  (testing "with provided binding id that IS NOT valid (duplicate)"
    (let [sid (.toLowerCase ^String (str (UUID/randomUUID)))
          bid (.toLowerCase ^String (str (UUID/randomUUID)))]
      (with-server-running
        (provided-vhost-exists sid
                               (provided-user-exists bid
                                                     (let [n                     (count (rs/list-users))
                                                           {:keys [status body]} (th/raw-put (format "v2/service_instances/%s/service_bindings/%s" sid bid))
                                                           res                   (json/decode body true)
                                                           n'                    (count (rs/list-users))]
                                                       (is (= {} res))
                                                       (is (= 409 status))
                                                       (is (= n n'))))))))
  (testing "with provided binding id that IS NOT valid (missing)"
    (let [sid (.toLowerCase ^String (str (UUID/randomUUID)))
          n   (count (rs/list-users))]
      (with-server-running
        (provided-vhost-exists sid
                               (let [{:keys [status body]} (th/raw-put (format "v2/service_instances/%s/service_bindings/" sid))
                                     n'                    (count (rs/list-users))]
                                 (is (= 404 status))
                                 (is (= n n'))))))))

(deftest test-unbind-service
  (testing "with provided service id and binding id that ARE valid"
    (let [sid (.toLowerCase ^String (str (UUID/randomUUID)))
          bid (.toLowerCase ^String (str (UUID/randomUUID)))]
      (with-server-running
        (provided-vhost-exists sid
                               (provided-user-exists bid
                                                     (let [n                     (count (rs/list-users))
                                                           {:keys [status body]} (th/raw-delete (format "v2/service_instances/%s/service_bindings/%s" sid bid))
                                                           res                   (json/decode body true)
                                                           n'                    (count (rs/list-users))]
                                                       (is (= 200 status))
                                                       (is (= {} res))
                                                       (is (= (dec n) n'))))))))
  (testing "with provided binding id that IS NOT valid (missing)"
    (let [sid (.toLowerCase ^String (str (UUID/randomUUID)))
          n   (count (rs/list-users))]
      (with-server-running
        (provided-vhost-exists sid
                               (let [{:keys [status body]} (th/raw-delete (format "v2/service_instances/%s/service_bindings/" sid))
                                     n'                    (count (rs/list-users))]
                                 (is (= 404 status))
                                 (is (= n n'))))))))

(deftest test-ops-config
  (testing "with valid credentials"
    (with-server-running
      (let [res (th/get "ops/config")]
        (is (= "p1-rabbit" (get-in res [:service :username])))))))
