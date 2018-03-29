#!/bin/bash

TEST=false # true - test on, false - test off
SLEEP_TIME=0 # sec

if ! $TEST ; then
  export PATH="/root/anaconda2/bin:$PATH"
  source /opt/DL/tensorflow/bin/tensorflow-activate
fi

iters=1 # Number of iteration(s) for each run

vars=(
#nodistortions
num_batches="1100"
num_gpus="1 2 4"
batch_size="64"
local_parameter_device="gpu"
variable_update="replicated"
all_reduce_spec="nccl"
#dataset="synthetic imagenet:/home/asis/TF_records"
dataset="imagenet:/home/asis/TF_records"
#dataset="synthetic"
#use_fp16=True
#use_fp16="False True"
model="resnet50 resnet101 resnet152"
)

if [ -z "$1" ] ; then
  BASE_PATH=$PWD
else 
  BASE_PATH=$1
fi

mldlrepo=$(rpm -qa 2>/dev/null | egrep '^mldl-repo-local' | sed 's/.*-\([^-][^-]*-[^-][^-]*\)\.[^\.]*$/_\1/')
results_dir="${BASE_PATH}/results${mldlrepo}"

if ! $TEST ; then
  mkdir -p $results_dir
fi

ext=$(date +%d%b%Y_%H%M%S)

systype=$(lscpu | grep "Model name" | sed 's/.*:\s\s*\([^ ,(][^ ,(]*\).*/\1/')
SMT=$(lscpu | grep "Thread(s) per core" | tr -d ' ' | cut -d ':' -f2)
GPUdriver=$(cat /proc/driver/nvidia/version | grep "NVRM version" | sed 's/.*Kernel Module\s\s*\([^ ][^ ]*\).*/\1/')
HPM=$((git show 2>/dev/null| grep "^commit" || echo default) | head -1 | sed 's/^commit \(.......\).*/\1/')
TFv=$(python -c 'import tensorflow as tf; print(tf.__version__)' 2>/dev/null)
base="${systype}_SMT${SMT}_$(hostname)_${GPUdriver}_hpm-${HPM}_TF-${TFv}"

cmds="python tf_cnn_benchmarks.py"

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
      if [ "$option" == "num_batches" ] ; then 
        if [ $val -lt 100 ] ; then
          nvprof="/usr/local/cuda/bin/nvprof -o"
          nv_extra="--num_warmup_batches=1 --display_every=1"
        fi
      fi 
      if [ "$option" == "dataset" ] ; then 
        for v in $val ; do
          if [ "$v" == "synthetic" ] ; then 
            data_name="synthetic"
            cmds="${cmds}${tmpcmds}\n"
          else 
            data_name=$(echo $v | cut -d':' -f 1)
            data_dir=$(echo $v | cut -d':' -f 2)
            tcmds=$(echo "${tmpcmds}" | sed "s/$/ --data_name="${data_name}" --data_dir="${data_dir}"/g")
            cmds="${cmds}$tcmds\n"
          fi
        done
      else
        if [ "$option" == "model" ] ; then
          if echo $val | grep ":" > /dev/null ; then
            BS=$(echo $val | cut -d':' -f2)
            val=$(echo $val | cut -d':' -f1)
            tcmds=$(echo "${tmpcmds}" | sed "s/$/ --"${option}"="${val}"/g")
            tcmds=$(echo "${tcmds}" | sed 's/--batch_size=[^ ][^ ]*/--batch_size='$BS'/g') 
           else
             tcmds=$(echo "${tmpcmds}" | sed "s/$/ --"${option}"="${val}"/g")
          fi
        else
          tcmds=$(echo "${tmpcmds}" | sed "s/$/ --"${option}"="${val}"/g")
        fi 
        cmds="${cmds}$tcmds\n"
      fi
    done
  fi
  cmds=$(echo -e "$cmds" )
  l=$(echo "$cmds" | wc -l)
  cmds=$(echo "$cmds" | head -$l)
done

cmds=$(echo "$cmds" | sed 's/ /:/g')

cmdno=0
for cmd in $cmds ; do
  cmd=$(echo $cmd | tr ':' ' ')
  logfile=$(echo "$cmd" | tr '_' '-' | tr ' ' '_' | sed 's/--//g' | sed 's/python_tf-cnn-benchmarks.py_//g' | tr '=' '-')
  if echo $logfile | grep data-dir > /dev/null 2>&1 ; then
    logfile=$(echo $logfile | sed 's/_data-dir-[^_$][^_$]*//g')
    DATASET=$(echo $logfile | sed 's/.*\(_data-name-[^_$][^_$]*\)_.*/\1/')
    logfile=$(echo $logfile | sed 's/_data-name-[^_$][^_$]*//g')
    logfile="${logfile}${DATASET}"
  else 
    logfile="${logfile}_data-name-synthetic"
  fi 
  iter=0
  while [ $iter -lt $iters ] ; do
    log="${results_dir}/${base}_${logfile}_${ext}_${iter}"
    filename_length=$(echo "${base}_${logfile}_${ext}_${iter}" | wc -c)
    if [ $filename_length -gt 240 ] ; then
      log=$(echo $log | sed 's/'$logfile'/'$cmdno'/')
    fi
    _cmd=$cmd
    if [ "$nvprof" != "" ] ; then 
      _cmd="${nvprof} ${log}.nvvp ${cmd} ${nv_extra}"
    fi
    log="${log}.log"
    echo "$log"
    if ! $TEST ; then
      echo $_cmd >> ${log} 2>&1
      eval $_cmd >> ${log} 2>&1
      echo
      sleep $SLEEP_TIME
      if [ -f ${BASE_PATH}/extra.sh ] ; then
        ${BASE_PATH}/extra.sh
      fi
    #else
    #  echo $_cmd
    #  echo
    fi
    iter=$(expr $iter + 1)
  done
  cmdno=$(expr $cmdno + 1)
done
