(ns io.pivotal.pcf.rabbitmq.init.policy-setter-test
  (:require [clojure.test :refer :all]
            [langohr.http :as hc]
            [io.pivotal.pcf.rabbitmq.test-helpers :refer [has-mirrored-policy? has-no-policy? load-config]]
            [io.pivotal.pcf.rabbitmq.config :as cfg]
            [io.pivotal.pcf.rabbitmq.resources :as rs]
            [io.pivotal.pcf.rabbitmq.init.policy-setter :as ps]))

(def vhost-1 "vhost-1")
(def vhost-2 "vhost-2")

(defn with-two-vhosts
  [f]
  (let [vhosts-count (count (hc/list-vhosts))]
    (hc/add-vhost vhost-1)
    (hc/set-permissions vhost-1 "guest" {:configure ".*" :read ".*" :write ".*"})
    (hc/add-vhost vhost-2)
    (hc/set-permissions vhost-2 "guest" {:configure ".*" :read ".*" :write ".*"})

    (f)

    (is (= (count (hc/list-vhosts)) (+ 2 vhosts-count)))
    (hc/delete-vhost vhost-1)
    (hc/delete-vhost vhost-2)))

(use-fixtures :each with-two-vhosts)

(deftest when-mirrored-queues-flag-is-on
  (let [m  (load-config "config/valid_with_mirrored_queues.yml")]

    (testing "trys to set policy on all vhosts"
      (let [policy-name (cfg/mirrored-queues-policy-name m)]
        (ps/init-policy-on-all-vhosts m)

        (has-no-policy? "/" policy-name)
        (has-mirrored-policy? vhost-1 policy-name)
        (has-mirrored-policy? vhost-2 policy-name)))

    (testing "when some of the nodes already have the mirrored queues"
      (let [policy-name (cfg/mirrored-queues-policy-name m)]
        (rs/add-mirrored-queues-policy vhost-1 policy-name)

        (ps/init-policy-on-all-vhosts m)

        (has-no-policy? "/" policy-name)
        (has-mirrored-policy? vhost-1 policy-name)
        (has-mirrored-policy? vhost-2 policy-name)))))

(deftest when-mirrored-queues-flag-is-off
  (let [m  (load-config "config/valid.yml")]
    (testing "does not set the mirrored policy"
      (let [policy-name (cfg/mirrored-queues-policy-name m)]
        (ps/init-policy-on-all-vhosts m)
        (has-no-policy? vhost-1 policy-name)))))
