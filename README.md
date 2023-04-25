Author	: Guy Coen

This system logs key system parameters in a time series database and graphs them.

To install:
- edit run_rrd.sh and set appropriate CONTROLLER (NUC or T1)
- check if all sensor readings at the bottom of run_rrd.sh work correctly
- sudo ./setup_rrd.sh

To graph:
- ./graph_rrd.sh --start N-600 
will create a graph.png of the last 600 seconds in the current directory


