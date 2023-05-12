#!/bin/bash

if [ "$EUID" -ne 0 ]
then
    echo "Please run with sudo"
	exit
fi

create_config() {
    echo "#!/bin/bash" > .config2
    echo "# Location of database file" >> .config2
    echo "DB=/var/log/sensors2" >> .config2
    echo "# Where the graphs are stored" >> .config2
    echo "OUT=$PWD/graph_pan" >> .config2
    echo "# Graph dimensions" >> .config2
    echo "HEIGHT=800" >> .config2
    echo "MIN_WIDTH=1000" >> .config2
}

if [ -f $PWD/.config2 ]
then
    while true; do
        read -p "Do you want to generate a new .config2 file? " yn
        case $yn in
            [Yy]* ) create_config && break;;
            [Nn]* ) break;;
            * ) echo "Please answer yes or no.";;
        esac
    done
else
    create_config
fi

cat .config2
while true; do
	read -p "Is this data OK and do you want to proceed? " yn
	case $yn in
		[Yy]* ) break;;
		[Nn]* ) exit;;
		* ) echo "Please answer yes or no.";;
	esac
done

source .config2

TOOLS="tshark"
for i in $TOOLS
do
    dpkg -s $i &> /dev/null
    if [ $? -ne 0 ]
	then 
	  echo "Please install $i using sudo apt install $i"
	  exit 
	fi
done

if [ ! -f "$PWD/rrd2.service" ]
then
	echo "[Unit]" > rrd2.service
	echo "Description=Log sensor values to round robin database" >> rrd2.service
	echo "DefaultDependencies=no" >> rrd2.service
	echo "After=network.target" >> rrd2.service
	echo "" >> rrd2.service
	echo "[Service]" >> rrd2.service
	echo "ExecStart=$PWD/run_rrd.sh " >> rrd2.service
	echo "Restart=on-failure" >> rrd2.service
	echo "RestartSec=5s" >> rrd2.service
	echo "[Install]" >> rrd2.service
    echo "WantedBy=multi-user.target" >> rrd2.service
fi

if [ ! -f "/etc/systemd/system/rrd2.service" ]
then
    ln -s $PWD/rrd2.service /etc/systemd/system/rrd2.service
    ln -s $PWD/.config2 /etc/systemd/system/rrd2.config
fi

if [ ! -f "/etc/systemd/system/rrd2.service" ]
then
    echo "Please link or copy rrd2.service to /etc/systemd/system/rrd2.service"
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
    DS:panel_tmp:GAUGE:60:U:U \
    DS:panel_fps:GAUGE:60:U:U \
    RRA:AVERAGE:0.5:1:10080 RRA:AVERAGE:0.5:60:2160 

if [ ! -f "${DB}.rrd" ]
then
    echo "Something went wrong. "
    echo "Database ${DB}.rrd is not yet in place"
    exit
fi

sudo systemctl daemon-reload
sudo systemctl start rrd2
sudo systemctl status rrd2
