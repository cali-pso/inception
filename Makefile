# Single source of truth: LOGIN comes from srcs/.env (also read by compose).
LOGIN    = $(shell sed -n 's/^LOGIN=//p' srcs/.env)
OLLAMA_MODEL    = $(shell sed -n 's/^OLLAMA_MODEL=//p' srcs/.env)
DOMAIN   = $(LOGIN).42.fr

COMPOSE  = docker compose -f srcs/docker-compose.yml
DATA_DIR = /home/$(LOGIN)/data
SECRETS  = secrets/db_password.txt secrets/db_root_password.txt \
           secrets/wp_password.txt secrets/wp_admin_password.txt \
		   secrets/ftp_password.txt

all: secrets hosts
	mkdir -p $(DATA_DIR)/mariadb $(DATA_DIR)/wordpress $(DATA_DIR)/site $(DATA_DIR)/ollama
	$(COMPOSE) up -d --build

# Generate any missing secret file with a random password (never overwrites).
secrets:
	@mkdir -p secrets
	@for f in $(SECRETS); do \
		[ -s $$f ] || { openssl rand -base64 18 > $$f; echo "created $$f"; }; \
	done

# Point the domain at this machine. Idempotent: never appends twice.
hosts:
	@grep -q "[[:space:]]$(DOMAIN)$$" /etc/hosts || { \
		echo "adding $(DOMAIN) to /etc/hosts (needs sudo)"; \
		echo "127.0.0.1 $(DOMAIN)" | sudo tee -a /etc/hosts > /dev/null; \
	}

down:
	$(COMPOSE) down

pull-model:
	$(COMPOSE) exec ollama ollama pull $(OLLAMA_MODEL)

clean:
	$(COMPOSE) down -v --rmi all

fclean: clean
	sudo rm -rf $(DATA_DIR)

re: fclean all

.PHONY: all secrets hosts down clean fclean re pull-model
