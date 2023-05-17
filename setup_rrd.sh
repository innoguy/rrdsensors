#!/bin/bash

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
	echo "OUT3=$PWD/graph_app" >> .config
    echo "# Graph dimensions" >> .config
    echo "HEIGHT=800" >> .config
    echo "MIN_WIDTH=1000" >> .config
	echo "# Applications to monitor" >> .config
	echo "APP1_PRC=AppRun" >> .config
	echo "APP1_TXT=Nucleus" >> .config
	echo "APP2_PRC=screenhub-play" >> .config
	echo "APP2_TXT=Player" >> .config
	echo "APP3_PRC=anydesk" >> .config
	echo "APP3_TXT=Anydesk" >> .config
	echo "APP4_PRC=teamviewer" >> .config
    echo "APP4_TXT=Teamvwr" >> .config
    echo "# System information" >> .config
    if [ $(lscpu | grep -c "6305E") -ge 1 ] 
    then 
        echo "CONTROLLER=T1" >> .config
    elif [ $(lscpu | grep -c "E3950") -ge 1 ]
    then
        echo "CONTROLLER=M1PRO" >> .config
    elif [ $(lscpu | grep -c "4250U") -ge 1 ]
    then
        echo "CONTROLLER=NUC" >> .config
	elif [ $(lscpu | grep -c "Cortex-A53") -ge 1 ]
    then
        echo "CONTROLLER=A1" >> .config
	elif [ $(lscpu | grep -c "N3160") -ge 1 ]
    then
        echo "CONTROLLER=M1" >> .config
    else 
        echo "Unrecognized controller type"
        echo "CONTROLLER=Unknown" >> .config
        exit
    fi

    IF_ETH=""
	for i in "eth2" "eth0"
	do
		if $(echo $(ip link) | grep -q $i) 
		then 
			IF_ETH=$i
			break
		fi
	done

    IF_WIF=""
	for i in "wlp6s0" "wlan0" "wlp2s0"
	do
		if $(echo $(ip link) | grep -q $i) 
		then 
			IF_WIF=$i
			break
		fi
	done

    IF_CEL=""
	for i in "wwan0" "mlan0" "ppp0"
	do
		if $(echo $(ip link) | grep -q $i) 
		then 
			IF_CEL=$i
			break
		fi
	done

    DISK="Unknown"
    for i in "sdb" "nvme0n1" "mmcblk1" "sda" "mmcblk2"
	do
	    if [ -b "/dev/"$i ]
		then
		    DISK=$i
			break
		fi
	done

    TZ_CPU=""
    for i in 2 0
	do
	    if [ -f "/sys/class/thermal/thermal_zone"$i"/temp" ]
	    then
		    TZ_CPU=$i
			break
	    fi
    done

	echo "IF_ETH="$IF_ETH >> .config
	echo "IF_WIF="$IF_WIF >> .config
	echo "IF_CEL="$IF_CEL >> .config
	echo "DISK="$DISK >> .config
	echo "TZ_CPU="$TZ_CPU >> .config
}

if [ -f $PWD/.config ]
then
    while true; do
        read -p "Do you want to generate a new .config file? " yn
        case $yn in
            [Yy]* ) create_config && break;;
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

TOOLS="rrdtool"
if [[ $CONTROLLER == 'T1' ]]
then 
	TOOLS= $TOOLS" smartmontools"
fi

for i in $TOOLS
do
    dpkg -s $i &> /dev/null
    if [ $? -ne 0 ]
	then 
	  echo "Please install $i using sudo apt install $i"
	  exit 
	fi
done

if [ ! -f "$PWD/rrd.service" ]
then
	echo "[Unit]" > rrd.service
	echo "Description=Log sensor values to round robin database" >> rrd.service
	echo "DefaultDependencies=no" >> rrd.service
	echo "After=network.target" >> rrd.service
	echo "" >> rrd.service
	echo "[Service]" >> rrd.service
	echo "ExecStart=$PWD/run_rrd.sh " >> rrd.service
	echo "Restart=always" >> rrd.service
	echo "RestartSec=5s" >> rrd.service
	echo "[Install]" >> rrd.service
    echo "WantedBy=multi-user.target" >> rrd.service
fi

if [ ! -f "/etc/systemd/system/rrd.service" ]
then
    ln -s $PWD/rrd.service /etc/systemd/system/rrd.service
    ln -s $PWD/.config /etc/systemd/system/rrd.config
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

# Store 7 days every 1 min (10080 1min intervals)
# Store 3 months every 1 hour (2160 1h intervals)
rrdtool create ${DB}.rrd --start N --step 60 \
    DS:cpu_load:GAUGE:60:U:U \
    DS:cpu_temp:GAUGE:60:U:U \
	DS:ssd_read:COUNTER:60:U:U \
	DS:ssd_write:COUNTER:60:U:U \
    DS:ssd_temp:GAUGE:60:U:U \
    DS:net_cel:COUNTER:60:U:U \
    DS:net_wif:COUNTER:60:U:U \
    DS:net_eth:COUNTER:60:U:U \
    DS:app1_cpu:GAUGE:60:U:U \
    DS:app1_mem:GAUGE:60:U:U \
    DS:app2_cpu:GAUGE:60:U:U \
    DS:app2_mem:GAUGE:60:U:U \
    DS:app3_cpu:GAUGE:60:U:U \
    DS:app3_mem:GAUGE:60:U:U \
    DS:app4_cpu:GAUGE:60:U:U \
    DS:app4_mem:GAUGE:60:U:U \
    RRA:AVERAGE:0.5:1:10080 RRA:AVERAGE:0.5:60:2160 


if [ ! -f "${DB}.rrd" ]
then
    echo "Something went wrong. "
    echo "Database ${DB}.rrd is not yet in place"
    exit
fi

sudo systemctl daemon-reload
sudo systemctl enable rrd
sudo systemctl start rrd
sudo systemctl status rrd
