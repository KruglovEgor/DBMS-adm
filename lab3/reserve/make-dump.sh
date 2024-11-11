#!/bin/bash
bash $HOME/restore.sh
pg_dump -d postgres -U postgres1 -p 9644 > $HOME/pg_dump.sql
scp $HOME/pg_dump.sql postgres1@pg168:$HOME
bash $HOME/cleanup.sh