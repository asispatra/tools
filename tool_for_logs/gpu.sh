#!/bin/bash

if [ $# -ne 2 ] ; then
	echo "Usage: 'gpu.sh <file> <gpu_id>'"
	exit
fi

file=$1
id=$2

avggpu=0
avgmem=0

n=0
lines=$(grep " $id," $file | tr ' ' '*')
for l in $(echo "$lines") ; do
	l=$(echo $l | tr '*' ' ')
	gpu=$(echo $l | cut -d" " -f5)
	mem=$(echo $l | cut -d" " -f7)
	umem=$(echo $l | cut -d" " -f11)
	#echo "$gpu $mem $tmem $umem"

	if [ $n -eq 0 ] ; then 
		mingpu=$gpu
		maxgpu=$gpu
		minmem=$mem
		maxmem=$mem
		tmem=$(echo $l | cut -d" " -f9)
		maxumem=$umem
	else
		if [ $gpu -lt $mingpu ] ; then mingpu=$gpu ; fi
		if [ $gpu -gt $maxgpu ] ; then maxgpu=$gpu ; fi
		if [ $mem -lt $minmem ] ; then minmem=$mem ; fi
		if [ $mem -gt $maxmem ] ; then maxmem=$mem ; fi
		if [ $umem -gt $maxumem ] ; then maxumem=$umem ; fi
	fi
	avggpu=$(echo "scale=2; ($avggpu * $n + $gpu)/($n + 1)" | bc)
	avgmem=$(echo "scale=2; ($avgmem * $n + $mem)/($n + 1)" | bc)
	n=$(expr $n + 1)
done
echo "GPU Utilization, Memory Utilization, Memory Allocation"
echo "($mingpu $avggpu $maxgpu), ($minmem $avgmem $maxmem), $maxumem/$tmem"
