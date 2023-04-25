#!/bin/bash

set -u

if [ "$EUID" -ne 0 ]
then
    echo "Please run with sudo"
	exit
fi

for i in rrdtool smartmontools ifstat
do
    dpkg -s $i &> /dev/null
    if [ $? -ne 0 ]; then echo "Please install $i using sudo apt install $i"; fi
    exit
done

if [ ! -f "/usr/bin/run_rrd.sh" ]
then
    echo "Please link or copy run_ssd.sh to /usr/bin/run_rrd.sh"
	echo "Before doing so, check the following in file run_rrd.sh:"
    echo "  Set the CONTROLLER variable to the right value (NUC, T1 or RPI)"
	echo "  Set the right values for network interfaces IF_ETH, IF_CEL, IF_WIF"
	echo "  Set the right value for the used DISK (nvme0n1, sdb, mmcblk0,...)"
	echo "  Check if the sensor calculations work correctly on your system"
	exit
fi

if [ ! -f "/etc/systemd/system/rrd.service" ]
then
    echo "Please link or copy rrd.service to /etc/systemd/system/rrd.service"
	echo "Before doing so:"
	echo "    - Make sure the Exec field links to the right executable"
	echo "    - Check if you want the service to restart or not and adapt service file" 
	exit
fi

# Argument parsing 
! getopt --test > /dev/null
if [ ${PIPESTATUS[0]} != 4 ]; then
    echo '`getopt --test` failed in this environment.'
    exit 1
fi

OPTS="hv:d:r:"
LONGOPTS="help,verbose:,database:,rows:"
print_help() {
	cat <<EOF
Usage: $(basename $0) [OTHER OPTIONS]
E.g.: $(basename $0) --out sensors # inserts data points in out.rrd

  -h, --help            this help message
  -v, --verbose         show raw data on stdout
  -d, --database        base filename for the used .rrd file
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

# Store 24 hours every 5 sec (17280 5s intervals)
# Store 30 days every minute (43200 (12 x 5s) intervals)
rrdtool create ${DB}.rrd --start N --step 5 \
    DS:cpu_load:GAUGE:5:U:U \
    DS:cpu_temp:GAUGE:5:U:U \
	DS:ssd_read:COUNTER:5:U:U \
	DS:ssd_write:COUNTER:5:U:U \
    DS:ssd_temp:GAUGE:5:U:U \
    DS:net_cel:COUNTER:5:U:U \
    DS:net_wif:COUNTER:5:U:U \
    DS:net_eth:COUNTER:5:U:U \
    RRA:AVERAGE:0.5:1:17280 RRA:AVERAGE:0.5:12:43200 

if [ ! -f "${DB}.rrd" ]
then
    echo "Something went wrong. "
    echo "Database ${DB}.rrd is not yet in place"
    exit
fi

echo "All set! Now either run the data collector run_rrd.sh manually or activate the systemd service with:"
echo "    sudo systemctl daemon-reload && sudo systemctl start rrd && sudo systemctl status rrd"
