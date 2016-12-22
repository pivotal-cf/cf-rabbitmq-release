(defproject com.pivotal.pcf.rabbitmq/broker "1.3.0-SNAPSHOT"
  :description "Pivotal CF RabbitMQ service broker"
  :dependencies [[org.clojure/clojure     "1.6.0"]
                 ;; RabbitMQ client (including HTTP API)
                 [com.novemberain/langohr "3.7.0" :exclusions [clj-http]]
                 ;; HTTP client which uses HTTPCore 4.2.x, compatible
                 ;; with Spring 3 and CF Java client.
                 [clj-http                "1.0.1"]
                 ;; routing, etc for HTTP API
                 [compojure                 "1.2.0"     :exclusions [org.clojure/clojure ring/ring-core]]
                 [ring/ring-core            "1.3.1"]
                 [ring/ring-servlet         "1.3.1"]
                 ;; Embedded HTTP server. Same as ring-jetty-adapter
                 ;; but uses Jetty 9 => requires JDK 7.
                 [info.sunng/ring-jetty9-adapter "0.8.2"]
                 [ring/ring-json            "0.3.1"     :exclusions [ring/ring-core]]
                 ;; basic HTTP authentication
                 [ring-basic-authentication "1.0.5"     :exclusions [org.clojure/clojure ring/ring-core]]
                 ;; CLI
                 [org.clojure/tools.cli     "0.3.1"]
                 ;; logging
                 [com.taoensso/timbre       "3.3.1"]
                 ;; YAML/JSON parser
                 [circleci/clj-yaml         "0.5.3"]
                 [org.clojure/data.json     "0.2.6"]
                 ;; validation
                 [com.novemberain/validateur "2.3.1"]
                 ;; nicer signal handling
                 [beckon                     "0.1.1"]
                 ;; test stubbing
                 [robert/hooke "1.3.0"]
                 ]
  :source-paths      ["src/clojure"]
  :java-source-paths ["src/java"]
  :resource-paths    ["src/resources"]
  :javac-options     ["-target" "1.7" "-source" "1.7"]
  :main io.pivotal.pcf.rabbitmq.main
  :global-vars {*warn-on-reflection* true}
  :jvm-opts ["-Xmx512m"]
  :profiles {:uberjar {:aot :all}}
  :repositories {"sonatype" {:url "http://oss.sonatype.org/content/repositories/releases"
                             :snapshots false
                             :releases {:checksum :fail}}
                 "jboss-thirdparty" {:url "https://repository.jboss.org/nexus/content/repositories/thirdparty-uploads"
                                     :snapshots false
                                     :releases {:checksum :fail}}})
