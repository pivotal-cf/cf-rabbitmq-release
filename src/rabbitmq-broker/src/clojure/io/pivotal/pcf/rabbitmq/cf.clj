(ns io.pivotal.pcf.rabbitmq.cf
  (:require [clojurewerkz.mold.client :as cfc]
            [clojurewerkz.mold.users  :as cfu])
  (:import  [org.cloudfoundry.client.lib CloudFoundryClient]))

;;
;; Implementation
;;

(def client)

;;
;; API
;;

(defn init!
  [^CloudFoundryClient c]
  (alter-var-root #'client (constantly c)))
