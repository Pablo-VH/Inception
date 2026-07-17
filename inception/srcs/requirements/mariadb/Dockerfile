
FROM alpine:3.23.5
 
# Instalamos MariaDB, el cliente y bash (para el script de entrypoint)
RUN apk update && apk add --no-cache \
    mariadb \
    mariadb-client \
    bash
 
# Copiamos la configuracion personalizada
COPY conf/50-server.cnf /etc/my.cnf.d/mariadb-server.cnf
 
# Copiamos el script que inicializa la base de datos al arrancar
COPY tools/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
 
# Directorio donde MariaDB guarda los datos (aqui montaremos el volumen)
RUN mkdir -p /run/mysqld && chown -R mysql:mysql /run/mysqld
 
EXPOSE 3306
 
ENTRYPOINT ["/entrypoint.sh"]
