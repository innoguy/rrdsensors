#!/bin/bash

#CONTROLLER="NUC"
#CONTROLLER="T1"
#CONTROLLER="RPI"
#CONTROLLER="M1PRO"
#CONTROLLER="A1"


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
VERBOSE="0"
DB="/var/log/sensors"

if [[ $CONTROLLER == 'NUC' ]]
then
    echo "Configuring for NUC"
    IF_ETH="eno1"
	IF_CEL=""
	IF_WIF="wlp2s0"
	DISK="sdb"
	TZ_CPU="2"
elif [[ $CONTROLLER == 'T1' ]]
then
    echo "Configuring for T1"
	IF_ETH="eth2"
	IF_CEL="mlan0"
	IF_WIF="wlp6s0"
	DISK="nvme0n1"
	TZ_CPU="2"
elif [[ $CONTROLLER == 'RPI' ]]
then
    echo "Configuring for RPI"
	IF_ETH="eth0"
	IF_CEL=""
	IF_WIF="wlan0"
	DISK="mmcblk0"
	TZ_CPU="2"
elif [[ $CONTROLLER == 'M1PRO' ]]
then
    echo "Configuring for M1PRO"
	IF_ETH="enp1s0"
	IF_CEL=""
	IF_WIF="wlp6s0"
	DISK="mmcblk1"
	TZ_CPU="2"
elif [[ $CONTROLLER == 'A1' ]]
then
    echo "Configuring for A1"
	IF_ETH="eth3"
	IF_CEL=""
	IF_WIF=""
	DISK="mmcblk1"
	TZ_CPU="0"
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
  if [[ $CONTROLLER == 'NUC' ]]
  then
	SSD_TEMP="$(bc -l <<< $(smartctl -d sntrealtek /dev/sdb -a | grep 'Temperature:' | awk '{print $2}'))"
  elif [[ $CONTROLLER == 'T1' ]]
  then
	SSD_TEMP="$(bc -l <<< $(sensors | grep 'Composite' | awk '{print $2+0}'))"
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
  sleep 2
done
 
