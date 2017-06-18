# mrbackup


Sample crontab:

0 02 * * * /usr/local/sbin/mrbackup.sh /backup/ | /usr/bin/logger -t mrbackup.sh
