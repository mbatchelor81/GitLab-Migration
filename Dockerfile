# Stage 1: Build the application
FROM gradle:7.4-jdk11 AS build
WORKDIR /app
COPY build.gradle settings.gradle* ./
COPY gradle ./gradle
COPY gradlew ./
RUN ./gradlew dependencies --no-daemon || true
COPY src ./src
RUN ./gradlew bootJar --no-daemon -x test

# Stage 2: Run the application
FROM eclipse-temurin:11-jre-alpine
WORKDIR /app
COPY --from=build /app/build/libs/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
