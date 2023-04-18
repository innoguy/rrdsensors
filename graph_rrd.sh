#!/bin/bash

set -u

####################
# argument parsing #
####################
! getopt --test > /dev/null
if [ ${PIPESTATUS[0]} != 4 ]; then
    echo '`getopt --test` failed in this environment.'
    exit 1
fi

OPTS="hv:d:o:s:e:r:h:w"
LONGOPTS="help,verbose:,database:,output:,start:,end:,rra:,height:,min-width:"
print_help() {
	cat <<EOF
Usage: $(basename $0) [OTHER OPTIONS]
E.g.: $(basename $0) --out ${HOME}/graph # produces graph.png

  -h, --help            this help message
  -v, --verbose         show raw data on stdout
  -d, --database        base filename for the .rrd file
  -o, --output          base filename for the .png file
  -s, --start           start time of graph (defaults to start of archive)
  -e, --end             end time of graph (defaults to end of archive)
  -r, --rra             rra index to use for first and last element   
      --height          graph height (in pixels, default: 800)
      --min-width       minimum graph width (default: 1000)
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
OUT="graph"
DB="sensors"
ROWS="100000"
TIME="60"
RRA="0"
HEIGHT="800"
MIN_WIDTH="1000"
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
		-o|--output)
			OUT="$2"
			shift 2
			;;
		-t|--time)
			TIME="$2"
			shift 2
			;;
		-s|--start)
			START="$2"
			shift 2
			;;
		-e|--end)
			END="$2"
			shift 2
			;;
		-r|--rra)
			RRA="$2"
			shift 2
			;;
		--height)
			HEIGHT="$2"
			shift 2
			;;
		--min-width)
			MIN_WIDTH="$2"
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


COLORS=(
	"#FF0000"
	"#00FF00"
	"#0000FF"
	"#00FFFF"
	"#EF843C"
	"#1F78C1"
	"#705DA0"
)

if [[ -v START ]]
then
    echo "Start graph at command line argument ${START}"
else
    START="$(rrdtool first --rraindex ${RRA} ${DB}.rrd)"
    echo "Start graph at start of archive ${START}"
fi
if [[ -v END ]]
then
    echo "Finish graph at command line argument ${END}"
else
    END="$(rrdtool last ${DB}.rrd)"
    echo "Finish graph at end of archive ${END}"
fi

LINE_WIDTH=1
ALPHA=30 # used in area RGBA

rrdtool graph \
    ${OUT}.png \
    --title "Controller statistics normalised to their maximum values" \
    --watermark "$(date)" \
    --vertical-label "% of maximum" \
    --slope-mode \
    --alt-y-grid \
    --left-axis-format "%.0lf%%" \
    --rigid \
    --start ${START} --end ${END} \
    --width ${MIN_WIDTH} \
    --height ${HEIGHT} \
    --color CANVAS#181B1F \
    --color BACK#111217 \
    --color FONT#CCCCDC \
    DEF:cpu_temp=${DB}.rrd:cpu_temp:AVERAGE \
        VDEF:cpu_temp_max=cpu_temp,MAXIMUM \
        VDEF:cpu_temp_avg=cpu_temp,AVERAGE \
        CDEF:cpu_temp_norm=cpu_temp,cpu_temp_max,/,100,\* \
        CDEF:cpu_temp_norm_avg=cpu_temp,POP,cpu_temp_avg,100,\*,cpu_temp_max,/ \
        LINE1:cpu_temp_norm${COLORS[0]}:"%TEMP\t" \
        LINE0.5:cpu_temp_norm_avg${COLORS[0]}:dashes \
        GPRINT:cpu_temp_max:"(max\: %.2lf\g" \
        GPRINT:cpu_temp_avg:"(avg\: %.2lf)" \
        COMMENT:"\n" \
    DEF:cpu_load=${DB}.rrd:cpu_load:AVERAGE \
        VDEF:cpu_load_max=cpu_load,MAXIMUM \
        VDEF:cpu_load_avg=cpu_load,AVERAGE \
        CDEF:cpu_load_norm=cpu_load,cpu_load_max,/,100,\* \
        CDEF:cpu_load_norm_avg=cpu_load,POP,cpu_load_avg,100,\*,cpu_load_max,/ \
        LINE1:cpu_load_norm${COLORS[1]}:"%CPU\t" \
        LINE0.5:cpu_load_norm_avg${COLORS[1]}:dashes \
	    AREA:cpu_load_norm${COLORS[1]}${ALPHA} \
        GPRINT:cpu_load_max:"(max\: %.2lf \g" \
        GPRINT:cpu_load_avg:"(avg\:%.2lf)" \
        COMMENT:"\n" \
    DEF:net_in=${DB}.rrd:net_in:AVERAGE \
        VDEF:net_in_max=net_in,MAXIMUM \
        VDEF:net_in_avg=net_in,AVERAGE \
        CDEF:net_in_norm=net_in,net_in_max,/,100,\* \
        CDEF:net_in_norm_avg=net_in,POP,net_in_avg,100,\*,net_in_max,/ \
        LINE1:net_in_norm${COLORS[2]}:"%In\t" \
        LINE0.5:net_in_norm_avg${COLORS[2]}:dashes \
        GPRINT:net_in_max:"(max\: %.2lf KB/s\g" \
        GPRINT:net_in_avg:"(avg\: %.2lf KB/s)" \
        COMMENT:"\n" \
    DEF:net_out=${DB}.rrd:net_out:AVERAGE \
        VDEF:net_out_max=net_out,MAXIMUM \
        VDEF:net_out_avg=net_out,AVERAGE \
        CDEF:net_out_norm=net_out,net_out_max,/,100,\* \
        CDEF:net_out_norm_avg=net_out,POP,net_out_avg,100,\*,net_out_max,/ \
        LINE1:net_out_norm${COLORS[3]}:"%Out\t" \
        LINE0.5:net_out_norm_avg${COLORS[3]}:dashes \
        GPRINT:net_out_max:"(max\: %.2lf KB/s\g" \
        GPRINT:net_out_avg:"(avg\: %.2lf KB/s)" \
        COMMENT:"\n" \
