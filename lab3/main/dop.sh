#!/bin/sh

# 2024-11-25 19:39:09.175746+03

pg_ctl -D $HOME/vtz5 stop

cd $HOME/backups
BACKUP_DIR=$(ls -td */ | head -n 1) # выбираем последнюю резервную копию
cd $BACKUP_DIR

rm -rf $HOME/vtz5/*
tar -xzf base.tar.gz -C $HOME/vtz5
chmod -R 750 $HOME/vtz5

cd $HOME
rm -rf vtz5/pg_wal/*
scp -r postgres1@pg173:$HOME/wal_archive/* $HOME/vtz5/pg_wal/

#ручками прописываемrecovery_target_time='наше время в формате "YYYY-MM-DD HH:MI:SS"'

touch $HOME/vtz5/recovery.signal
chmod -R 700 $HOME/vtz5/recovery.signal

pg_ctl -D $HOME/vtz5 start