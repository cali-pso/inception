# Single source of truth: LOGIN comes from srcs/.env (also read by compose).
LOGIN    = $(shell sed -n 's/^LOGIN=//p' srcs/.env)
OLLAMA_MODEL    = $(shell sed -n 's/^OLLAMA_MODEL=//p' srcs/.env)

COMPOSE  = docker compose -f srcs/docker-compose.yml
DATA_DIR = /home/$(LOGIN)/data
SECRETS  = secrets/db_password.txt secrets/db_root_password.txt \
           secrets/wp_password.txt secrets/wp_admin_password.txt \
		   secrets/ftp_password.txt

all: secrets
	mkdir -p $(DATA_DIR)/mariadb $(DATA_DIR)/wordpress $(DATA_DIR)/site $(DATA_DIR)/ollama
	$(COMPOSE) up -d --build

# Generate any missing secret file with a random password (never overwrites).
secrets:
	@mkdir -p secrets
	@for f in $(SECRETS); do \
		[ -s $$f ] || { openssl rand -base64 18 > $$f; echo "created $$f"; }; \
	done

down:
	$(COMPOSE) down

pull-model:
	$(COMPOSE) exec ollama ollama pull $(OLLAMA_MODEL)

clean:
	$(COMPOSE) down -v --rmi all

fclean: clean
	sudo rm -rf $(DATA_DIR)

re: fclean all

.PHONY: all secrets down clean fclean re pull-model
