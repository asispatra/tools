#!/bin/bash

CMD_INTERVAL=5
Log_header="logs"
Log_PATH=$(cat ${PWD}/Log_PATH)
mkdir -p $Log_PATH

TMP="mpstat.log"
LOG="${Log_PATH}/${Log_header}_${TMP}"
mpstat -P ALL $CMD_INTERVAL > $LOG &
PID=$!
ALL_PID=$PID

TMP="freestat.log"
LOG="${Log_PATH}/${Log_header}_${TMP}"
free -h -c 200000 -s $CMD_INTERVAL > $LOG &
PID=$!
ALL_PID="$ALL_PID $PID"

TMP="iostat.log"
LOG="${Log_PATH}/${Log_header}_${TMP}"
iostat -x $CMD_INTERVAL > $LOG &
PID=$!
ALL_PID="$ALL_PID $PID"

TMP="vmstat.log"
LOG="${Log_PATH}/${Log_header}_${TMP}"
vmstat $CMD_INTERVAL > $LOG &
PID=$!
ALL_PID="$ALL_PID $PID"

TMP="nvidia_smi.log"
LOG="${Log_PATH}/${Log_header}_${TMP}"
nvidia-smi --query-gpu=timestamp,pci.bus_id,index,utilization.gpu,utilization.memory,memory.total,memory.used,memory.free --format=csv -l  $CMD_INTERVAL > $LOG &
PID=$!
ALL_PID="$ALL_PID $PID"

echo $ALL_PID > "${Log_PATH}/pids"

