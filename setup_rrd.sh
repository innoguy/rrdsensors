#!/bin/bash

set -u

if [ "$EUID" -ne 0 ]
then
    echo "Please run with sudo"
	exit
fi

create_config() {
	echo "#!/bin/bash" > .config
	echo "# Location of database file" >> .config
	echo "DB=/var/log/sensors" >> .config
	echo "# Where the graphs are stored" >> .config
	echo "OUT1=$PWD/graph_sys" >> .config
	echo "OUT2=$PWD/graph_net" >> .config
	echo "# Graph dimensions" >> .config
	echo "HEIGHT=800" >> .config
	echo "MIN_WIDTH=1000" >> .config

	echo "# System information" >> .config
	CPU="$(lscpu | grep 'Model\ name' | awk '{print $5}')"
	case ${CPU:0:8} in
		"i5-4250U")
			echo "CONTROLLER=NUC" >> .config
			;;

		"6305E")
			echo "CONTROLLER=T1" >> .config
			;;

		"E3950")
			echo "CONTROLLER=M1PRO" >> .config
			;;
		*)
			echo "Unrecognized controller type"
			echo "CONTROLLER=Unknown" >> .config
			exit
			;; 
	esac

	IF_ETH=$(ip link | awk '{print $2}' | grep -e ^[eth,eno] | awk 'NR==1 {print $1}' | sed 's/ //g' | sed 's/://g')
	echo "IF_ETH="$IF_ETH >> .config

	IF_WIF=$(ip link | awk '{print $2}' | grep -e ^wl | sed 's/ //g' | sed 's/://g')
	echo "IF_WIF="$IF_WIF >> .config

	IF_CEL=$(ip link | awk '{print $2}' | grep -e ^m | sed 's/ //g' | sed 's/://')
	echo "IF_CEL="$IF_CEL >> .config

	if [ -b "/dev/sdb" ]
	then
		DISK="sdb"
	elif [ -b "/dev/nvme0n1" ]
	then
		DISK="nvme0n1"
	elif [ -b "/dev/mmcblk1" ]
	then 
		DISK="mmcblk1"
	else
		DISK="Unknown"
		echo "Unable to identify disk used. Please correct in .config file"
	fi
	echo "DISK="$DISK >> .config


	if [ -f /sys/class/thermal/thermal_zone2/temp ]
	then
		TZ_CPU=2
	elif [ -f /sys/class/thermal/thermal_zone0/temp ]
	then	
	    TZ_CPU=0
	else
		echo "Unable to identify CPU temperature sensor. Please correct in .config file"
	fi
	echo "TZ_CPU="$TZ_CPU >> .config
}

if [ -f $PWD/.config ]
then
    while true; do
        read -p "Do you want to generate a new .config file? " yn
        case $yn in
            [Yy]* ) create_config;;
            [Nn]* ) break;;
            * ) echo "Please answer yes or no.";;
        esac
    done
else
    create_config
fi

cat .config
while true; do
	read -p "Is this data OK and do you want to proceed? " yn
	case $yn in
		[Yy]* ) break;;
		[Nn]* ) exit;;
		* ) echo "Please answer yes or no.";;
	esac
done

source .config

for i in rrdtool
do
    dpkg -s $i &> /dev/null
    if [ $? -ne 0 ]
	then 
	  echo "Please install $i using sudo apt install $i"
	  exit 
	fi
done

if [[ $CONTROLLER == 'NUC' ]]
then
    for i in smartmontools 
    do
        dpkg -s $i &> /dev/null
        if [ $? -ne 0 ]
	    then 
	        echo "Please install $i using sudo apt install $i"
	        exit 
	    fi
    done
fi

if [ ! -f "/usr/bin/cfd_run_rrd.sh" ]
then
    sudo cat $PWD/.config $PWD/run_rrd.sh > cfd_run_rrd.sh
	sudo cp $PWD/cfd_run_rrd.sh /usr/bin
	sudo chmod a+x /usr/bin/cfd_run_rrd.sh
fi

if [ ! -f "/etc/systemd/system/rrd.service" ]
then
    echo ln -s $PWD/rrd.service /etc/systemd/system/rrd.service
fi

if [ ! -f "/etc/systemd/system/rrd.service" ]
then
    echo "Please link or copy rrd.service to /etc/systemd/system/rrd.service"
	echo "Before doing so:"
	echo "  Make sure the Exec field links to the right executable"
	echo "  Check if you want the service to restart or not and adapt service file" 
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

sudo systemctl daemon-reload
sudo systemctl start rrd
sudo systemctl status rrd