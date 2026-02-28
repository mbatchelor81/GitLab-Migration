FROM jenkins/jenkins:lts
USER root
RUN apt-get update && \
    apt-get install -y docker.io wget curl unzip chromium chromium-driver && \
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/arm64/kubectl" && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && \
    rm kubectl && \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o /tmp/awscliv2.zip && \
    cd /tmp && unzip awscliv2.zip && ./aws/install && rm -rf /tmp/aws /tmp/awscliv2.zip && cd / && \
    usermod -aG docker jenkins && \
    wget -q https://github.com/adoptium/temurin11-binaries/releases/download/jdk-11.0.25%2B9/OpenJDK11U-jdk_aarch64_linux_hotspot_11.0.25_9.tar.gz -O /tmp/jdk11.tar.gz && \
    mkdir -p /opt/java/jdk-11 && \
    tar -xzf /tmp/jdk11.tar.gz -C /opt/java/jdk-11 --strip-components=1 && \
    rm /tmp/jdk11.tar.gz && \
    rm -rf /var/lib/apt/lists/* && \
    echo '#!/bin/bash\nchmod 666 /var/run/docker.sock 2>/dev/null || true\nexec /usr/bin/tini -- /usr/local/bin/jenkins.sh "$@"' > /usr/local/bin/docker-entrypoint.sh && \
    chmod +x /usr/local/bin/docker-entrypoint.sh
ENV CHROME_BIN=/usr/bin/chromium
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
USER jenkins
