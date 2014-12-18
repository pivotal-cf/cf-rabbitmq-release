(ns io.pivotal.pcf.rabbitmq.config-test
  (:require [clojure.test :refer :all]
            [io.pivotal.pcf.rabbitmq.test-helpers :refer [load-config]]
            [io.pivotal.pcf.rabbitmq.config :as cfg]))
 
(deftest test-cc-endpoint
  (let [m (load-config "config/valid.yml")]
    (is (= "http://127.0.0.1:8181" (cfg/cc-endpoint m)))))

(deftest test-uaa-username
  (let [m (load-config "config/valid.yml")]
    (is (= "p1-rabbit" (cfg/uaa-username m)))))

(deftest test-uaa-password
  (let [m (load-config "config/valid.yml")]
    (is (= "p1-rabbit-pwd" (cfg/uaa-password m)))))

(deftest test-using-tls
  (let [m (load-config "config/valid.yml")]
    (is (not (cfg/using-tls? m))))
  (let [m (load-config "config/valid_with_tls.yml")]
    (is (cfg/using-tls? m))))

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
    (is (not (cfg/valid? (load-config "config/missing_rabbitmq_administrator.yml"))))))

(deftest test-service-info
  (let [m  (load-config "config/valid.yml")
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
