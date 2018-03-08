#!/bin/bash

startCommit=7fc628d041fd7b7fafceccf60ba1f52448c50330
endCommit=5726e36c0cf251807bdfadeecc9d84a3defede7c

commits_URL="https://github.com/tensorflow/benchmarks/commits/master"

notDONE=1
ALLOWED=0

while [ $notDONE -eq 1 ] ; do
    wget $commits_URL -O pageout -o tmp
    commitList=$(grep "sha btn btn-outline BtnGroup-item" pageout | sed 's/.*commit\/\([^"][^"]*\).*/\1/')
    #echo $commitList ; exit
    for COMMIT in $commitList ; do
        if [ "$COMMIT" == "$startCommit" ] ; then
            ALLOWED=1
        fi
        if [ $ALLOWED -eq 1 ] ; then
            echo $COMMIT
            git clone https://github.com/tensorflow/benchmarks.git
            cd benchmarks
            git checkout $COMMIT
            cd scripts/tf_cnn_benchmarks
            cp /home/asis/test/hpms/asis_runs.sh .
            bash asis_runs.sh
            cd /home/asis/test/hpms
            rm -rf benchmarks 
        fi
        if [ "$COMMIT" == "$endCommit" ] ; then
            ALLOWED=0
            notDONE=0
        fi
    done
    commits_URL=$(grep "Newer.*Older" pageout | sed 's/.*"\([^"][^"]*\?after=[^"][^"]*\)".*/\1/')
done
