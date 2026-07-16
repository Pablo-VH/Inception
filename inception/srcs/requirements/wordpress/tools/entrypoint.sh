#!/bin/bash
set -e
 
# Leemos las contrasenas desde los secrets montados por docker-compose
DB_PASSWORD=$(cat /run/secrets/db_password)
WP_ADMIN_PASSWORD=$(grep WP_ADMIN_PASSWORD /run/secrets/credentials | cut -d '=' -f2)
WP_USER_PASSWORD=$(grep WP_USER_PASSWORD /run/secrets/credentials | cut -d '=' -f2)
 
cd /var/www/html
 
# 1) Esperamos a que MariaDB acepte conexiones (puede tardar en arrancar)
echo "==> Esperando a MariaDB..."
until mysqladmin ping -h"mariadb" -u"${MYSQL_USER}" -p"${DB_PASSWORD}" --silent; do
    sleep 2
done
echo "==> MariaDB lista."
 
# 2) Si WordPress no esta ya instalado en el volumen, lo descargamos
#    y lo configuramos. Esto solo pasa la PRIMERA vez (el volumen persiste).
if [ ! -f "/var/www/html/wp-config.php" ]; then
    echo "==> Descargando WordPress..."
    wp core download --allow-root
 
    echo "==> Generando wp-config.php..."
    wp config create \
        --dbname="${MYSQL_DATABASE}" \
        --dbuser="${MYSQL_USER}" \
        --dbpass="${DB_PASSWORD}" \
        --dbhost="mariadb:3306" \
        --allow-root
 
    echo "==> Instalando WordPress (usuario administrador)..."
    wp core install \
        --url="${DOMAIN_NAME}" \
        --title="${WP_TITLE}" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --skip-email \
        --allow-root
 
    echo "==> Creando segundo usuario (no administrador)..."
    wp user create \
        "${WP_USER}" "${WP_USER_EMAIL}" \
        --role=editor \
        --user_pass="${WP_USER_PASSWORD}" \
        --allow-root
 
    echo "==> WordPress instalado correctamente."
fi
 
# Nos aseguramos de que php-fpm es dueno de los ficheros
chown -R nobody:nobody /var/www/html
 
# 3) Arrancamos php-fpm en PRIMER PLANO -> PID 1 del contenedor
exec php-fpm83 -F