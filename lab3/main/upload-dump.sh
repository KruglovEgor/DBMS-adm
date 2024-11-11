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