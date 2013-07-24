#!/bin/sh

#Директория бэкапов
SDIR="/home/backup"
#Директория ключей
SKEY="/root/.ssh/id_rsa"
#Файл логов
SLOG="$SDIR/backup.log"
#Файл работы программы
PID_FILE="$SDIR/backup.pid"
#Мыло
ADMIN_EMAIL="admin@example.com"
#Текущая дата
DATE=`date +%F`
#Удаленное хранилеще, я использую яндекс.диск
YA="/media/yandex.disk"

	#Если скрипт запущен, отправляем письмо
	if [ -e $SDIR/$PID_FILE ]; then
		echo "Эта задача уже выполняется или предыдущая была завершена с ошибкой на `hostname`" | mail -s "Ошибка создания резервной копии на `hostname`..." $ADMIN_EMAIL
		exit
	fi
	touch $PID_FILE
	#Весь вывод в лог
	exec >> $SLOG 2>&1
	#Парсим файл, получем что бэкапить
	cat $SDIR/backup.ini | while read domain from mysqln ; do
		#Путь до бэкапов
		destination="$SDIR/domains/$domain"
		#Проверка существования каталогов
		if [ ! -d $SDIR/domains/$domain ]; then 
			mkdir $SDIR/domains/$domain
		fi
		if [ ! -d $YA/$domain ]; then
			mkdir $YA/$domain
		fi
		echo "$DATE *** $domain Резервное копирование началось">>$SLOG
		#Синхронизируем папку с бэкапами, получем ее локально
		start=$(date +%s)
		rsync --archive --one-file-system --delete -e "ssh -i $SKEY" "$from" "$destination/latest" || (echo -e "Ошибка при rsyncing $domain. \n\n Для получения дополнительной информации см $SLOG:\n\n `tail $SLOG`" | mail -s "rsync error" $ADMIN_EMAIL & continue)
		finish=$(date +%s)
		echo "$DATE *** RSYNC работал $((finish - start)) секунд">>$SLOG
		#Проверка на наличие БД
		if [ -n "$mysqln" ];then
			#Выполняем скрипт создания дампа Mysql на удаленной машине
			ssh root@192.168.0.1 /etc/mysqlback.sh $mysqln >>$SLOG &
			#Ждем его завершения
			wait
			#Получем файл базы и кладем его в локльную папку бэкапа
			scp root@192.168.0.1:/tmp/$mysqln$DATE.sql.gz /$destination/latest
			#Удаляем дамп базы
			ssh root@192.168.0.1 rm -f /tmp/$mysqln$DATE.sql.gz
		fi
		#Создаем копию бэкапа с текущей датой
		cp --archive --link "$destination/latest" "$destination/$DATE"
		#Удаляем дамп базы из общей папки
		rm -rf /$destination/latest/$mysqln$DATE.sql.gz
		#Проверяем есть ли шифрованный архив с тем же именем на удаленном сервере
		#if [ ! -f $YA/$domain/$DATE.tar.aes ]; then
			#Переходим в каталог с бэкапом
			#cd $destination
			#Создаем шифрованный архив
			#tar -cf - $DATE | aescrypt -e -p "qwerty" - >$DATE.tar.aes
			#Закачиваем на удаленный сервер
			#mv $DATE.tar.aes $YA/$domain/
		#fi
		#Проверяем есть ли архив с тем же именем на удаленном сервере
		if [ ! -f $YA/$domain/$DATE.tar.gz ]; then
			#Переходим в каталог с бэкапом
			cd $destination
			#Создаем архив
			tar -czf $DATE.tar.gz $DATE/
			#Закачиваем на удаленный сервер
			mv $DATE.tar.gz $YA/$domain/
		fi
		#Удаляем бэкапы старше недели
		find "$destination" -maxdepth 1 -ctime +7 -type d -path "$destination/????-??-??" -exec rm -r -f {} \;
		echo "`date` *** Размер $domain/latest сейчас `du -sh $destination/latest | awk '{print $1}'` ">>$SLOG
		echo "`date` *** $domain Резервное копирование завершено">>$SLOG
		echo "`date` *** Общий объем `du -sh $destination | awk '{print $1}'`">>$SLOG
		echo "------------------------------------------------------------------">>$SLOG
	done
	#Удаляем архивы на удаленном сервере старше 7 дней
	find "$YA" -type f -mtime +7 -exec rm -r -f {} \;
	rm $PID_FILE