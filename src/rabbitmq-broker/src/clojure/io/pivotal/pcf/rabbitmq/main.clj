(ns io.pivotal.pcf.rabbitmq.main
  (:gen-class)
  (:require [clojure.tools.cli :refer [parse-opts]]
            [clojure.string :as cs]
            [io.pivotal.pcf.rabbitmq.config :as cfg]
            [io.pivotal.pcf.rabbitmq.server :as srv]
            [taoensso.timbre :as log])
  (:import java.io.File))

(def cli-options
  [
   ["-c" "--config-path PATH"
    :id           :config-path
    :desc         "Configuration file path"
    :validate-fn  (fn [^String s]
                    (and s (.exists (File. s))))
    :validate-msg "must point to a file that exists"]
   ["-h" "--help"]
   ])

(defn usage
  [options-summary]
  (cs/join \newline
           ["PCF RabbitMQ service broker"
            ""
            "Usage: java -jar broker.jar [options]"
            ""
            "Options:"
            options-summary]))

(defn ^:private readable-attribute-name
  [k]
  (let [xs (if (coll? k)
             k
             [k])]
    (cs/join "." (map name xs))))

(defn ^:private readable-errors
  [xs]
  (cs/join "," xs))

(defn ^:private display-config-errors
  [errors]
  (let [sb (reduce (fn [^StringBuilder acc [k v]]
                     (.append acc ^String (format "* %s: %s\n"
                                                  (readable-attribute-name k)
                                                  (readable-errors v)))
                     acc)
                   (StringBuilder.)
                   (sort-by (comp count readable-attribute-name key) < errors))]
    (println (format "Config validation failed. Errors:\n\n%s" (.toString ^StringBuilder sb)))))

(defn error-msg
  [errors]
  (str "Could not parse command line arguments:\n\n"
       (cs/join \newline errors)))

(defn exit
  ([^long status]
     (System/exit status))
  ([^long status msg]
     (println msg)
     (System/exit status)))

(defn -main
  [& args]
  (let [{:keys [errors options arguments summary]} (parse-opts args cli-options)]
    (cond
     (:help options)    (exit 0 (usage summary))
     errors             (exit 1 (error-msg errors))
     (empty? options)   (exit 1 (usage summary)))
    (try
      (let [m (cfg/from-path (:config-path options))]
        (if (cfg/valid? m)
          (let [s (srv/start m)]
            (.join s))
          (display-config-errors (cfg/validate m))))
      (catch Exception e
        (log/infof "Failed to start with config from %s:" (:config-path options))
        (.printStackTrace e)
        (exit 1)))))
