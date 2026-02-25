#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="jenkins-demo"
JENKINS_PORT=8080
AGENT_PORT=50000
VOLUME_NAME="jenkins_demo_home"
IMAGE_NAME="jenkins-demo-docker"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

usage() {
    echo "Usage: $0 {start|stop|restart|status|logs|password}"
    exit 1
}

start() {
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo "Jenkins is already running at http://localhost:${JENKINS_PORT}"
        return
    fi

    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo "Starting existing Jenkins container..."
        docker start "${CONTAINER_NAME}"
    else
        echo "Building custom Jenkins image with Docker CLI..."
        docker build -t "${IMAGE_NAME}" -f "${SCRIPT_DIR}/jenkins.Dockerfile" "${SCRIPT_DIR}"

        echo "Creating and starting Jenkins container..."
        docker run -d \
            --name "${CONTAINER_NAME}" \
            -p "${JENKINS_PORT}:8080" \
            -p "${AGENT_PORT}:50000" \
            -v "${VOLUME_NAME}:/var/jenkins_home" \
            -v /var/run/docker.sock:/var/run/docker.sock \
            "${IMAGE_NAME}"
    fi

    echo ""
    echo "Jenkins is starting at http://localhost:${JENKINS_PORT}"
    echo "It may take a minute to initialize on first run."
    echo "Run '$0 password' to get the initial admin password."
}

stop() {
    echo "Stopping Jenkins..."
    docker stop "${CONTAINER_NAME}" 2>/dev/null || echo "Jenkins is not running."
}

restart() {
    stop
    sleep 2
    start
}

status() {
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo "Jenkins is running at http://localhost:${JENKINS_PORT}"
    elif docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo "Jenkins container exists but is stopped. Run '$0 start' to start it."
    else
        echo "Jenkins is not set up. Run '$0 start' to create and start it."
    fi
}

logs() {
    docker logs -f "${CONTAINER_NAME}"
}

password() {
    echo "Waiting for Jenkins to initialize..."
    for i in {1..30}; do
        if docker exec "${CONTAINER_NAME}" cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null; then
            echo ""
            echo "Use this password at http://localhost:${JENKINS_PORT} to complete setup."
            return
        fi
        sleep 2
    done
    echo "Could not retrieve password. Jenkins may still be starting — try again in a moment."
}

case "${1:-}" in
    start)    start ;;
    stop)     stop ;;
    restart)  restart ;;
    status)   status ;;
    logs)     logs ;;
    password) password ;;
    *)        usage ;;
esac
