#!/bin/sh

#
#Version 1.4 6/19/2017 ryan_mcdowell@yahoo.com
#

#
#Editable constants
#
CONFIGFILE=/usr/local/etc/mrbackup.conf
LOGGING=1
DRYRUN=0
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games

#
#Set root directory for backups
#
HOME=$1


RSYNC=`which rsync`

#
#
#logging
#$1=log message, $2=level (0=errors, 1=informational)
#
#
logging () 
{
if [ "$LOGGING" = "1" ]
then
  echo $2":"$1
elif [ "$2" = "0" ]
then
  echo $2":"$1
fi
}


#---------------------------------------------------------------------------
#
#parse_config_line
#$1 is line to parse
#
#---------------------------------------------------------------------------
parse_config_line()
{
USER=""
METHOD=""
HARDLINK="true"
HOSTNAME=""
DIR=""
DAYS=""
WEEKS=""
MONTH=""

local LINE="`head -n $1 $CONFIGFILE | tail -n 1`" 
local ISCOMMENT=`echo $LINE | grep ^#`
local VAR=""
local VALUE=""

if [ "$ISCOMMENT" != "" ]
then
logging "parse_config_line(): Line $1 is a comment" 1 
return 1
fi

for ITEM in $LINE
do
VAR=`echo $ITEM | cut -f1 -d"=" | tr 'A-Z' 'a-z'`
VALUE=`echo $ITEM | cut -f2 -d"="`
if [ "$VAR" = "user" ]
then
  USER=$VALUE
elif [ "$VAR" = "method" ]
then
  METHOD=$VALUE
elif [ "$VAR" = "hostname" ]
then
  HOSTNAME=$VALUE
elif [ "$VAR" = "dir" ]
then
  DIR=$VALUE
elif [ "$VAR" = "hardlink" ]
then
  HARDLINK=$VALUE
else
  logging "parse_config_line(): Unknown option $VAR" 0
  return 1
fi
done
logging "parse_config_line(): Users:"$USER" Method:"$METHOD" Hardlink:"$HARDLINK 1

return 0
}

#---------------------------------------------------------------------------
#
#rysnc_it
#
#---------------------------------------------------------------------------
rsync_it ()
{
local RSYNCOPTS=" -aR -H --delete"



if [ "$HARDLINK" = "true" ]
then
        LOCATION=$HOME"INCREMENTAL/"$HOSTNAME"/"

elif [ "$HARDLINK" = "false" ]
then
        LOCATION=$HOME"NONINCREMENTAL/"$HOSTNAME"/"
else
        logging "rsync_it(): invalid value HARDLINK:"$HARDLINK
fi

#check to make sure the destination directory exists
if [ ! -d $LOCATION ]
then
        mkdir $LOCATION
fi
if [ ! -w $LOCATION ]
then
        logging "rsync_it(): Unable to write to destination directory" 0
        return 1
fi



#check RSYNC version
local VERSION="`$RSYNC --version | grep version`"

if [ "$VERSION" = "" ]
then
  logging "rsync_it(): Unable to find rsync" 0
  return 1
fi

#OK, lets run rsync now
if [ "$METHOD" = "local" ]
then
  logging  "EXEC: $RSYNC$RSYNCOPTS $DIR $LOCATION" 1
  if [ "$DRYRUN" = "0" ]
  then
    $RSYNC$RSYNCOPTS $DIR $LOCATION
    return 0
  fi
elif [ "$METHOD" = "ssh" ]
  then
  logging  "EXEC: $RSYNC -e ssh $RSYNCOPTS $USER@$HOSTNAME:$DIR $LOCATION" 1
  if [ "$DRYRUN" = "0" ]
  then
    $RSYNC -e ssh $RSYNCOPTS $USER@$HOSTNAME:$DIR $LOCATION
    return 0
  fi
else
  logging "rysnc_it(): Unsupported method $METHOD" 0
  return 1
fi

}

#---------------------------------------------------------------------------
#
#delete_hardlinks
#
#---------------------------------------------------------------------------
delete_hardlinks ()
{

COUNT=`ls $HOME"ARCHIVES" | wc -l`
while [ "$COUNT" -gt "$1" ]
do
  DELETEDIR=$HOME"ARCHIVES/"`ls $HOME"ARCHIVES" | sort -n | head -1`
  logging "EXEC: rm -Rf $DELETEDIR" 1
  rm -Rf $DELETEDIR
  COUNT=`ls $HOME"/ARCHIVES" | wc -l`
done
}

#---------------------------------------------------------------------------
#
#hardlink_it
#
#---------------------------------------------------------------------------
hardlink_it ()
{


LOCATION=$HOME"INCREMENTAL/"

DATE=`date +%F`

if [ ! -d $HOME"ARCHIVES/"$DATE ]
then
 mkdir $HOME"ARCHIVES/"$DATE
fi

echo $LOCATION
logging "EXEC: cp -al $LOCATION$1 $HOME"ARCHIVES/"$DATE" 1

if [ -d $HOME"ARCHIVES/"$DATE$1 ]
then 
 logging "Directory $HOME"ARCHIVES/"$DATE$1 already exists, failing to hardlink." 0
 return 0
fi

if [ "$DRYRUN" = "0" ]
then
  cp -al $LOCATION$1 $HOME"ARCHIVES/"$DATE"/"
fi

}

#---------------------------------------------------------------------------
#
#Main
#
#---------------------------------------------------------------------------

#Get the number of lines in the configuration file
LINES=`wc -l $CONFIGFILE | cut -f1 -d " "`
LINE=1

#process each line in the configuration file and see what to do
while [ "$LINE" -le "$LINES" ]
do
logging "Processing line $LINE of the configuration file $CONFIGFILE..." 1
parse_config_line $LINE
if [ "$?" = "1" ]
then
  logging "Skipping configuration line $LINE due to errors" 0
else
  rsync_it
  HOSTLIST="$HOSTLIST $HOSTNAME"
fi
LINE=`expr $LINE + 1`
done

HOSTLIST=`echo $HOSTLIST | sed -e 's/ /\n/g' | sort | uniq`

for HOST in $HOSTLIST
do
hardlink_it $HOST
done

delete_hardlinks 5
