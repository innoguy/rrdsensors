#!/bin/bash

source .config2

####################
# argument parsing #
####################
! getopt --test > /dev/null
if [ ${PIPESTATUS[0]} != 4 ]; then
    echo '`getopt --test` failed in this environment.'
    exit 1
fi

OPTS="hv:d:o:t:s:e:r:h:w"
LONGOPTS="help,verbose:,database:,output:,start:,end:,rra:,height:,min-width:"
print_help() {
	cat <<EOF
Usage: $(basename $0) [OTHER OPTIONS]
E.g.: $(basename $0) --out ${HOME}/graph # produces graph.png

  -h, --help            this help message
  -v, --verbose         show raw data on stdout
  -d, --database        base filename for the .rrd file
  -o, --output          base filename for the .png file
  -t, --type            all, net or system in graph
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
TIME="60"
RRA="0"
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
		-t|--type)
			TYPE="$2"
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
	"#FFF700"
	"#EF843C"
	"#1F78C1"
	"#A05DA0"
    "#A01DA0"
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

NOW=`date +%s`
if [[ ! START =~ [N] ]]
then
    START=$(bc -l <<< ${START/N/$NOW})
fi
if [[ ! END =~ [N] ]]
then
    END=$(bc -l <<< ${END/N/$NOW})
fi


LINE_WIDTH=1
ALPHA=30 # used in area RGBA

LOUT="Panels"
echo $START
LSTART=`date +%F\ %T -d @$START`
LEND=`date +%F\ %T -d @$END`

rrdtool graph \
    ${OUT}.png \
    --title "$LOUT statistics for $HOSTNAME from $LSTART to $LEND" \
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
    DEF:panel_tmp=${DB}.rrd:panel_tmp:AVERAGE \
        VDEF:panel_tmp_max=panel_tmp,MAXIMUM \
        VDEF:panel_tmp_avg=panel_tmp,AVERAGE \
        CDEF:panel_tmp_norm=panel_tmp,panel_tmp_max,/,100,\* \
        CDEF:panel_tmp_norm_avg=panel_tmp,POP,panel_tmp_avg,100,\*,panel_tmp_max,/ \
        LINE1:panel_tmp_norm${COLORS[0]}:"%Panel_temp\t" \
        LINE0.5:panel_tmp_norm_avg${COLORS[0]}:dashes \
        AREA:panel_tmp_norm${COLORS[0]}${ALPHA} \
        GPRINT:panel_tmp_max:"(max\: %.2lf \g" \
        GPRINT:panel_tmp_avg:"(avg\:%.2lf)" \
        COMMENT:"\n" \
    DEF:panel_fps=${DB}.rrd:panel_fps:AVERAGE \
        VDEF:panel_fps_max=panel_fps,MAXIMUM \
        VDEF:panel_fps_avg=panel_fps,AVERAGE \
        CDEF:panel_fps_norm=panel_fps,panel_fps_max,/,100,\* \
        CDEF:panel_fps_norm_avg=panel_fps,POP,panel_fps_avg,100,\*,panel_fps_max,/ \
        LINE1:panel_fps_norm${COLORS[1]}:"%Panel_fps\t" \
        LINE0.5:panel_fps_norm_avg${COLORS[1]}:dashes \
        GPRINT:panel_fps_max:"(max\: %.2lf\g" \
        GPRINT:panel_fps_avg:"(avg\: %.2lf)" \
        COMMENT:"\n" \
