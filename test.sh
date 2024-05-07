#!/bin/sh



MYSQL_TYPE=`cat /root/mysql_install/pkg/mysql_download_type.lst`
MYSQL_TYPE=""


if [ "$MYSQL_TYPE" == "commerial" ];
then
   echo "commerial"
else
   echo "community"
fi
