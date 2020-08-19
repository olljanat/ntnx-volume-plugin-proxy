# STAGE 1: Generate self signed certificate and .htaccess file
FROM alpine AS build
RUN apk add openssl && mkdir /certs
RUN openssl req -x509 -newkey rsa:2048 -keyout /certs/localhost.key -out /certs/localhost.crt -days 3650 -nodes -subj '/CN=localhost'
RUN echo -n "29513873:" >> /.htpasswd
RUN echo "docker" | openssl passwd -apr1 -stdin >> /.htpasswd

# STAGE 2: Build final image with output
FROM alpine
EXPOSE 9440
RUN apk add --no-cache bash curl fcgiwrap gettext jq nginx nginx-mod-http-echo \
    && mkdir /run/nginx/ \
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log
COPY docker-entrypoint.sh /
COPY docker-entrypoint.d/* /docker-entrypoint.d/

COPY /scripts/* /scripts/
COPY --from=build /certs/* /etc/nginx/certs/
COPY --from=build /.htpasswd /usr/share/nginx/html/
COPY *.html /usr/share/nginx/html/
COPY default.conf.template /etc/nginx/templates/

ENTRYPOINT ["/docker-entrypoint.sh"]
STOPSIGNAL SIGTERM
CMD ["nginx", "-g", "daemon off;"]
