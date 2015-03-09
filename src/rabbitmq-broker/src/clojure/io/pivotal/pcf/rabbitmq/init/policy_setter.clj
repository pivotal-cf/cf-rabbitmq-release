(ns io.pivotal.pcf.rabbitmq.init.policy-setter
  (:require [langohr.http :as hc]
            [io.pivotal.pcf.rabbitmq.config :as cfg]
            [io.pivotal.pcf.rabbitmq.resources :as rs]))

(defn init-policy-on-all-vhosts
  [m]
  (if (cfg/mirrored-queues-enabled? m)
    (doseq [vhost (hc/list-vhosts)]
      (if-not (= (:name vhost) "/")
        (rs/add-mirrored-queues-policy (:name vhost))))))
