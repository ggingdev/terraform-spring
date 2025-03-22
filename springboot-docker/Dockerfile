# Build
FROM eclipse-temurin:17-alpine AS build
RUN apk add --no-cache bash

WORKDIR /app

COPY gradlew .
COPY gradle gradle
COPY build.gradle.kts settings.gradle.kts ./

RUN ./gradlew dependencies --no-daemon

COPY . .

RUN chmod +x ./gradlew

RUN ./gradlew build --no-daemon -x test


# Runtime
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app

RUN addgroup -g 1000 worker && \
    adduser -u 1000 -G worker -s /bin/sh -D worker

COPY --from=build --chown=worker:worker /app/build/libs/*.jar ./main.jar

ARG PROFILE=dev
ENV PROFILE=${PROFILE}

USER worker:worker

EXPOSE 8080

ENTRYPOINT ["java", "-Dspring.profiles.active=${PROFILE}", "-jar", "main.jar"]
