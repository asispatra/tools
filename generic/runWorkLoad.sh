#!/bin/bash

#
# File Name: runWorkLoad.sh
#
# Date:      June 14, 2018
# Author:    Asis Kumar Patra
# Purpose:   Run any workload with various combination of option. It supports
#            to take NV Profile and can collect different system stats while
#            the workload is running.
#

# Write your shell script here.

TEST=true # true - test on, false - test off
SLEEP_TIME=0 # Sleep for specified second after each run
TAKE_NV_PROFILE=false # true - take nvprofile, false(default) - dont take

iters=1 # Number of iteration(s) for each run

# Specify all combination of  arguments to program
vars=(
#nodistortions
#num_batches="10 200"
#data_dir="/home/asis/TF_records"
#num_gpus="1 2 4"
#output_dir="/home/asis/TF_records"
#batch_size="128 64"
#data_name="imagenet"
model="resnet50"
#gpu_thread_mode="gpu_shared"
)

# Determine BASE_PATH - where to save the logs/results
if [ -z "$1" ] ; then
  BASE_PATH=$PWD
else
  BASE_PATH=$1
fi

# Save all the logs in results_dir
results_dir="${BASE_PATH}/results"

if ! $TEST ; then
  mkdir -p $results_dir
fi

ext=$(date +%d%b%Y_%H%M%S) # Add timestamp extension to file name to identify uniqly

# Extra info user can add.
extra_info="TF-$(python -c 'import tensorflow as tf; print(tf.__version__)' 2>/dev/null)"

# Collect these system info and will be put in file name.
systype=$(lscpu | grep "Model name" | sed 's/.*:\s\s*\([^ ,(][^ ,(]*\).*/\1/') # System Type: P9, Intel
SMT=$(lscpu | grep "Thread(s) per core" | tr -d ' ' | cut -d ':' -f2) # SMT for Power, Hyperthread for Intel
GPUdriver=$(cat /proc/driver/nvidia/version | grep "NVRM version" | sed 's/.*Kernel Module\s\s*\([^ ][^ ]*\).*/\1/') # Nvidia GPU Driver
COMMIT=$(echo $(git show 2> /dev/null | grep "^commit" || echo default) | head -1 | sed 's/^commit \(.......\).*/\1/') # if there is a commit

base="${systype}_SMT${SMT}_$(hostname)_${GPUdriver}_commit-${COMMIT}"
if [ "${extra_info}" != "" ] ; then
  base="${extra_info}_${base}"
fi

# Spefify your workload command
cmds="python -m trace --listfuncs --trackcalls ./t2t_trainer --num_batches=1100"

base_cmd=$cmds

# NF Profile configuration
if $TAKE_NV_PROFILE ; then
  nvprof="/usr/local/cuda/bin/nvprof -o"
  nv_extra="--num_warmup_batches=1 --display_every=1" # This will change depending upon Workload
fi

# Create all the combination of runs
for elm in "${vars[@]}" ; do
  option=$(echo $elm | cut -d'=' -f 1)
  value=$(echo $elm | cut -d'=' -f 2)
  if [ "${value}" == "${option}" ] ; then
    cmds=$(echo "${cmds}" | sed "s/$/ --"${option}"/g")
  else
    tmpcmds="${cmds}"
    cmds=""
    for val in ${value} ; do
      val=$(echo $val | sed 's/\//\\\//g')
      tcmds=$(echo "${tmpcmds}" | sed "s/$/ --"${option}"="${val}"/g")
      cmds="${cmds}$tcmds\n"
    done
  fi
  cmds=$(echo -e "$cmds" )
  l=$(echo "$cmds" | wc -l)
  cmds=$(echo "$cmds" | head -$l)
done

cmds=$(echo "$cmds" | sed 's/ /'$(echo -e '\033')'/g') # \033 character used, so that this char should not be part of any code/WL
#echo "$cmds"
#exit
# ALL the combination created here

cmdno=0 # This will be used if log file name contains more than 240 Characters
for cmd in $cmds ; do
  cmd=$(echo $cmd | tr '\033' ' ')
  cmdtoreplace=$(echo "${base_cmd}" | sed 's/\///g' | sed 's/\.//g'| tr '_' '-' | tr ' ' '_' | sed 's/--//g') # Process your Command only
  logfile=$(echo "$cmd" | sed 's/\///g'| sed 's/\.//g' | tr '_' '-' | tr ' ' '_' | sed 's/--//g') # Process logfile name
  #echo "$cmdtoreplace"
  #echo "$logfile"
  logfile=$(echo "$logfile"| sed 's/'${cmdtoreplace}'_*//g' | tr '=' '-') # remove command from log file name, keep only the option
  if echo $logfile | grep "\/" > /dev/null 2>&1 ; then
    logfile=$(echo _$logfile | sed 's/_[^_]*\/[^_]*//g' | sed 's/^_//') # Remove all the options with directory specified
  fi
  iter=0
  while [ $iter -lt $iters ] ; do
    if [ "${logfile}" = "" ] ; then logfile="-" ; fi # Add "-" if logfile name is empty
    log="${results_dir}/${base}_${logfile}_${ext}_${iter}" # Absulute logfile name
    filename_length=$(echo "${base}_${logfile}_${ext}_${iter}" | wc -c)
    if [ $filename_length -gt 240 ] ; then # Check logfile name length, if more than 240 replace with cmdno
      log=$(echo $log | sed 's/'$logfile'/'$cmdno'/')
    fi
    _cmd=$cmd
    if [ "$nvprof" != "" ] ; then # If NV Profile need to take
      _cmd="${nvprof} ${log}.nvvp ${cmd} ${nv_extra}"
    fi
    log="${log}.log"
    echo "$log" # Print the log file name on standard output
    #echo "$_cmd"
    if ! $TEST ; then
      echo "$_cmd" >> ${log} 2>&1 # Put the full command in the logfile
      eval "$_cmd" >> ${log} 2>&1 # Execute the command and put the output in the logfile
      echo
      sleep $SLEEP_TIME # Sleep if needed
      if [ -f ${BASE_PATH}/extra.sh ] ; then # Run extra thing after each run done.
        ${BASE_PATH}/extra.sh
      fi
    else
      echo "$_cmd"
    #  echo
    fi
    iter=$(expr $iter + 1)
  done
  cmdno=$(expr $cmdno + 1)
done
