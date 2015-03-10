(ns io.pivotal.pcf.rabbitmq.main-test
  (:require [clojure.test :refer :all]
            [langohr.http :as hc]
            [io.pivotal.pcf.rabbitmq.main :as main]
            [io.pivotal.pcf.rabbitmq.server :as server])
  (:import (java.net URL UnknownHostException)))


(defn FakeInit
  [m]
  (def FakeInitCalled "called"))

(defn FakeExit
  [^long status]
  (def FakeExitCalled "called"))

(defn FakeServer
  [m]
  (Thread. (fn [] (prn "Started Fake Sever"))))

(defn FakeAlivenessTest
  [^String vhost]
  (def FakeAlivenessCallsBeforeSuccess (- FakeAlivenessCallsBeforeSuccess 1))
  (if (= FakeAlivenessCallsBeforeSuccess 0)
    {:status "ok"}
    (throw (UnknownHostException. "Host is down"))))


(deftest initialization
  (testing "when the polling succeeds calls the initializers"
    (with-redefs [main/initializers (set [FakeInit])
                  hc/aliveness-test FakeAlivenessTest
                  server/start FakeServer
                  main/polling-attempts 5
                  main/polling-sleep 10
                  main/exit FakeExit]
      (def FakeAlivenessCallsBeforeSuccess 5)
      (def FakeInitCalled nil)
      (def FakeExitCalled nil)
      (main/-main "-c" "test/config/valid.yml")
      (is (= FakeInitCalled "called"))
      (is (= FakeExitCalled nil))))
  (testing "when the polling fails exits the app"
    (with-redefs [main/initializers (set [FakeInit])
                  hc/aliveness-test FakeAlivenessTest
                  server/start FakeServer
                  main/polling-attempts 5
                  main/polling-sleep 10
                  main/exit FakeExit]
      (def FakeAlivenessCallsBeforeSuccess -1)
      (def FakeInitCalled nil)
      (def FakeExitCalled nil)
      (main/-main "-c" "test/config/valid.yml")
      (is (= FakeInitCalled nil))
      (is (= FakeExitCalled "called")))))
