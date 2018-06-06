#!/bin/bash -e

status=$(cat <<'EOF'
Status of node rabbit@21b6557b73f343201277dbf290ae8b79 ...
[{pid,5509},
 {running_applications,
     [{rabbitmq_management,"RabbitMQ Management Console","3.4.3"},
      {rabbitmq_web_dispatch,"RabbitMQ Web Dispatcher","3.4.3"},
      {webmachine,"webmachine","1.10.3-rmq3.4.3-gite9359c7"},
      {mochiweb,"MochiMedia Web Server","2.7.0-rmq3.4.3-git680dba8"},
      {rabbitmq_mqtt,"RabbitMQ MQTT Adapter","3.4.3"},
      {rabbitmq_stomp,"Embedded Rabbit Stomp Adapter","3.4.3"},
      {rabbitmq_management_agent,"RabbitMQ Management Agent","3.4.3"},
      {rabbit,"RabbitMQ","this-is-a-malformed-version"},
      {os_mon,"CPO  CXC 138 46","2.2.15"},
      {mnesia,"MNESIA  CXC 138 12","4.12.1"},
      {amqp_client,"RabbitMQ AMQP Client","3.4.3"},
      {rabbitmq_clusterer,"Declarative Clustering","3.4.3"},
      {ssl,"Erlang/OTP SSL application","5.3.5"},
      {public_key,"Public key infrastructure","0.22"},
      {crypto,"CRYPTO","3.4"},
      {asn1,"The Erlang ASN1 compiler version 3.0.1","3.0.1"},
      {inets,"INETS  CXC 138 49","5.10.2"},
      {xmerl,"XML parser","1.3.7"},
      {sasl,"SASL  CXC 138 11","2.4"},
      {stdlib,"ERTS  CXC 138 10","2.1"},
      {kernel,"ERTS  CXC 138 10","3.0.1"}]},
 {os,{unix,linux}},
 {erlang_version,
     "Erlang/OTP 17 [erts-6.1] [source] [64-bit] [smp:4:4] [async-threads:30] [hipe] [kernel-poll:true]\n"},
 {memory,
     [{total,47905040},
      {connection_readers,0},
      {connection_writers,0},
      {connection_channels,0},
      {connection_other,5616},
      {queue_procs,2808},
      {queue_slave_procs,0},
      {plugins,389104},
      {other_proc,14010336},
      {mnesia,66616},
      {mgmt_db,11912},
      {msg_index,44184},
      {other_ets,1302704},
      {binary,37240},
      {code,22596828},
      {atom,801697},
      {other_system,8635995}]},
 {alarms,[]},
 {listeners,
     [{clustering,25672,"::"},
      {'amqp/ssl',5671,"::"},
      {stomp,61613,"::"},
      {'stomp/ssl',61614,"::"},
      {mqtt,1883,"::"},
      {'mqtt/ssl',8883,"::"}]},
 {vm_memory_high_watermark,0.4},
 {vm_memory_limit,6731374592},
 {disk_free_limit,1000000},
 {disk_free,1856520192},
 {file_descriptors,
     [{total_limit,49900},
      {total_used,7},
      {sockets_limit,44908},
      {sockets_used,5}]},
 {processes,[{limit,1048576},{used,210}]},
 {run_queue,0},
 {uptime,38591}]
EOF)

case $1 in

  status)
    echo "$status"
    echo "status $2 $3" >> $TEST_OUTPUT_FILE
    ;;

  stop_app)
    echo "stop_app $2 $3" >> $TEST_OUTPUT_FILE
    ;;

  *)
    exit 1
    ;;

esac
