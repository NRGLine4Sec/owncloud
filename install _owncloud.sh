apt-get update && apt-get upgrade -y
apt-get install -y nginx php5 php5-fpm php5-curl php5-mysql php5-gd php5-cli php5-dev memcached php5-memcache varnish php5-common php5-cgi php5-xmlrpc php5-gd php5-json php5-intl php5-mcrypt php5-imagick php5-ldap mariadb-server mariadb-client php-xml-parser
#apt-get install -y nginx mariadb-server mariadb-client
#echo "deb http://dl.hhvm.com/debian jessie main" > /etc/apt/sources.list.d/hhvm.list
#wget -O- http://dl.hhvm.com/conf/hhvm.gpg.key | apt-key add -
#apt-get update
#apt install -y hhvm
#/usr/share/hhvm/install_fastcgi.sh
#/usr/bin/update-alternatives --install /usr/bin/php php /usr/bin/hhvm 60
#update-rc.d hhvm defaults

owncloud_version="10.0.0"

cd /var/www/html
wget --no-check-certificate https://download.owncloud.org/community/owncloud-$owncloud_version.tar.bz2
tar xjvf owncloud-$owncloud_version.tar.bz2
chown -R www-data:www-data /var/www/html/owncloud/


echo 'upstream php-handler {
  server 127.0.0.1:9000;
  #server unix:/var/run/php5-fpm.sock;
  }

server {
  listen 80;
  server_name owncloud;
  # Force le passage en https
  return 301 https://$server_name$request_uri;
  }

server {
  #listen 443 ssl;
  #server_name owncloud.example.com;

  #ssl_certificate /etc/ssl/nginx/owncloud.example.com.crt;
  #ssl_certificate_key /etc/ssl/nginx/owncloud.example.com.key;

  # Fichier de log
  access_log /var/log/nginx/ssl.owncloud.example.com.access.log;
  error_log /var/log/nginx/ssl.owncloud.example.com.error.log;

  # Ajout de header liés à la sécurité
  add_header Strict-Transport-Security "max-age=15768000; includeSubDomains; preload;";
  add_header X-Content-Type-Options nosniff;
  add_header X-Frame-Options "SAMEORIGIN";
  add_header X-XSS-Protection "1; mode=block";
  add_header X-Robots-Tag none;

  # Répertoire dans lequel est installé Owncloud
  root /var/www/owncloud/;
  # Taille de fichier maximum  que l'on peut téléverser/uploader
  client_max_body_size 1G;
  fastcgi_buffers 64 4K;

  # Désactivation de la compression pour éviter la suppression du header ETag
  gzip off;

  # Décommenter cette option si votre serveur est compilé avec le module ngx_pagespeed
  # Ce module est non supporté
  #pagespeed off;

  rewrite ^/caldav(.*)$ /remote.php/caldav$1 redirect;
  rewrite ^/carddav(.*)$ /remote.php/carddav$1 redirect;
  rewrite ^/webdav(.*)$ /remote.php/webdav$1 redirect;

  index index.php;
  error_page 403 /core/templates/403.php;
  error_page 404 /core/templates/404.php;

  location = /robots.txt {
    allow all;
    log_not_found off;
    access_log off;
    }

  location ~ ^/(?:\.htaccess|data|config|db_structure\.xml|README){
    deny all;
    }

  location / {
   # Les régles suivantes sont uniquement nécessaire en cas d'utilisation de webfinger
   rewrite ^/.well-known/host-meta /public.php?service=host-meta last;
   rewrite ^/.well-known/host-meta.json /public.php?service=host-meta-json last;

   rewrite ^/.well-known/carddav /remote.php/carddav/ redirect;
   rewrite ^/.well-known/caldav /remote.php/caldav/ redirect;

   rewrite ^(/core/doc/[^\/]+/)$ $1/index.html;

   try_files $uri $uri/ /index.php;
   }

   location ~ \.php(?:$|/) {
   fastcgi_split_path_info ^(.+\.php)(/.+)$;
   include fastcgi_params;
   fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
   fastcgi_param PATH_INFO $fastcgi_path_info;
   fastcgi_param HTTPS on;
   fastcgi_param modHeadersAvailable true; #Evite d'envoyer les header de sécurtié deux fois
   fastcgi_pass php-handler;
   }

   # Optionnel : positionne un header EXPIRES long sur les ressources statiques
   location ~* \.(?:jpg|jpeg|gif|bmp|ico|png|css|js|swf)$ {
       expires 30d;
       # Optionnel : ne pas logger l'accès aux ressources statiques
         access_log off;
   }
  }' >> /etc/nginx/sites-available/owncloud

ln -s /etc/nginx/sites-available/owncloud /etc/nginx/sites-enabled/owncloud

read -p "Enter your MySQL root password: " rootpass
read -p "Database name: " dbname
read -p "Database username: " dbuser
read -p "Enter a password for user $dbuser: " userpass
echo "CREATE DATABASE $dbname;" | mysql -u root -p$rootpass
echo "CREATE USER '$dbuser'@'localhost' IDENTIFIED BY '$userpass';" | mysql -u root -p$rootpass
echo "GRANT ALL PRIVILEGES ON $dbname.* TO '$dbuser'@'localhost';" | mysql -u root -p$rootpass
echo "FLUSH PRIVILEGES;" | mysql -u root -p$rootpass
echo "New MySQL database is successfully created"

# Test de la configuration 
nginx -t
service php-fpm restart
service nginx restart
#service php-fpm restart
