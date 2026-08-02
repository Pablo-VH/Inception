FROM alpine:3.23.5
 
RUN apk update && apk add --no-cache \
    nginx \
    openssl \
    bash
 
# Creamos el directorio donde guardaremos el certificado TLS
RUN mkdir -p /etc/nginx/ssl
 
# Generamos un certificado autofirmado en tiempo de build.
# DOMAIN_NAME se pasa como build-arg desde docker-compose.yml
ARG DOMAIN_NAME=pavicent.42.fr
RUN openssl req -x509 -nodes -days 365 \
    -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/inception.key \
    -out /etc/nginx/ssl/inception.crt \
    -subj "/C=ES/ST=Madrid/L=Madrid/O=42/OU=42/CN=${DOMAIN_NAME}"
 
# Copiamos nuestra configuracion, sobreescribiendo la que trae Alpine por defecto
COPY conf/nginx.conf /etc/nginx/nginx.conf
 
# Sustituimos el placeholder por el dominio real, usando el mismo ARG
# que usamos para el certificado, para que ambos queden sincronizados
RUN sed -i "s/pavicent.42.fr/${DOMAIN_NAME}/g" /etc/nginx/nginx.conf
 
# NGINX corre en foreground por defecto con "daemon off", asi que
# no necesitamos entrypoint.sh aqui: llamamos al binario directamente.
 
EXPOSE 443
 
# "-g daemon off" fuerza a nginx a NO hacer fork a segundo plano,
# para que sea el proceso PID 1 real del contenedor (no un hack tipo tail -f)
ENTRYPOINT ["nginx", "-g", "daemon off;"]
 
