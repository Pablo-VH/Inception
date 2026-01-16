
FROM alpine:3.22

RUN apk update && apk upgrade && apk add --no-cache  nginx openssl envsubst

RUN rm -f /etc/nginx/http.d/default.conf

COPY ./conf/nginx.conf /etc/nginx/http.d/inception.conf

CMD ["nginx", "-g", "daemon off;"]
