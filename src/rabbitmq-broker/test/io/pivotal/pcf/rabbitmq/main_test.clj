(ns io.pivotal.pcf.rabbitmq.main-test
  (:require [clojure.test :refer :all]
            [io.pivotal.pcf.rabbitmq.main :as main]))

(defn FakeInit
  [m]
  (def FakeInitCalled "called"))

(defn FakeServer
  [m]
  (Thread. (fn [] (prn "Started Fake Sever"))))

(deftest initialization
  (testing "runs on init any registered initializers"
    (try
      (with-redefs [main/server FakeServer main/initializers (set [FakeInit])]
        (main/-main "-c" "test/config/valid.yml")
        (is (= FakeInitCalled "called")))
      (finally
        (def FakeInitCalled nil)))))
