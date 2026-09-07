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
                    echo "========== WORKSPACE BEFORE COPY =========="
                    pwd
                    ls -la | head -20
                    echo ""
                    
                    echo "========== CREATE TEMP DIR =========="
                    TEMP_DIR=$(mktemp -d)
                    echo "Temp dir: $TEMP_DIR"
                    ls -la $TEMP_DIR
                    echo ""
                    
                    echo "========== COPY FILES TO TEMP =========="
                    cp -rv . $TEMP_DIR/ 2>&1 | head -20
                    echo ""
                    
                    echo "========== TEMP DIR AFTER COPY =========="
                    ls -la $TEMP_DIR | head -20
                    echo ""
                    
                    echo "========== CHECK FOR POM IN TEMP =========="
                    find $TEMP_DIR -name "pom.xml" -type f
                    echo ""
                    
                    echo "========== RUN DOCKER =========="
                    docker run --rm \
                        -v $TEMP_DIR:$TEMP_DIR \
                        -w $TEMP_DIR \
                        ${DOCKER_IMAGE} \
                        ls -la
                    echo ""
                    
                    echo "========== RUN MAVEN =========="
                    docker run --rm \
                        -v $TEMP_DIR:$TEMP_DIR \
                        -w $TEMP_DIR \
                        ${DOCKER_IMAGE} \
                        mvn clean verify -DskipITs
                    
                    echo "========== CLEANUP =========="
                    rm -rf $TEMP_DIR
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
