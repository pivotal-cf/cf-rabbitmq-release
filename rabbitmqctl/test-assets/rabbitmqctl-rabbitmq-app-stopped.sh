#!/bin/bash -e

status=$(cat <<'EOF'
Status of node rabbit@21b6557b73f343201277dbf290ae8b79 ...
[{pid,555},
 {running_applications,[{ssl,"Erlang/OTP SSL application","5.3.5"},
                        {public_key,"Public key infrastructure","0.22"},
                        {crypto,"CRYPTO","3.4"},
                        {asn1,"The Erlang ASN1 compiler version 3.0.1",
                              "3.0.1"},
                        {inets,"INETS  CXC 138 49","5.10.2"},
                        {xmerl,"XML parser","1.3.7"},
                        {sasl,"SASL  CXC 138 11","2.4"},
                        {stdlib,"ERTS  CXC 138 10","2.1"},
                        {kernel,"ERTS  CXC 138 10","3.0.1"}]},
 {os,{unix,linux}},
 {erlang_version,"Erlang/OTP 17 [erts-6.1] [source] [64-bit] [smp:4:4] [async-threads:30] [hipe] [kernel-poll:true]\n"},
 {memory,[{total,46731480},
          {connection_readers,0},
          {connection_writers,0},
          {connection_channels,0},
          {connection_other,0},
          {queue_procs,0},
          {queue_slave_procs,0},
          {plugins,0},
          {other_proc,13578008},
          {mnesia,0},
          {mgmt_db,0},
          {msg_index,0},
          {other_ets,1131528},
          {binary,37144},
          {code,22587228},
          {atom,801697},
          {other_system,8595875}]},
 {alarms,[]},
 {listeners,[]},
 {processes,[{limit,1048576},{used,62}]},
 {run_queue,0},
 {uptime,60863}]
EOF)

case $1 in

  status)
    echo "$status"
    echo "status $2 $3" >> $TEST_OUTPUT_FILE
    ;;

  *)
    exit 1
    ;;

esac
