#!/bin/sh

DATE=`date +%F`
DIR=/tmp
BASES="$1"
#MYSQL_USER
USER=root
#MYSQL_PASS
PASSWD="qwerty"

#Функция бэкапа БД
backupDB() {
        echo -n "Dumping $BASES..."
        ((mysqldump -u $USER -h localhost -p$PASSWD $BASES | gzip -c > $DIR/$BASES$DATE.sql.gz) \
        && echo -n "ok "; du -h $DIR/$BASES$DATE.sql.gz | awk '{print($1)}') \
        || echo "ERROR!!!"

}

if [ -n "$BASES" ];then 
	echo "\n## Dumping MySQL Databases ##"
	backupDB
	exit 0
fi