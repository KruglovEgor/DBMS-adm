# Этап 1. Резервное копирование

## Включение режима архивирования WAL на основном узле
Создаем директорию wal_archive в домашнем каталоге на резервном узле:
```sh
mkdir wal_archive
```

Редактируем файл postgresql.conf на основном узле:
```sh
wal_level = replica
archive_mode = on
archive_command = 'scp %p postgres1@pg173:$HOME/wal_archive/%f'
```

Сгенерируем SSH-ключ для автоматической авторизации scp на основном узле:
```sh
ssh-keygen -t rsa -b 4096 -C "postgres1@pg168"
ssh-copy-id -i $HOME/.ssh/id_rsa.pub postgres1@pg173
```

Сразу же проверим доступ (на основном узле):
```sh
ssh postgres1@pg173
```

##  Настройка полного резервного копирования (pg_basebackup) по расписанию
Создаем директории для хранения резервных копий на обоих узлах:
```sh
mkdir $HOME/backups
```

На основном узле редактируем pg_hba.conf - добавим разрешение подключения для репликации:
```sh
local   replication     all                     peer
```

Создадим скрипт backup.sh для резервного копипрования на основном узле:
```sh
#!/bin/sh
CURRENT_DATE=$(date "+%Y-%m-%d_%H:%M:%S")
BACKUP_DIR="$HOME/backups/$CURRENT_DATE"
mkdir -p "$BACKUP_DIR"

# Создаем полную резервную копию
pg_basebackup -D "$BACKUP_DIR" -F tar -z -P -p 9644 # 9644 - порт указанный в основном узле postgresql.conf

# Копируем резервную копию на резервный узел
ssh postgres1@pg173 "mkdir BACKUP_DIR"
scp $BACKUP_DIR/*.tar.gz postgres1@pg173:$BACKUP_DIR

# Удаляем резервные копии старше 7 дней на основном узле
find $HOME/backups/ -type d -mtime +7 -exec rm -rf {} \;

# Удаляем WAL-файлы старше 7 дней на основном узле
find $HOME/vtz5/pg_wal -type f -mtime +7 -exec rm -f {} \; # по предыдущему заданию WAL-файлы хранятся в '~/vtz/pg_wal'

# Удаляем резервные копии старше 28 дней на резервном узле
ssh postgres1@pg173 'find $HOME/backups/ -type d -mtime +28 -exec rm -rf {} \;'

# Удаляем WAL-файлы старше 28 дней на резервном узле
ssh postgres1@pg173 'find $HOME/wal_archive/ -type f -mtime +28 -exec rm -f {} \;'
```

Загрузим скрипт в корень на основном узле и сделаем его исполняемым:
```sh
chmod +x backup.sh
```

Проверим работоспособность скрипта:
```sh
bash $HOME/backup.sh >> $HOME/backup.log 2>&1
cat backup.log
```

Добавляем задачу в cron на основном узле:
```sh
crontab -e
```

Добавляем строчку (в 1 минуту, в 0 часов, в любой день месяца, в любой месяц, в понедельник):
```sh
1 0 * * 1 $HOME/backup.sh >> $HOME/backup.log 2>&1
```

## Расчет объема резервных копий
Подсчитать, каков будет объем резервных копий спустя месяц работы системы, исходя из следующих условий:
* Средний объем новых данных в БД за сутки: 550МБ.
* Средний объем измененных данных за сутки: 950МБ.

Подсчет:
--потом--
--потом--
--потом--
--потом--
--потом--
--потом--
--потом--


# Этап 2. Потеря основного узла

Настроим postgresql.conf для резервного узла (скопируем с основного и изменим):
```sh
#archive_command = 'scp %p postgres1@pg173:$HOME/wal_archive/%f'

restore_command = 'cp $HOME/wal_archive/%f "%p"'
```

Также скопируем pg_hba.conf на резервный узел без изменений. Поместим данные файлы в директорию configs:
```sh
mkdir configs
```

Напишем скрипт для восстановления базы данных restore.sh на резервном узле:
```sh
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
```

Также для возможности повторения сценария создадим cleanup.sh:
```sh
#!/bin/sh

pg_ctl -D $HOME/vtz5 stop

rm -rf $HOME/vtz5
rm -rf $HOME/iks88
```

Сделаем файлы restore.sh и cleanup.sh исполняемыми:
```sh
chmod +x $HOME/restore.sh
chmod +x $HOME/cleanup.sh
```

Проверим работу скрипта для восстановления restore.sh, предварительно остановив СУБД на основном узле
```sh
bash $HOME/restore.sh
```

После проверки очистим резервный узел с помощью cleanup.sh:
```sh
bash $HOME/cleanup.sh
```

# Этап 3. Повреждение файлов БД

Для проверки создадим таблицу iks88_test_table в табличном пространстве iks88:
```SQL
psql -d postgres -U postgres1 -p 9644
CREATE TABLE iks88_test_table (id SERIAL PRIMARY KEY, data TEXT) TABLESPACE iks88;
INSERT INTO iks88_test_table (data) VALUES ('test 1');
```

Проверим доступность записанных данных:
```SQL
SELECT * FROM iks88_test_table;
```
```
 id |  data
----+--------
  1 | test 1
(1 строка)
```

Сделаем бэкап:
```sh
bash $HOME/backup.sh >> $HOME/backup.log 2>&1
```

Удалим табличное пространство iks88 (симуляция сбоя):
```sh
rm -rf $HOME/iks88
```

