LOGIN ?= rapoggi
all:
	mkdir -p /home/$(LOGIN)/data/mariadb /home/$(LOGIN)/data/wordpress
	docker compose -f srcs/docker-compose.yml up -d --build

down:
	docker compose -f srcs/docker-compose.yml down

clean: down
	docker compose -f srcs/docker-compose.yml down -v

fclean: clean
	sudo rm -rf /home/$(LOGIN)/data

re: fclean all