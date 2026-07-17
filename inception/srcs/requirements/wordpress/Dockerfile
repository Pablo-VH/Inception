FROM alpine:3.23.5
 
# php-fpm + extensiones que WordPress necesita + mysql-client (para esperar a la BD) + curl para wp-cli
RUN apk update && apk add --no-cache \
    php83 \
    php83-fpm \
    php83-mysqli \
    php83-json \
    php83-curl \
    php83-dom \
    php83-exif \
    php83-fileinfo \
    php83-mbstring \
    php83-openssl \
    php83-xml \
    php83-zip \
    php83-gd \
    php83-phar \
    php83-session \
    php83-tokenizer \
    php83-xmlwriter \
    php83-simplexml \
    php83-iconv \
    curl \
    bash \
    mysql-client \
    wget
 
# Creamos el enlace simbolico para poder llamar "php" a secas
RUN ln -s /usr/bin/php83 /usr/bin/php
 
# Instalamos wp-cli, la herramienta que usaremos para configurar
# WordPress por linea de comandos, sin pasar por el navegador
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp
 
# Configuracion de php-fpm: que escuche en el puerto 9000 de todas las interfaces
COPY conf/www.conf /etc/php83/php-fpm.d/www.conf

COPY conf/php.ini /etc/php83/conf.d/99-custom.ini
 
WORKDIR /var/www/html
 
COPY tools/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
 
EXPOSE 9000
 
ENTRYPOINT ["/entrypoint.sh"]
