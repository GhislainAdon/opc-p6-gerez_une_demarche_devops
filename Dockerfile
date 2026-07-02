# syntax=docker/dockerfile:1
# Multi-stage build producing two targeted images (one process per container):
#   --target front : Angular static bundle served by Caddy (non-root, port 8080)
#   --target back  : Spring Boot API on a JRE 17 (non-root, port 8080)

FROM node:20-alpine AS front-build

COPY ./front /src

WORKDIR /src

RUN npm ci \
    && npx @angular/cli build --optimization

FROM gradle:8.7-jdk17-alpine AS back-build

COPY ./back /src

WORKDIR /src

RUN ./gradlew --no-daemon build

FROM caddy:2-alpine AS front

RUN adduser -D -u 10001 webuser

COPY --from=front-build /src/dist/microcrm/browser /app/front
COPY misc/docker/Caddyfile /etc/caddy/Caddyfile

USER webuser

ENV XDG_DATA_HOME=/tmp/caddy-data \
    XDG_CONFIG_HOME=/tmp/caddy-config

WORKDIR /app

EXPOSE 8080

CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile"]

FROM eclipse-temurin:17-jre-alpine AS back

RUN adduser -D -u 10001 spring

COPY --from=back-build /src/build/libs/microcrm-0.0.1-SNAPSHOT.jar /app/back/microcrm.jar

USER spring

WORKDIR /app

EXPOSE 8080

CMD ["java", "-jar", "/app/back/microcrm.jar"]
