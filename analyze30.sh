#!/bin/bash
PKT30=$(sudo tshark -f "ether proto 0x07d0 and ether[14]==0x30" -Tfields -e eth.src -a packets:10)
IFS=' ' read -a array <<< "$PKT30"
IFS=$'\n' sorted=($(sort -r <<<"${array[*]}"))
FIRST=$(echo ${sorted[0]} | sed 's/://g' )
FUP=${FIRST^^}
HIGHEST=$(echo "obase=10; ibase=16; ${FUP:6:12}" | bc)
echo $HIGHEST


