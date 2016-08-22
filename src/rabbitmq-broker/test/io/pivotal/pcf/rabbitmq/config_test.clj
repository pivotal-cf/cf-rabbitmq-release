(ns io.pivotal.pcf.rabbitmq.config-test
  (:require [clojure.test :refer :all]
            [io.pivotal.pcf.rabbitmq.test-helpers :refer [load-config]]
            [io.pivotal.pcf.rabbitmq.config :as cfg]))

(deftest test-cc-endpoint
  (let [m (load-config "config/valid.yml")]
    (is (= "http://127.0.0.1:8181" (cfg/cc-endpoint m)))))

(deftest test-using-tls
  (let [m (load-config "config/valid.yml")]
    (is (not (cfg/using-tls? m))))
  (let [m (load-config "config/valid_with_tls.yml")]
    (is (cfg/using-tls? m))))

(deftest test-operator-set-policies
  (testing "with valid policy definition"
    (let [m (load-config "config/valid.yml")]
      (is (not (cfg/operator-set-policy-enabled? m))))
    (let [m (load-config "config/valid_with_operator_set_policy.yml")]
      (is (cfg/operator-set-policy-enabled? m))
      (is (= (cfg/operator-set-policy-name m) "operator_set_policy"))
      (is (= (cfg/operator-set-policy-definition m) {:ha-mode "exactly" :ha-params 2 :ha-sync-mode "automatic"}))
      (is (= (cfg/operator-set-policy-priority m) 50))))
  (testing "with invalid policy definition"
    (let [m (load-config "config/valid_with_corrupt_operator_set_policy.yml")]
      (is (nil? (cfg/operator-set-policy-definition m))))))

(deftest test-amqp-scheme
  (let [m (load-config "config/valid.yml")]
    (is (= "amqp" (cfg/amqp-scheme m))))
  (let [m (load-config "config/valid_with_tls.yml")]
    (is (= "amqps" (cfg/amqp-scheme m))))
  (let [m (load-config "config/missing_tls.yml")]
    (is (= "amqp" (cfg/amqp-scheme m)))))

(deftest test-http-scheme
  (let [m (load-config "config/valid.yml")]
    (is (= "http" (cfg/http-scheme m))))
  (let [m (load-config "config/valid_with_tls.yml")]
    (is (= "https" (cfg/http-scheme m))))
  (let [m (load-config "config/missing_tls.yml")]
    (is (= "http" (cfg/http-scheme m)))))

(deftest test-config-validation
  (testing "valid config"
    (let [m (load-config "config/valid.yml")]
      (is (cfg/valid? m))))
  (testing "config with missing service section"
    (is (not (cfg/valid? (load-config "config/missing_service.yml")))))
  (testing "config with missing CC endpoint"
    (is (not (cfg/valid? (load-config "config/missing_cc_endpoint.yml")))))
  (testing "config with incorrect logging level"
    (is (not (cfg/valid? (load-config "config/incorrect_logging_level.yml")))))
  (testing "config with missing RabbitMQ section"
    (is (not (cfg/valid? (load-config "config/missing_rabbitmq_info.yml")))))
  (testing "config with missing management domain"
    (is (not (cfg/valid? (load-config "config/missing_management_domain.yml")))))
  (testing "config with missing RabbitMQ administrator"
    (is (not (cfg/valid? (load-config "config/missing_rabbitmq_administrator.yml")))))
  (testing "config with missing RabbitMQ regular user tags"
    (is (not (cfg/valid? (load-config "config/missing_regular_user_tags.yml"))))))

(deftest test-service-info
  (let [m (load-config "config/valid.yml")
        si (cfg/service-info m)]
    (are [attr] (is (attr si))
         :id
         :name
         :description
         :bindable
         :requires
         :tags
         :metadata
         :plans)))

(deftest test-display-name
  (let [m (load-config "config/valid.yml")
        info (cfg/service-info m)]
    (is (= "WhiteRabbitMQ" (get-in info [:metadata "displayName"])))))

(deftest test-provider-name
  (let [m (load-config "config/valid.yml")
        info (cfg/service-info m)]
    (is (= "SomeCompany" (get-in info [:metadata "providerDisplayName"])))))

(deftest test-description
  (let [m (load-config "config/valid.yml")
        info (cfg/service-info m)]
    (is (= "this is a description" (get-in info [:description])))))

(deftest test-long-description
  (let [m (load-config "config/valid.yml")
        info (cfg/service-info m)]
    (is (= "this is a long description" (get-in info [:metadata "longDescription"])))))

(deftest test-documentation-url
  (let [m (load-config "config/valid.yml")
        info (cfg/service-info m)]
    (is (= "https://example.com" (get-in info [:metadata "documentationUrl"])))))

(deftest test-support-url
  (let [m (load-config "config/valid.yml")
        info (cfg/service-info m)]
    (is (= "https://support.example.com" (get-in info [:metadata "supportUrl"])))))

(deftest test-image-url
  (let [m (load-config "config/valid.yml")
        info (cfg/service-info m)]
    (is (= "data:image/png;base64,image_icon_base64" (get-in info [:metadata "imageUrl"])))))

(deftest test-node-hosts
  (testing "when there is no DNS host"
    (let [m (load-config "config/valid.yml")]
      (is (= (set (cfg/node-hosts m)) #{"127.0.0.1" "127.0.0.2"}))))
  (testing "when there is a DNS host"
    (let [m (load-config "config/valid_with_dns_host.yml")]
      (is (= (set (cfg/node-hosts m)) #{"my-dns-host.com"})))))

(deftest test-rabbitmq-administrator-uris
  (let [m (load-config "config/valid.yml")]
    (is (= (set (cfg/rabbitmq-administrator-uris m)) #{"http://127.0.0.1:15672" "http://127.0.0.2:15672"}))))

(deftest test-rabbitmq-regular-user-tags
  (let [m (load-config "config/valid.yml")]
    (is (= (cfg/regular-user-tags m) "policymaker,management"))))
