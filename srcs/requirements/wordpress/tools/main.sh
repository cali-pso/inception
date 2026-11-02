#!/bin/ash
set -e

WP_PATH=/var/www/html
DB_PASS="$(cat /run/secrets/db_password)"
WP_ADMIN_PASS="$(cat /run/secrets/wp_admin_password)"
WP_USER_PASS="$(cat /run/secrets/wp_password)"

if [ ! -f "$WP_PATH/wp-load.php" ]; then
    wp core download --path="$WP_PATH" --allow-root
fi

if [ ! -f "$WP_PATH/wp-config.php" ]; then
    wp config create --path="$WP_PATH" --allow-root \
        --dbname="$MYSQL_DATABASE" --dbuser="$MYSQL_USER" \
        --dbpass="$DB_PASS" --dbhost=mariadb
fi

if ! wp core is-installed --path="$WP_PATH" --allow-root; then
    wp core install --path="$WP_PATH" --allow-root \
        --url="https://$DOMAIN_NAME" --title="$WP_TITLE" \
        --admin_user="$WP_ADMIN_USER" \
        --admin_password="$WP_ADMIN_PASS" \
        --admin_email="$WP_ADMIN_EMAIL" --skip-email
    wp user create "$WP_USER" "$WP_USER_EMAIL" \
    --path="$WP_PATH" --allow-root --role=author \
    --user_pass="$WP_USER_PASS"
fi


wp config set WP_REDIS_HOST redis --path="$WP_PATH" --allow-root
wp config set WP_REDIS_PORT 6379 --raw --path="$WP_PATH" --allow-root
wp config set WP_REDIS_GRACEFUL true --raw --path="$WP_PATH" --allow-root

if ! wp plugin is-installed redis-cache --path="$WP_PATH" --allow-root; then
    wp plugin install redis-cache --activate --path="$WP_PATH" --allow-root
fi
wp redis enable --path="$WP_PATH" --allow-root

chown -R www-data:www-data "$WP_PATH"
exec php-fpm83 -F
