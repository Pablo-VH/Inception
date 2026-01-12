
FROM alpine:3.22

RUN apk update && apk upgrade && apk add --no-cache  php-fpm

RUN ln -s $(find /usr/sbin -name "php-fpm*") /usr/bin/php-fpm

CMD ["php-fpm", "-F"]
