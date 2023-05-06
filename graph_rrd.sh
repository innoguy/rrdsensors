#!/bin/bash

set -u
source .config

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
    ${OUT1}.png \
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
    DEF:cpu_load=${DB}.rrd:cpu_load:AVERAGE \
        VDEF:cpu_load_max=cpu_load,MAXIMUM \
        VDEF:cpu_load_avg=cpu_load,AVERAGE \
        CDEF:cpu_load_norm=cpu_load,cpu_load_max,/,100,\* \
        CDEF:cpu_load_norm_avg=cpu_load,POP,cpu_load_avg,100,\*,cpu_load_max,/ \
        LINE1:cpu_load_norm${COLORS[0]}:"%CPU\t" \
        LINE0.5:cpu_load_norm_avg${COLORS[0]}:dashes \
        AREA:cpu_load_norm${COLORS[0]}${ALPHA} \
        GPRINT:cpu_load_max:"(max\: %.2lf \g" \
        GPRINT:cpu_load_avg:"(avg\:%.2lf)" \
        COMMENT:"\n" \
    DEF:cpu_temp=${DB}.rrd:cpu_temp:AVERAGE \
        VDEF:cpu_temp_max=cpu_temp,MAXIMUM \
        VDEF:cpu_temp_avg=cpu_temp,AVERAGE \
        CDEF:cpu_temp_norm=cpu_temp,cpu_temp_max,/,100,\* \
        CDEF:cpu_temp_norm_avg=cpu_temp,POP,cpu_temp_avg,100,\*,cpu_temp_max,/ \
        LINE1:cpu_temp_norm${COLORS[1]}:"%CPUT\t" \
        LINE0.5:cpu_temp_norm_avg${COLORS[1]}:dashes \
        GPRINT:cpu_temp_max:"(max\: %.2lf\g" \
        GPRINT:cpu_temp_avg:"(avg\: %.2lf)" \
        COMMENT:"\n" \
    DEF:ssd_read=${DB}.rrd:ssd_read:AVERAGE \
        VDEF:ssd_read_max=ssd_read,MAXIMUM \
        VDEF:ssd_read_avg=ssd_read,AVERAGE \
        CDEF:ssd_read_norm=ssd_read,ssd_read_max,/,100,\* \
        CDEF:ssd_read_norm_avg=ssd_read,POP,ssd_read_avg,100,\*,ssd_read_max,/ \
        LINE1:ssd_read_norm${COLORS[2]}:"%SSDR\t" \
        LINE0.5:ssd_read_norm_avg${COLORS[2]}:dashes \
        GPRINT:ssd_read_max:"(max\: %.2lf\g" \
        GPRINT:ssd_read_avg:"(avg\: %.2lf)" \
        COMMENT:"\n" \
    DEF:ssd_write=${DB}.rrd:ssd_write:AVERAGE \
        VDEF:ssd_write_max=ssd_write,MAXIMUM \
        VDEF:ssd_write_avg=ssd_write,AVERAGE \
        CDEF:ssd_write_norm=ssd_write,ssd_write_max,/,100,\* \
        CDEF:ssd_write_norm_avg=ssd_write,POP,ssd_write_avg,100,\*,ssd_write_max,/ \
        LINE1:ssd_write_norm${COLORS[3]}:"%SSDW\t" \
        LINE0.5:ssd_write_norm_avg${COLORS[3]}:dashes \
        GPRINT:ssd_write_max:"(max\: %.2lf\g" \
        GPRINT:ssd_write_avg:"(avg\: %.2lf)" \
        COMMENT:"\n" \
    DEF:ssd_temp=${DB}.rrd:ssd_temp:AVERAGE \
        VDEF:ssd_temp_max=ssd_temp,MAXIMUM \
        VDEF:ssd_temp_avg=ssd_temp,AVERAGE \
        CDEF:ssd_temp_norm=ssd_temp,ssd_temp_max,/,100,\* \
        CDEF:ssd_temp_norm_avg=ssd_temp,POP,ssd_temp_avg,100,\*,ssd_temp_max,/ \
        LINE1:ssd_temp_norm${COLORS[4]}:"%SSDT\t" \
        LINE0.5:ssd_temp_norm_avg${COLORS[4]}:dashes \
        GPRINT:ssd_temp_max:"(max\: %.2lf\g" \
        GPRINT:ssd_temp_avg:"(avg\: %.2lf)" \
        COMMENT:"\n" 

