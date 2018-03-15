#!/bin/bash

CMD_INTERVAL=10 # ms
Log_header="logs"
Log_PATH=$(cat ${PWD}/Log_PATH)
mkdir -p $Log_PATH

TMP="top.log"
TF_PID=$(ps -eaf | grep "tf_cnn_benchmarks.py" | grep python | tr -s ' ' | cut -d' ' -f2)
TOP_DELAY=$(echo "scale=2; $CMD_INTERVAL / 1000" | bc)
LOG="${Log_PATH}/${Log_header}_${TMP}"
top -d $TOP_DELAY -p $TF_PID -b > $LOG &
PID=$!
ALL_PID=$PID

TMP="nvidia_smi.log"
LOG="${Log_PATH}/${Log_header}_${TMP}"
nvidia-smi --query-gpu=timestamp,pci.bus_id,index,utilization.gpu,utilization.memory,memory.total,memory.used,memory.free --format=csv -lms  $CMD_INTERVAL > $LOG &
PID=$!
ALL_PID="$ALL_PID $PID"

echo $ALL_PID > "${Log_PATH}/pids"
