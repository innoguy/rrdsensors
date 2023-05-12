## Add panel data to rrdsensors

One option to add panel related data to rrdsensors without changes to other software would be to capture packets from the ethernet bus and add elements of captured data to the time series database.

For example:

PKT30=$(sudo tshark -f "ether proto 0x07d0 and ether[14]==0x30" -Tfields -e data.data -a packets:1)
PTMPL=${PKT30:80:4}
PTMP=$(echo $(echo "obase=10; ibase=16; ${PTMPL^^}" | bc) "/10" | bc -l )
PFPSL=${PKT30:252:4}
PFPS=$(echo "obase=10; ibase=16; ${PFPSL^^}" | bc)

