pipeline {
    agent any

    options {
        buildDiscarder(logRotator(numToKeepStr: '3'))
        timeout(time: 25, unit: 'MINUTES')
    }

    environment {
        SONAR_HOST = 'http://13.206.75.229:9000'
        DOCKER_IMAGE = 'commons-lang-build:latest'
    }

    stages {
        stage('Setup') {
            steps {
                script {
                    if (env.CHANGE_ID) {
                        env.SONAR_PROJECT_KEY = "commons-lang-pr-${env.CHANGE_ID}"
                        echo "🔍 PR #${env.CHANGE_ID}"
                    } else {
                        env.SONAR_PROJECT_KEY = 'commons-lang-main'
                        echo "📌 Main branch"
                    }
                }
            }
        }

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('DEBUG: Check Workspace') {
            steps {
                sh '''
                    echo "========== WORKSPACE PATH =========="
                    pwd
                    echo ""
                    
                    echo "========== FILES IN WORKSPACE =========="
                    ls -la
                    echo ""
                    
                    echo "========== SEARCH FOR POM.XML =========="
                    find . -name "pom.xml" -type f | head -10
                    echo ""
                    
                    echo "========== WORKSPACE SIZE =========="
                    du -sh .
                    echo ""
                    
                    echo "========== GIT INFO =========="
                    git branch -a
                    git log --oneline -5
                '''
            }
        }

        stage('Write Dockerfile') {
            steps {
                writeFile file: 'Dockerfile', text: '''FROM ubuntu:20.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    openjdk-11-jdk-headless \
    maven \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
CMD ["mvn", "--version"]
'''
            }
        }

        stage('Build Docker Image') {
            steps {
                sh 'docker build -t ${DOCKER_IMAGE} .'
            }
        }

        stage('DEBUG: Check Docker Mount') {
            steps {
                sh '''
                    echo "========== FILES INSIDE DOCKER =========="
                    docker run --rm \
                        -v ${WORKSPACE}:${WORKSPACE} \
                        -w ${WORKSPACE} \
                        ${DOCKER_IMAGE} \
                        ls -la
                    echo ""
                    
                    echo "========== SEARCH POM IN DOCKER =========="
                    docker run --rm \
                        -v ${WORKSPACE}:${WORKSPACE} \
                        -w ${WORKSPACE} \
                        ${DOCKER_IMAGE} \
                        find . -name "pom.xml" -type f | head -10
                '''
            }
        }
    }

    post {
        always {
            cleanWs()
        }
    }
}
