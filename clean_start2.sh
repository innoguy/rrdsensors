#!/bin/bash

sudo rm /etc/systemd/system/rrd2.service
sudo rm /etc/systemd/system/rrd2.config
sudo rm .config2
sudo rm rrd2.service
sudo rm /var/log/sensors2.rrd
sudo systemctl stop rrd2
sudo systemctl daemon-reload

