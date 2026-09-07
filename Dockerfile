FROM openjdk:11-jdk-slim

RUN apt-get update && apt-get install -y \
    maven \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

CMD ["mvn", "--version"]
