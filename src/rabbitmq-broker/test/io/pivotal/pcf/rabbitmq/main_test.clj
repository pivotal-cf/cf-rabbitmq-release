(ns io.pivotal.pcf.rabbitmq.main-test
  (:require [clojure.test :refer :all]
            [io.pivotal.pcf.rabbitmq.main :as main]
            [io.pivotal.pcf.rabbitmq.server :as server]))


(defn FakeExit
  [^long status]
  (def FakeExitCalled status))

; This exception is thrown to end the fake server
; We could not find any other reasonable way to achieve
; this. - (BC) (AS)
(defn FakeServerStart
  [m]
  (throw (Exception. "End Of The TEST")))
  ; (Thread. (fn [] (prn "Started Fake Sever"))))

(deftest initialization
  (testing "when server starts with an error"
    (with-redefs [server/start FakeServerStart main/exit FakeExit]
      (def FakeExitCalled nil)
      (main/-main "-c" "test/config/valid.yml")
      (is (= FakeExitCalled 1)))))
