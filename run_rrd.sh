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
	  SSD_TEMP="$(bc -l <<< $(sudo smartctl -d sntrealtek /dev/$DISK -a | grep 'Temperature:' | awk '{print $2}'))"
    if [[ $((SSD_TEMP > 128)) ]]; then SSD_TEMP=$((128-SSD_TEMP)); fi
  elif [[ $CONTROLLER == 'T1' ]]
  then
    if [[ $DISK == 'nvme0n1' ]]
	  then
	    SSD_TEMP="$(bc -l <<< $(sensors | grep 'Composite' | awk '{print $2+0}'))"
	  elif [[ $DISK == 'sda' ]]
	  then 
	    SSD_TEMP="$(bc -l <<< $(smartctl -d ata /dev/sda -a | grep 'Temperature' | awk '{print $10}'))"
      if [[ $((SSD_TEMP > 128)) ]]; then SSD_TEMP=$((128-SSD_TEMP)); fi
	  else
	    SSD_TEMP=0
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
  elif [[ $CONTROLLER == 'M1' ]]
  then
	  SSD_TEMP="0"
  fi
  CPU_TEMP="$(bc -l <<< $(cat /sys/class/thermal/thermal_zone"$TZ_CPU"/temp | awk '{print $0 / 1000}'))"
  CPU_LOAD="$(bc -l <<< $(top -b -n1 | grep 'Cpu(s)' | awk '{print $2 + $4}'))"
  SSD_READ="$(bc -l <<< $(cat /proc/diskstats | grep "${DISK} " | awk '{print $6}'))"
  SSD_WRITE="$(bc -l <<< $(cat /proc/diskstats | grep "${DISK} " | awk '{print $10}'))"
  if [ -z ${IF_CEL} ]; then NET_CEL=0; else NET_CEL="$(echo $(cat /proc/net/dev | grep ${IF_CEL} | awk '{printf "%.0f", $2 + $10}') "/1000" | bc)"; fi
  if [ -z ${IF_WIF} ]; then NET_WIF=0; else NET_WIF="$(echo $(cat /proc/net/dev | grep ${IF_WIF} | awk '{printf "%.0f", $2 + $10}') "/1000" | bc)"; fi
  if [ -z ${IF_ETH} ]; then NET_ETH=0; else NET_ETH="$(echo $(cat /proc/net/dev | grep ${IF_ETH} | awk '{printf "%.0f", $2 + $10}') "/1000" | bc)"; fi
  APP1_CPU="$(bc -l <<< $(ps aux | grep $APP1_PRC |  awk 'BEGIN { sum=0 }  { sum+=$3 } END { print sum }'))"
  APP1_MEM="$(bc -l <<< $(ps aux | grep $APP1_PRC |  awk 'BEGIN { sum=0 }  { sum+=$4 } END { print sum }'))"
  APP2_CPU="$(bc -l <<< $(ps aux | grep $APP2_PRC |  awk 'BEGIN { sum=0 }  { sum+=$3 } END { print sum }'))"
  APP2_MEM="$(bc -l <<< $(ps aux | grep $APP2_PRC |  awk 'BEGIN { sum=0 }  { sum+=$4 } END { print sum }'))"
  APP3_CPU="$(bc -l <<< $(ps aux | grep $APP3_PRC |  awk 'BEGIN { sum=0 }  { sum+=$3 } END { print sum }'))"
  APP3_MEM="$(bc -l <<< $(ps aux | grep $APP3_PRC |  awk 'BEGIN { sum=0 }  { sum+=$4 } END { print sum }'))"
  APP4_CPU="$(bc -l <<< $(ps aux | grep $APP4_PRC |  awk 'BEGIN { sum=0 }  { sum+=$3 } END { print sum }'))"
  APP4_MEM="$(bc -l <<< $(ps aux | grep $APP4_PRC |  awk 'BEGIN { sum=0 }  { sum+=$4 } END { print sum }'))"
 
  if [[ $APP1_CPU == "" ]]; then APP1_CPU=0; fi
  if [[ $APP1_MEM == "" ]]; then APP1_MEM=0; fi
  if [[ $APP2_CPU == "" ]]; then APP2_CPU=0; fi
  if [[ $APP2_MEM == "" ]]; then APP2_MEM=0; fi
  if [[ $APP3_CPU == "" ]]; then APP3_CPU=0; fi
  if [[ $APP3_MEM == "" ]]; then APP3_MEM=0; fi
  if [[ $APP4_CPU == "" ]]; then APP4_CPU=0; fi
  if [[ $APP4_MEM == "" ]]; then APP4_MEM=0; fi

  echo $CPU_LOAD:$CPU_TEMP:$SSD_READ:$SSD_WRITE:$SSD_TEMP:$NET_CEL:$NET_WIF:$NET_ETH:$APP1_CPU:$APP1_MEM:$APP2_CPU:$APP2_MEM:$APP3_CPU:$APP3_MEM:$APP4_CPU:$APP4_MEM
  rrdtool updatev ${DB}.rrd N:$CPU_LOAD:$CPU_TEMP:$SSD_READ:$SSD_WRITE:$SSD_TEMP:$NET_CEL:$NET_WIF:$NET_ETH:$APP1_CPU:$APP1_MEM:$APP2_CPU:$APP2_MEM:$APP3_CPU:$APP3_MEM:$APP4_CPU:$APP4_MEM
  sleep 20
done
 
