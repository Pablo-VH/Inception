#!/bin/bash
set -e
 
# Leemos las contrasenas desde los Docker secrets (montados en /run/secrets/)
DB_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)
DB_PASSWORD=$(cat /run/secrets/db_password)
 
# Si la base de datos aun no existe en el volumen, la inicializamos
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "==> Inicializando MariaDB por primera vez..."
    mysql_install_db --user=mysql --datadir=/var/lib/mysql > /dev/null
 
    # Arrancamos mysqld temporalmente en background SOLO para poder
    # ejecutar comandos SQL de configuracion inicial.
    mysqld --user=mysql --datadir=/var/lib/mysql --skip-networking &
    pid="$!"
 
    # Esperamos a que el socket este listo
    until mysqladmin ping --silent 2>/dev/null; do
        sleep 1
    done
 
    mysql -u root <<-EOSQL
        CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;

	-- Eliminamos cuentas anonimas que Alpine crea por defecto
	DELETE FROM mysql.user WHERE User='';
 
        -- Usuario normal para WordPress
        CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
        GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
 
        -- Password de root
        ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
 
        FLUSH PRIVILEGES;
EOSQL


 
    # Paramos el mysqld temporal de forma limpia
    mysqladmin -u root -p"${DB_ROOT_PASSWORD}" shutdown
    wait "$pid"
    echo "==> Inicializacion completada."
fi
 
# Arrancamos MariaDB en PRIMER PLANO -> este es el proceso PID 1 del contenedor
exec mysqld --user=mysql --datadir=/var/lib/mysql --bind-address=0.0.0.0
 
