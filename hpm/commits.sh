#!/bin/bash

commits=(
7fc628d041fd7b7fafceccf60ba1f52448c50330
5726e36c0cf251807bdfadeecc9d84a3defede7c
)
BASE_PATH=$PWD
for COMMIT in "${commits[@]}" ; do 
    echo $COMMIT
    git clone https://github.com/tensorflow/benchmarks.git
    cd benchmarks
    git checkout $COMMIT
    cd scripts/tf_cnn_benchmarks
    cp ${BASE_PATH}/allmodels.sh .
    cp ${BASE_PATH}/alexnet.sh .
    bash allmodels.sh ${BASE_PATH}
    bash alexnet.sh ${BASE_PATH}
    cd ${BASE_PATH}
    rm -rf benchmarks
done
