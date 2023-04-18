#!/bin/bash

set -u

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
DB="${HOME}/.scripts/sensors"
INTERFACE="eno1"
ROWS="100000"
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
  CPU_LOAD="$(bc -l <<< $(sensors | awk 'FNR==3 {print $2+0}'))"
  CPU_TEMP="$(bc -l <<< $(uptime | awk '{print $(NF-2)+0}'))"
  NET_IN="$(bc -l <<< $(ifstat  -i ${INTERFACE}  1 1 | awk 'FNR==3 {print $1+0}'))"
  NET_OUT="$(bc -l <<< $(ifstat  -i ${INTERFACE}  1 1 | awk 'FNR==3 {print $2+0}'))"
  rrdtool updatev ${DB}.rrd N:$CPU_LOAD:$CPU_TEMP:$NET_IN:$NET_OUT
  sleep 5
done
 
