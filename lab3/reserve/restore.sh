#!/bin/sh

mkdir  $HOME/vtz5 #  новый каталог для PostgreSQL, как в предыдущей лабораторной работе
echo "Создан каталог $HOME/vtz5"

cd $HOME/backups
BACKUP_DIR=$(ls -td */ | head -n 1) # выбираем последнюю резервную копию
cd $BACKUP_DIR
echo "Выбрана резервная копия $BACKUP_DIR"

tar -xzf base.tar.gz -C $HOME/vtz5
tar -xzf pg_wal.tar.gz -C $HOME/vtz5/pg_wal
echo "Распакована резервная копия"

# создание директорий для tablespace по аналогии с предыдущей лабораторной работой
mkdir $HOME/iks88
echo "Созданы каталог $HOME/vtz5"

tar -xzf 16389.tar.gz -C $HOME/iks88 # OID табличного пространства iks88
echo "Распаковано табличное пространство $HOME/iks88"

chmod -R 750 $HOME/vtz5 $HOME/iks88  # Маска прав должна быть u=rwx (0700) или u=rwx,g=rx (0750).
chown -R postgres1 $HOME/vtz5
chown -R postgres1 $HOME/iks88
echo "Установлены права доступа"

touch $HOME/vtz5/recovery.signal
chown postgres1 $HOME/vtz5/recovery.signal
chmod -R 700 $HOME/vtz5/recovery.signal
echo "Создан файл recovery.signal"

cd $HOME
cp $HOME/configs/pg_hba.conf $HOME/vtz5
cp $HOME/configs/postgresql.conf $HOME/vtz5
echo "Скопированы .conf файлы"

# запуск PostgreSQL
pg_ctl -D $HOME/vtz5 start

# Остановка PostgreSQL
pg_ctl -D $HOME/vtz5 stop

# Изменяем символические ссылки на табличные пространства
cd $HOME/vtz5/pg_tblspc
rm 16389
ln -s $HOME/iks88 16389

cd $HOME
# Запуск PostgreSQL
pg_ctl -D $HOME/vtz5 start