rrdtool graph \
    ${OUT2}.png \
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
    DEF:net_cel=${DB}.rrd:net_cel:AVERAGE \
        VDEF:net_cel_max=net_cel,MAXIMUM \
        VDEF:net_cel_avg=net_cel,AVERAGE \
        CDEF:net_cel_norm=net_cel,net_cel_max,/,100,\* \
        CDEF:net_cel_norm_avg=net_cel,POP,net_cel_avg,100,\*,net_cel_max,/ \
        LINE1:net_cel_norm${COLORS[0]}:"%IFCEL\t" \
        LINE0.5:net_cel_norm_avg${COLORS[0]}:dashes \
        GPRINT:net_cel_max:"(max\: %.2lf KB/s\g" \
        GPRINT:net_cel_avg:"(avg\: %.2lf KB/s)" \
        COMMENT:"\n" \
    DEF:net_wif=${DB}.rrd:net_wif:AVERAGE \
        VDEF:net_wif_max=net_wif,MAXIMUM \
        VDEF:net_wif_avg=net_wif,AVERAGE \
        CDEF:net_wif_norm=net_wif,net_wif_max,/,100,\* \
        CDEF:net_wif_norm_avg=net_wif,POP,net_wif_avg,100,\*,net_wif_max,/ \
        LINE1:net_wif_norm${COLORS[1]}:"%IFWIF\t" \
        LINE0.5:net_wif_norm_avg${COLORS[1]}:dashes \
        GPRINT:net_wif_max:"(max\: %.2lf KB/s\g" \
        GPRINT:net_wif_avg:"(avg\: %.2lf KB/s)" \
        COMMENT:"\n" \
    DEF:net_eth=${DB}.rrd:net_eth:AVERAGE \
        VDEF:net_eth_max=net_eth,MAXIMUM \
        VDEF:net_eth_avg=net_eth,AVERAGE \
        CDEF:net_eth_norm=net_eth,net_eth_max,/,100,\* \
        CDEF:net_eth_norm_avg=net_eth,POP,net_eth_avg,100,\*,net_eth_max,/ \
        LINE1:net_eth_norm${COLORS[2]}:"%IFETH\t" \
        LINE0.5:net_eth_norm_avg${COLORS[2]}:dashes \
        GPRINT:net_eth_max:"(max\: %.2lf KB/s\g" \
        GPRINT:net_eth_avg:"(avg\: %.2lf KB/s)" \
        COMMENT:"\n" 

rrdtool graph \
    ${OUT3}.png \
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
    DEF:app_cpu=${DB}.rrd:app_cpu:AVERAGE \
        VDEF:app_cpu_max=app_cpu,MAXIMUM \
        VDEF:app_cpu_avg=app_cpu,AVERAGE \
        CDEF:app_cpu_norm=app_cpu,app_cpu_max,/,100,\* \
        CDEF:app_cpu_norm_avg=app_cpu,POP,app_cpu_avg,100,\*,app_cpu_max,/ \
        LINE1:app_cpu_norm${COLORS[0]}:"%APPCPU\t" \
        LINE0.5:app_cpu_norm_avg${COLORS[0]}:dashes \
        GPRINT:app_cpu_max:"max\: %.2lf\t" \
        GPRINT:app_cpu_avg:"(avg\: %.2lf)" \
        COMMENT:"\n" \
    DEF:app_mem=${DB}.rrd:app_mem:AVERAGE \
        VDEF:app_mem_max=app_mem,MAXIMUM \
        VDEF:app_mem_avg=app_mem,AVERAGE \
        CDEF:app_mem_norm=app_mem,app_mem_max,/,100,\* \
        CDEF:app_mem_norm_avg=app_mem,POP,app_mem_avg,100,\*,app_mem_max,/ \
        LINE1:app_mem_norm${COLORS[1]}:"%APPMEM\t" \
        LINE0.5:app_mem_norm_avg${COLORS[1]}:dashes \
        GPRINT:app_mem_max:"max\: %.2lf\t" \
        GPRINT:app_mem_avg:"(avg\: %.2lf)" \
        COMMENT:"\n" \
 