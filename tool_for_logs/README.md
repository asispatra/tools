# System stat collection tool
A tool to collect mpstat, freestat, iostat, vmstat, nvidia_smi in specified time interval.
Note: Please make sure these commands are installed.

To collect system stats
```
bash startLogging.sh
```

To stop collection
```
bash stopLogging.sh
```

You can chage interval in startLogging.sh
```
CMD_INTERVAL=5 # default
```

Logs will be collected under directory, which is specified in Log_PATH, This can be change as the user want.
```
$ cat Log_PATH
stat_logs 
```

To find GPU utilization you can use gpu.sh, which will be copied to the logs directory.
```
$ bash gpu.sh logs_nvidia_smi.log 0         # For GPU 0
GPU Utilization, Memory Utilization, Memory Allocation
(27 51.75 68), (21 65.87 85), 3133/16280
```