Попробуем получить ранее записанные данные в таблицу iks88_test_table:
```sh
psql -d postgres -U postgres1 -p 9644
SELECT * FROM iks88_test_table;
```
Ожидаемо получаем ошибку:
```
ERROR:  could not open file "pg_tblspc/16389/PG_16_202307071/5/16403": No such file or directory
```

Попробуем перезапустить СУБД:
```sh
pg_ctl -D $HOME/vtz5 stop
pg_ctl -D $HOME/vtz5 start
```

СУБД запускается, но данные остаются недоступны:
```SQL
psql -d postgres -U postgres1 -p 9644
SELECT * FROM iks88_test_table;
```
```
ERROR:  could not open file "pg_tblspc/16389/PG_16_202307071/5/16403": No such file or directory
```

Напишем скрипт resrtore-iks88.sh , который с помощью последнего бэкапа восстановит iks88 в новом месте:
```sh
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
pg_ctl -D $HOME/vtz5 start
```

Загрузим и сделаем resrtore-iks88.sh исполняемым:
```sh
chmod +x restore-iks88.sh
```

Выполним загруженный скрипт:
```sh
bash $HOME/restore-iks88.sh
```

Проверим доступность данных в таблице iks88_test_table:
```SQL
psql -d postgres -U postgres1 -p 9644
SELECT * FROM iks88_test_table;
```

Видим, что данные снова доступны:
```
 id |  data
----+--------
  1 | test 1
(1 строка)
```

# Этап 4. Логическое повреждение данных

Создадим 2 таблицы, связанных через foreign key. Также добавим в них по 3 записи:
 ```SQL
psql -d postgres -U postgres1 -p 9644

CREATE TABLE step4_table_1 (
    id SERIAL PRIMARY KEY,
    data TEXT
);

CREATE TABLE step4_table_2 (
    id INTEGER REFERENCES step4_table_1(id) ON DELETE CASCADE,
    data TEXT
);

INSERT INTO step4_table_1 (data) VALUES 
    ('Data 1'), 
    ('Data 2'), 
    ('Data 3');

INSERT INTO step4_table_2 (id, data) VALUES 
    (1, 'Related Data 1'), 
    (2, 'Related Data 2'), 
    (3, 'Related Data 3');
```

Проверим содержимое таблиц:
```SQL
SELECT * FROM step4_table_1;
```

```
 id |  data
----+--------
  1 | Data 1
  2 | Data 2
  3 | Data 3
(3 строки)
```

```SQL
SELECT * FROM step4_table_2;
```

```
 id |      data
----+----------------
  1 | Related Data 1
  2 | Related Data 2
  3 | Related Data 3
(3 строки)
```

Сделаем бэкап:
```sh
bash $HOME/backup.sh >> $HOME/backup.log 2>&1
```

Получим время:
```SQL
SELECT now();
```
```
              now
-------------------------------
 2024-11-11 20:29:28.371813+03
(1 строка)
```

Испортим данные во второй таблице step4_table_2:
```SQL
ALTER TABLE step4_table_2 DROP CONSTRAINT step4_table_2_id_fkey;

UPDATE step4_table_2 SET id = 10 WHERE id = 1;
UPDATE step4_table_2 SET id = 20 WHERE id = 2;
UPDATE step4_table_2 SET id = 30 WHERE id = 3;

ALTER TABLE step4_table_2 
    ADD CONSTRAINT step4_table_2_id_fkey 
    FOREIGN KEY (id) REFERENCES step4_table_1(id) 
    NOT VALID;
```

Попробуем теперь прочитать данные:
```SQL
SELECT * FROM step4_table_2;
```

```
 id |      data
----+----------------
 10 | Related Data 1
 20 | Related Data 2
 30 | Related Data 3
(3 строки)
```

Теперь перейдем на резервный узел:
```sh
ssh postgres1@pg173
```

Также настроим ssh соединение с помощью ключа:
```sh
ssh-keygen -t rsa -b 4096 -C "postgres1@pg173"
ssh-copy-id -i ~/.ssh/id_rsa.pub postgres1@pg168
```

Напишем, загрузим и сделаем исполняемым скрипт make-dump.sh для создания дампа:
```sh
#!/bin/bash
bash $HOME/restore.sh
pg_dump -d postgres -U postgres1 -p 9644 > $HOME/pg_dump.sql
scp $HOME/pg_dump.sql postgres1@pg168:$HOME
bash $HOME/cleanup.sh
```

Выполним скрипт make-dump.sh:
```sh
bash make-dump.sh
```

Вернемся к основному узлу и восстановим данные из дампа:
```sh
ssh postgres1@pg168
```

Напишем, загрузим и сделаем исполняемым скрипт upload-dump.sh:
```sh
#!/bin/bash

# Удаление всех таблиц в базе данных 'postgres'
psql -d postgres -U postgres1 -p 9644 -c "
DO \$\$ DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public') LOOP
        EXECUTE 'DROP TABLE IF EXISTS ' || quote_ident(r.tablename) || ' CASCADE';
    END LOOP;
END \$\$;
"

# Загрузка данных из дампа
psql -d postgres -U postgres1 -p 9644 -f $HOME/pg_dump.sql
```

Запустим скрипт upload-dump.sh:
```sh
bash $HOME/upload-dump.sh
```

Проверим, что данные восстановлены:
```SQL
SELECT * FROM step4_table_1;
```

```
 id |  data
----+--------
  1 | Data 1
  2 | Data 2
  3 | Data 3
(3 строки)
```

```SQL
SELECT * FROM step4_table_2;
```

```
 id |      data
----+----------------
  1 | Related Data 1
  2 | Related Data 2
  3 | Related Data 3
(3 строки)
```
