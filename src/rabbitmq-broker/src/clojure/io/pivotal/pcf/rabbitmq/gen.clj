(ns io.pivotal.pcf.rabbitmq.gen
  (:import java.security.SecureRandom))

(def ^{:private true :tag SecureRandom} sr (SecureRandom.))
(def ^{:private true :const true} num-bits 130)

;;
;; API
;;

(defn ^String next-string
  "Generates a pseudo-random string"
  ([]
     (next-string 32))
  ([^long radix]
     (-> (BigInteger. num-bits sr)
         (.toString radix))))
