#!/bin/bash -e

cd ${ENV_PATH}
echo "current dir"
pwd
echo "generate .env file from .env_server"
cp ${ENV_PATH}/.env_server ${ENV_PATH}/.env

echo "update .env file from the arguments supplied by env vars"
sed -i 's/RDS_HOST/'"$RDS_HOST"'/g' .env
sed -i 's/RDS_DATABASE/'"$RDS_DATABASE"'/g' .env
sed -i 's/RDS_USERNAME/'"$RDS_USERNAME"'/g' .env
sed -i 's/RDS_PASSWORD/'"$RDS_PASSWORD"'/g' .env

if test -n "$ENV_FILESYSTEM_DRIVER"; then
    sed -i 's/ENV_FILESYSTEM_DRIVER/'"$ENV_FILESYSTEM_DRIVER"'/g' .env
    echo "ENV_FILESYSTEM_DRIVER is set to : $ENV_FILESYSTEM_DRIVER"
else
    sed -i 's/ENV_FILESYSTEM_DRIVER/'"public"'/g' .env
fi

sed -i 's/ENV_AWS_SECRET_ACCESS_KEY/'"$ENV_AWS_SECRET_ACCESS_KEY"'/g' .env
sed -i 's/ENV_AWS_ACCESS_KEY_ID/'"$ENV_AWS_ACCESS_KEY_ID"'/g' .env
sed -i 's#ENV_APP_URL#'"$ENV_APP_URL"'#g' .env
sed -i 's#ENV_ASSET_URL#'"$ENV_ASSET_URL"'#g' .env

sed -i 's/ENV_SMS_USERNAME/'"$ENV_SMS_USERNAME"'/g' .env
sed -i 's/ENV_SMS_PASSWORD/'"$ENV_SMS_PASSWORD"'/g' .env
sed -i 's/ENV_SMS_SENDER_ID/'"$ENV_SMS_SENDER_ID"'/g' .env
sed -i 's/ENV_SMS_PURCHASECODE/'"$ENV_SMS_PURCHASECODE"'/g' .env

#sed -i 's/ENV_CDN_URL/'"$ENV_CDN_URL"'/g' .env
#for url we need to change delimeter
sed -i 's#ENV_CDN_URL#'"$ENV_CDN_URL"'#g' .env

sed -i 's/ENV_MAIL_MAILER/'"$ENV_MAIL_MAILER"'/g' .env
sed -i 's/ENV_MAIL_ENCRYPTION/'"$ENV_MAIL_ENCRYPTION"'/g' .env
sed -i 's/ENV_MAIL_FROM_ADDRESS/'"$ENV_MAIL_FROM_ADDRESS"'/g' .env

sed -i 's/ENV_MAILGUN_DOMAIN/'"$ENV_MAILGUN_DOMAIN"'/g' .env
sed -i 's/ENV_MAILGUN_SECRET/'"$ENV_MAILGUN_SECRET"'/g' .env

#this contains / slash.
sed -i 's#ENV_AWS_BUCKET_FOLDER#'"$ENV_AWS_BUCKET_FOLDER"'#g' .env

sed -i 's/ENV_APP_ENV/'"$ENV_APP_ENV"'/g' .env
 
sed -i 's/ENV_APP_DEBUG/'"$ENV_APP_DEBUG"'/g' .env

# assume we have already setup basic database and run basic sql script for first time. 
echo "composer install"
composer install

echo "Running DB Migrate"
php artisan migrate --force

#download lang files from s3 to local resource folder
php artisan download:lang

chmod -R 0777 ${ENV_PATH}/resources/lang

#new logic.....
if [[ ! -z "${PHP_MEMORY_LIMIT}" ]]; then
  sed -i "s,memory_limit = 128M,memory_limit = ${PHP_MEMORY_LIMIT},g" /etc/php/${PHP_VERSION}/fpm/php.ini
  sed -i "s,opcache.memory_consumption = 128M,opcache.memory_consumption = ${PHP_MEMORY_LIMIT},g" /etc/php/${PHP_VERSION}/fpm/php.ini
fi

if [[ ! -z "${PHP_POST_MAX_SIZE}" ]]; then
  sed -i "s,post_max_size = 8M,post_max_size = ${PHP_POST_MAX_SIZE},g" /etc/php/${PHP_VERSION}/fpm/php.ini
fi

if [[ ! -z "${PHP_UPLOAD_MAX_FILESIZE}" ]]; then
  sed -i "s,upload_max_filesize = 2M,upload_max_filesize = ${PHP_UPLOAD_MAX_FILESIZE},g" /etc/php/${PHP_VERSION}/fpm/php.ini
fi

if [[ ! -z "${PHP_MAX_CHILDREN}" ]]; then
  sed -i "s,pm.max_children = 5,pm.max_children = ${PHP_MAX_CHILDREN},g" /etc/php/${PHP_VERSION}/fpm/pool.d/laravel.conf
fi

if [[ ! -z "${PHP_START_SERVERS}" ]]; then
  sed -i "s,pm.start_servers = 2,pm.start_servers = ${PHP_START_SERVERS},g" /etc/php/${PHP_VERSION}/fpm/pool.d/laravel.conf
fi

if [[ ! -z "${PHP_MIN_SPARE_SERVERS}" ]]; then
  sed -i "s,pm.min_spare_servers = 1,pm.min_spare_servers = ${PHP_MIN_SPARE_SERVERS},g" /etc/php/${PHP_VERSION}/fpm/pool.d/laravel.conf
fi

if [[ ! -z "${PHP_MAX_SPARE_SERVERS}" ]]; then
  sed -i "s,pm.max_spare_servers = 3,pm.max_spare_servers = ${PHP_MAX_SPARE_SERVERS},g" /etc/php/${PHP_VERSION}/fpm/pool.d/laravel.conf
fi

if [[ ! -z "${PHP_MAX_REQUESTS}" ]]; then
  sed -i "s,pm.max_requests = 500,pm.max_requests = ${PHP_MAX_REQUESTS},g" /etc/php/${PHP_VERSION}/fpm/pool.d/laravel.conf
fi

if [[ ! -z "${NEW_RELIC_LICENSE_KEY}" ]]; then
  sed -i -e s/\"REPLACE_WITH_REAL_KEY\"/${NEW_RELIC_LICENSE_KEY}/ -e s/newrelic.appname[[:space:]]=[[:space:]].\*/newrelic.appname="${NEW_RELIC_APP_NAME}"/ /etc/php/${PHP_VERSION}/fpm/conf.d/newrelic.ini
  sed -i -e s/\"REPLACE_WITH_REAL_KEY\"/${NEW_RELIC_LICENSE_KEY}/ -e s/newrelic.appname[[:space:]]=[[:space:]].\*/newrelic.appname="${NEW_RELIC_APP_NAME}"/ /etc/php/${PHP_VERSION}/cli/conf.d/newrelic.ini
fi

if [[ ! -z "${NEW_RELIC_ENABLED}" ]]; then
  sed -i "s/;newrelic.enabled = true/newrelic.enabled = ${NEW_RELIC_ENABLED}/" /etc/php/${PHP_VERSION}/fpm/conf.d/newrelic.ini
  sed -i "s/;newrelic.enabled = true/newrelic.enabled = ${NEW_RELIC_ENABLED}/" /etc/php/${PHP_VERSION}/cli/conf.d/newrelic.ini
fi


/usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
