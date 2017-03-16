#!/bin/bash

Log_PATH=$(cat ${PWD}/Log_PATH)

kill -9 $(cat ${Log_PATH}/pids)
dir="${Log_PATH}/$(date +%d%b%Y_%H%M%S)"
mkdir $dir
mv ${Log_PATH}/*.log ${Log_PATH}/pids $dir
cp gpu.sh $dir
