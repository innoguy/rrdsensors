#!/bin/bash

source /etc/systemd/system/rrd.config

if [ -z "$CONTROLLER" ]
then
    echo "CONTROLLER not yet set. Please uncomment the right one in run_ssh.sh"
	exit
fi

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
  if [[ $CONTROLLER == 'NUC' ]]
  then
	SSD_TEMP="$(bc -l <<< $(smartctl -d sntrealtek /dev/sdb -a | grep 'Temperature:' | awk '{print $2}'))"
  elif [[ $CONTROLLER == 'T1' ]]
  then
	SSD_TEMP="$(bc -l <<< $(sensors | grep 'Composite' | awk '{print $2+0}'))"
	if [[ $SSD_TEMP == "" ]]
	then
	    SSD_TEMP="$(bc -l <<< $(sensors | grep 'temp1:' | awk 'NR==1 {print $2+0}'))"
	fi
  elif [[ $CONTROLLER == 'RPI' ]]
  then
	SSD_TEMP="$(bc -l <<< $(sensors | grep 'temp1:' | awk '{print $2+0}'))"
  elif [[ $CONTROLLER == 'M1PRO' ]]
  then
	SSD_TEMP="$(bc -l <<< $(sensors | grep 'temp1:' | awk '{print $2+0}'))"
  elif [[ $CONTROLLER == 'A1' ]]
  then
	SSD_TEMP="0"
  fi
  CPU_TEMP="$(bc -l <<< $(cat /sys/class/thermal/thermal_zone"$TZ_CPU"/temp | awk '{print $0 / 1000}'))"
  CPU_LOAD="$(bc -l <<< $(top -b -n1 | grep 'Cpu(s)' | awk '{print $2 + $4}'))"
  SSD_READ="$(bc -l <<< $(cat /proc/diskstats | grep "${DISK} " | awk '{print $6}'))"
  SSD_WRITE="$(bc -l <<< $(cat /proc/diskstats | grep "${DISK} " | awk '{print $10}'))"
  if [ -z ${IF_CEL} ]; then NET_CEL=0; else NET_CEL="$(bc -l <<< $(cat /proc/net/dev | grep ${IF_CEL} | awk '{printf "%.0f", $2 + $10}'))"; fi
  if [ -z ${IF_WIF} ]; then NET_WIF=0; else NET_WIF="$(bc -l <<< $(cat /proc/net/dev | grep ${IF_WIF} | awk '{printf "%.0f", $2 + $10}'))"; fi
  if [ -z ${IF_ETH} ]; then NET_ETH=0; else NET_ETH="$(bc -l <<< $(cat /proc/net/dev | grep ${IF_ETH} | awk '{printf "%.0f", $2 + $10}'))"; fi
  rrdtool updatev ${DB}.rrd N:$CPU_LOAD:$CPU_TEMP:$SSD_READ:$SSD_WRITE:$SSD_TEMP:$NET_CEL:$NET_WIF:$NET_ETH
  sleep 20
done
 
