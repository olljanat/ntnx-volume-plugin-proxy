# STAGE 1: Generate self signed certificate and .htaccess file
FROM alpine AS build
RUN apk add openssl && mkdir /certs
RUN openssl req -x509 -newkey rsa:2048 -keyout /certs/localhost.key -out /certs/localhost.crt -days 3650 -nodes -subj '/CN=localhost'
RUN echo -n "docker:" >> /.htpasswd
RUN echo "docker" | openssl passwd -apr1 -stdin >> /.htpasswd

# STAGE 2: Build final image with output
FROM nginx
EXPOSE 9440
COPY --from=build /certs/* /etc/nginx/certs/
COPY --from=build /.htpasswd /usr/share/nginx/html/
COPY index.html /usr/share/nginx/html/
COPY default.conf.template /etc/nginx/templates/
