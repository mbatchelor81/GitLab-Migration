FROM jenkins/jenkins:lts
USER root
RUN apt-get update && \
    apt-get install -y docker.io wget && \
    usermod -aG docker jenkins && \
    wget -q https://github.com/adoptium/temurin11-binaries/releases/download/jdk-11.0.25%2B9/OpenJDK11U-jdk_aarch64_linux_hotspot_11.0.25_9.tar.gz -O /tmp/jdk11.tar.gz && \
    mkdir -p /opt/java/jdk-11 && \
    tar -xzf /tmp/jdk11.tar.gz -C /opt/java/jdk-11 --strip-components=1 && \
    rm /tmp/jdk11.tar.gz && \
    rm -rf /var/lib/apt/lists/*
USER jenkins
