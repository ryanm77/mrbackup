# mrbackup


Sample crontab:
```
0 02 * * * /usr/local/sbin/mrbackup.sh /backup/ | /usr/bin/logger -t mrbackup.sh
```
Sample config file:
```
user=root method=ssh hostname=server1 dir=/etc
user=root method=ssh hostname=server1 dir=/home
user=root method=ssh hostname=server1 hardlink=false dir=/mnt/Virtual_Machines
user=root method=local hostname=mrbackup dir=/usr/local
user=minecraft method=ssh hostname=minecraft dir=/opt/msm
```
