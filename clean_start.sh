#!/bin/bash

sudo rm /etc/systemd/system/rrd.service
sudo rm /etc/systemd/system/rrd.config
sudo rm .config
sudo rm rrd.service
sudo rm /var/log/sensors.rrd
sudo systemctl stop rrd
sudo systemctl daemon-reload

