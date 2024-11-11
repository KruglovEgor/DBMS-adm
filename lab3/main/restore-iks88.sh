#!/bin/sh

pg_ctl -D $HOME/vtz5 stop

mkdir $HOME/new_iks88
echo "Создана директория $HOME/new_iks88"

cd $HOME/backups
BACKUP_DIR=$(ls -td */ | head -n 1) # выбираем последнюю резервную копию
cd $BACKUP_DIR
echo "Выбрана резервная копия $BACKUP_DIR"

tar -xzf 16389.tar.gz -C $HOME/new_iks88
echo "Распаковано табличное пространство"

chown -R postgres1 $HOME/new_iks88
chmod 750 $HOME/new_iks88
echo "Установлены права доступа"

cd $HOME/vtz5/pg_tblspc
rm 16389
ln -s $HOME/new_iks88 16389
echo "Изменены символические ссылки"

cd $HOME
pg_ctl -D $HOME/new_iks88 start