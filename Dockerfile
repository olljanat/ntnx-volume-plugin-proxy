FROM alpine AS build
RUN apk add openssl && mkdir /certs
RUN openssl req -x509 -newkey rsa:2048 -keyout /localhost.key -out /localhost.crt -days 3650 -nodes -subj '/CN=localhost'

FROM nginx
EXPOSE 9440
COPY --from=build /certs/* /etc/nginx/certs/
COPY index.html /usr/share/nginx/html/
COPY default.conf.template /etc/nginx/templates/
