NAME = inception
 
COMPOSE_FILE = srcs/docker-compose.yml
DATA_DIR = $(HOME)/data
 
all: data build up
 
# Creamos las carpetas donde se guardaran los volumenes ANTES de
# arrancar, si no docker compose falla al intentar montarlas.
data:
	@mkdir -p $(DATA_DIR)/mariadb
	@mkdir -p $(DATA_DIR)/wordpress
	@echo "==> Carpetas de datos listas en $(DATA_DIR)"
 
build:
	@docker compose -f $(COMPOSE_FILE) build
 
up:
	@docker compose -f $(COMPOSE_FILE) up -d
 
down:
	@docker compose -f $(COMPOSE_FILE) down
 
stop:
	@docker compose -f $(COMPOSE_FILE) stop
 
start:
	@docker compose -f $(COMPOSE_FILE) start
 
logs:
	@docker compose -f $(COMPOSE_FILE) logs -f
 
status:
	@docker compose -f $(COMPOSE_FILE) ps
 
# Baja los contenedores y borra imagenes/redes creadas por el proyecto,
# pero NO toca los datos persistidos en el host.
clean: down
	@docker compose -f $(COMPOSE_FILE) down --rmi all --volumes
	@echo "==> Contenedores, imagenes y volumenes de docker eliminados"
 
# Limpieza total: ademas de "clean", borra tambien los datos reales
# del host (la BD y los ficheros de WordPress). Uso con cuidado.
fclean: clean
	@sudo rm -rf $(DATA_DIR)
	@echo "==> Datos persistentes en $(DATA_DIR) eliminados"
 
re: fclean all
 
.PHONY: all data build up down stop start logs status clean fclean re