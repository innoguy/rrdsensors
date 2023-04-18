shell scripts are expected in 
$HOME/.scripts directory

service definition file should be copied to 
$HOME/.config/systemd/user/rrd.service

then enable with
systemctl --user enable rrd

then start with
systemctl --user start rrd
