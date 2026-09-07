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

        stage('Build & Test') {
            steps {
                sh '''
                    WORKSPACE_PATH=$(pwd)
                    echo "Workspace: $WORKSPACE_PATH"
                    echo "Running Maven build in Docker..."
                    
                    docker run --rm \
                        -v $WORKSPACE_PATH:$WORKSPACE_PATH \
                        -w $WORKSPACE_PATH \
                        ${DOCKER_IMAGE} \
                        mvn clean verify -DskipITs
                '''
            }
        }

        stage('SonarQube Scan') {
            steps {
                withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
                    sh '''
                        WORKSPACE_PATH=$(pwd)
                        echo "Workspace: $WORKSPACE_PATH"
                        echo "Running SonarQube scan in Docker..."
                        
                        docker run --rm \
                            -v $WORKSPACE_PATH:$WORKSPACE_PATH \
                            -w $WORKSPACE_PATH \
                            ${DOCKER_IMAGE} \
                            mvn sonar:sonar \
                                -Dsonar.host.url=${SONAR_HOST} \
                                -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                                -Dsonar.projectName=commons-lang \
                                -Dsonar.login=${SONAR_TOKEN}
                    '''
                }
            }
        }
    }

    post {
        always {
            cleanWs()
        }
    }
}
