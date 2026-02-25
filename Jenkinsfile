pipeline {
    agent any

    environment {
        REGISTRY        = 'registry.gitlab.com'
        REGISTRY_GROUP  = 'mason-cognition/spring-boot-realworld-example-app'
        BACKEND_IMAGE   = "${REGISTRY}/${REGISTRY_GROUP}/backend"
        FRONTEND_IMAGE  = "${REGISTRY}/${REGISTRY_GROUP}/frontend"
        IMAGE_TAG       = "${env.GIT_COMMIT?.take(8) ?: 'latest'}"
        GITLAB_CREDS    = credentials('gitlab-registry-credentials')
        K8S_NAMESPACE   = 'realworld'
    }

    tools {
        jdk 'JDK-11'
        gradle 'Gradle-7.4'
        nodejs 'Node-16'
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timestamps()
        timeout(time: 30, unit: 'MINUTES')
        disableConcurrentBuilds()
    }

    stages {

        // ──────────────────────────────────────────────
        // BUILD & TEST — Backend
        // ──────────────────────────────────────────────

        stage('Backend: Build') {
            steps {
                sh './gradlew assemble --no-daemon'
            }
        }

        stage('Backend: Lint') {
            steps {
                sh './gradlew spotlessCheck --no-daemon'
            }
        }

        stage('Backend: Unit & Integration Tests') {
            steps {
                sh './gradlew test --no-daemon'
            }
            post {
                always {
                    junit '**/build/test-results/test/*.xml'
                }
            }
        }

        stage('Backend: Code Coverage') {
            steps {
                sh './gradlew jacocoTestReport --no-daemon'
            }
            post {
                always {
                    publishHTML(target: [
                        reportDir:   'build/reports/jacoco/test/html',
                        reportFiles: 'index.html',
                        reportName:  'JaCoCo Coverage Report'
                    ])
                }
            }
        }

        // ──────────────────────────────────────────────
        // BUILD & TEST — Frontend
        // ──────────────────────────────────────────────

        stage('Frontend: Install') {
            steps {
                dir('frontend') {
                    sh 'npm ci'
                }
            }
        }

        stage('Frontend: Build') {
            steps {
                dir('frontend') {
                    sh 'npm run build'
                }
            }
        }

        // ──────────────────────────────────────────────
        // DOCKER — Build & Push Images
        // ──────────────────────────────────────────────

        stage('Docker: Build Images') {
            parallel {
                stage('Build Backend Image') {
                    steps {
                        sh "docker build -t ${BACKEND_IMAGE}:${IMAGE_TAG} -t ${BACKEND_IMAGE}:latest ."
                    }
                }
                stage('Build Frontend Image') {
                    steps {
                        sh "docker build -t ${FRONTEND_IMAGE}:${IMAGE_TAG} -t ${FRONTEND_IMAGE}:latest ./frontend"
                    }
                }
            }
        }

        stage('Docker: Push Images') {
            when {
                branch 'master'
            }
            steps {
                sh "echo ${GITLAB_CREDS_PSW} | docker login ${REGISTRY} -u ${GITLAB_CREDS_USR} --password-stdin"
                sh "docker push ${BACKEND_IMAGE}:${IMAGE_TAG}"
                sh "docker push ${BACKEND_IMAGE}:latest"
                sh "docker push ${FRONTEND_IMAGE}:${IMAGE_TAG}"
                sh "docker push ${FRONTEND_IMAGE}:latest"
            }
            post {
                always {
                    sh "docker logout ${REGISTRY}"
                }
            }
        }

        // ──────────────────────────────────────────────
        // DEPLOY — Staging (Kubernetes)
        // ──────────────────────────────────────────────

        stage('Deploy to Staging') {
            when {
                branch 'master'
            }
            steps {
                withCredentials([file(credentialsId: 'kubeconfig-staging', variable: 'KUBECONFIG')]) {
                    sh """
                        # Update image tags in manifests
                        sed -i 's|image: .*backend:.*|image: ${BACKEND_IMAGE}:${IMAGE_TAG}|' k8s/backend-deployment.yaml
                        sed -i 's|image: .*frontend:.*|image: ${FRONTEND_IMAGE}:${IMAGE_TAG}|' k8s/frontend-deployment.yaml

                        kubectl apply -f k8s/backend-deployment.yaml  -n ${K8S_NAMESPACE}-staging
                        kubectl apply -f k8s/frontend-deployment.yaml -n ${K8S_NAMESPACE}-staging
                        kubectl apply -f k8s/ingress.yaml             -n ${K8S_NAMESPACE}-staging

                        # Wait for rollout to complete
                        kubectl rollout status deployment/realworld-backend  -n ${K8S_NAMESPACE}-staging --timeout=120s
                        kubectl rollout status deployment/realworld-frontend -n ${K8S_NAMESPACE}-staging --timeout=120s
                    """
                }
            }
        }

        // ──────────────────────────────────────────────
        // E2E TESTS — Run against Staging
        // ──────────────────────────────────────────────

        stage('E2E Tests (Selenium)') {
            when {
                branch 'master'
            }
            steps {
                sh './gradlew seleniumTest --no-daemon'
            }
            post {
                always {
                    publishHTML(target: [
                        reportDir:   'build/reports/tests/seleniumTest',
                        reportFiles: 'index.html',
                        reportName:  'Selenium E2E Report'
                    ])
                }
            }
        }

        // ──────────────────────────────────────────────
        // DEPLOY — Production (Kubernetes, manual gate)
        // ──────────────────────────────────────────────

        stage('Approval: Deploy to Production') {
            when {
                branch 'master'
            }
            steps {
                input message: 'Deploy to production?', ok: 'Deploy',
                      submitter: 'admin,release-managers'
            }
        }

        stage('Deploy to Production') {
            when {
                branch 'master'
            }
            steps {
                withCredentials([file(credentialsId: 'kubeconfig-production', variable: 'KUBECONFIG')]) {
                    sh """
                        sed -i 's|image: .*backend:.*|image: ${BACKEND_IMAGE}:${IMAGE_TAG}|' k8s/backend-deployment.yaml
                        sed -i 's|image: .*frontend:.*|image: ${FRONTEND_IMAGE}:${IMAGE_TAG}|' k8s/frontend-deployment.yaml

                        kubectl apply -f k8s/backend-deployment.yaml  -n ${K8S_NAMESPACE}
                        kubectl apply -f k8s/frontend-deployment.yaml -n ${K8S_NAMESPACE}
                        kubectl apply -f k8s/ingress.yaml             -n ${K8S_NAMESPACE}

                        kubectl rollout status deployment/realworld-backend  -n ${K8S_NAMESPACE} --timeout=120s
                        kubectl rollout status deployment/realworld-frontend -n ${K8S_NAMESPACE} --timeout=120s
                    """
                }
            }
        }
    }

    // ──────────────────────────────────────────────
    // POST — Cleanup & Notifications
    // ──────────────────────────────────────────────

    post {
        always {
            cleanWs()
        }
        success {
            echo "Pipeline completed successfully for ${env.BRANCH_NAME} @ ${IMAGE_TAG}"
        }
        failure {
            echo "Pipeline FAILED for ${env.BRANCH_NAME} @ ${IMAGE_TAG}"
            // Uncomment to enable Slack notifications:
            // slackSend channel: '#deployments',
            //           color: 'danger',
            //           message: "FAILED: ${env.JOB_NAME} #${env.BUILD_NUMBER} (<${env.BUILD_URL}|Open>)"
        }
    }
}
