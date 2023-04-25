#!/bin/bash

set -u

CONTROLLER="NUC"
#CONTROLLER="T1"

# Argument parsing 
! getopt --test > /dev/null
if [ ${PIPESTATUS[0]} != 4 ]; then
    echo '`getopt --test` failed in this environment.'
    exit 1
fi

OPTS="hv:d:i:r:"
LONGOPTS="help,verbose:,database:,interface:,rows:"
print_help() {
	cat <<EOF
Usage: $(basename $0) [OTHER OPTIONS]
E.g.: $(basename $0) --out sensors # inserts data points in out.rrd

  -h, --help            this help message
  -v, --verbose         show raw data on stdout
  -d, --database        base filename for the used .rrd file
  -i, --interface       network interface to be traced
  -r, --rows            maximum number of rows in the RRD file (defaults to
                        100000 and, at one datapoint per second, it's also the
                        maximum duration of recorded and visualised data)
EOF
}
! PARSED=$(getopt --options=${OPTS} --longoptions=${LONGOPTS} --name "$0" -- "$@")
if [ ${PIPESTATUS[0]} != 0 ]; then
    # getopt has complained about wrong arguments to stdout
    exit 1
fi
# read getopt's output this way to handle the quoting right
eval set -- "$PARSED"
VERBOSE="0"
DB="/var/log/sensors"

if [[ $CONTROLLER=='NUC' ]]
then
    echo "Configuring for NUC"
    INTERFACE="eno1"
	CPU_TEMP_LINE=9
	CPU_TEMP_COLUMN=3
elif [[ $CONTROLLER=='T1' ]]
then
    echo "Configuring for T1"
    INTERFACE='wlp6s0'
fi

while true; do
	case "$1" in
		-h|--help)
			print_help
			exit
			;;
		-v|--verbose)
			VERBOSE=1
			shift
			;;
		-d|--database)
			DB="$2"
			shift 2
			;;
		-i|--interface)
			INTERFACE="$2"
			shift 2
			;;
		-r|--rows)
			ROWS="$2"
			shift 2
			;;
		--)
			shift
			break
			;;
		*)
			echo "argument parsing error"
			exit 1
	esac
done

while [ true ] 
do
  if [[ $CONTROLLER=='NUC' ]]
  then
	CPU_TEMP="$(bc -l <<< $(sensors | awk 'FNR==9 {print $3+0}'))"
	SSD_TEMP="$(bc -l <<< $(smartctl -d sntrealtek /dev/sdb -a | grep 'Temperature:' | awk '{print $2}'))"
	CPU_LOAD="$(bc -l <<< $(top -b -n1 | grep 'Cpu(s)' | awk '{print $2 + $4}'))"
	SSD_READ="$(bc -l <<< $(cat /proc/diskstats | grep "sdb " | awk '{print $6}'))"
	SSD_WRITE="$(bc -l <<< $(cat /proc/diskstats | grep "sdb " | awk '{print $10}'))"
	NET_IN="$(bc -l <<< $(ifstat  -i ${INTERFACE}  1 1 | awk 'FNR==3 {print $1+0}'))"
	NET_OUT="$(bc -l <<< $(ifstat  -i ${INTERFACE}  1 1 | awk 'FNR==3 {print $2+0}'))"
  elif [[ $CONTROLLER=='T1' ]]
  then
	CPU_TEMP="$(bc -l <<< $(sensors | grep 'Core 0' | awk '{print $3+0}'))"
	SSD_TEMP="$(bc -l <<< $(sensors | grep 'Composite' | awk '{print $2+0}'))"
	CPU_LOAD="$(bc -l <<< $(top -b -n1 | grep 'Cpu(s)' | awk '{print $2 + $4}'))"
	SSD_READ="$(bc -l <<< $(cat /proc/diskstats | grep "nvme0n1 " | awk '{print $6}'))"
	SSD_WRITE="$(bc -l <<< $(cat /proc/diskstats | grep "nvme0n1 " | awk '{print $10}'))"
	NET_IN="$(bc -l <<< $(ifstat  -i ${INTERFACE}  1 1 | awk 'FNR==3 {print $1+0}'))"
	NET_OUT="$(bc -l <<< $(ifstat  -i ${INTERFACE}  1 1 | awk 'FNR==3 {print $2+0}'))"
  fi
  rrdtool updatev ${DB}.rrd N:$CPU_LOAD:$CPU_TEMP:$SSD_READ:$SSD_WRITE:$SSD_TEMP:$NET_IN:$NET_OUT
  sleep 2
done
 
