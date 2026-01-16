
FROM alpine:3.22

RUN apk update && apk upgrade && apk add --no-cache \
    php-fpm php-mysqli php-json curl

RUN ln -s $(find /usr/sbin -name "php-fpm*") /usr/bin/php-fpm

RUN /etc/php*/php-fpm.d/www.conf

CMD ["php-fpm", "-F"]
