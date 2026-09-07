pipeline {
    agent any

    options {
        buildDiscarder(logRotator(numToKeepStr: '3'))
        timeout(time: 25, unit: 'MINUTES')
    }

    environment {
        SONAR_HOST = 'http://13.206.75.229:9000'
        DOCKER_IMAGE = 'commons-lang-build:latest'
        REPO_OWNER = 'apache'
        REPO_NAME = 'commons-lang'
    }

    stages {
        stage('Setup') {
            steps {
                script {
                    if (env.CHANGE_ID) {
                        env.SONAR_PROJECT_KEY = "commons-lang-pr-${env.CHANGE_ID}"
                        env.SONAR_PROJECT_NAME = "Commons Lang PR #${env.CHANGE_ID}"
                        env.SOURCE_BRANCH = env.CHANGE_BRANCH ?: 'feature'
                        env.TARGET_BRANCH = env.CHANGE_TARGET ?: 'master'
                        echo "🔍 PR #${env.CHANGE_ID} from ${env.SOURCE_BRANCH} → ${env.TARGET_BRANCH}"
                    } else {
                        env.SONAR_PROJECT_KEY = 'commons-lang-main'
                        env.SONAR_PROJECT_NAME = 'Commons Lang Main'
                        env.SOURCE_BRANCH = 'master'
                        env.TARGET_BRANCH = 'master'
                        echo "📌 Main branch scan"
                    }
                }
            }
        }

        // For PRs, fetch the target branch so SonarQube can compute the diff
        stage('Fetch Target Branch (PR only)') {
            when {
                expression { env.CHANGE_ID != null }
            }
            steps {
                sh """
                    echo "Fetching target branch ${env.TARGET_BRANCH} for PR comparison..."
                    git fetch origin ${env.TARGET_BRANCH}:${env.TARGET_BRANCH}
                """
            }
        }

        stage('Build Docker Image') {
            steps {
                writeFile file: 'Dockerfile', text: '''FROM ubuntu:20.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    openjdk-11-jdk-headless \
    maven \
    git \
    curl \
    jq \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /workspace
CMD ["mvn", "--version"]
'''
                sh 'docker build -t ${DOCKER_IMAGE} .'
            }
        }

        stage('Build & Test with Coverage') {
            steps {
                sh '''
                    echo "===== Current directory ====="
                    pwd
                    echo "===== Files in workspace ====="
                    ls -la
                    echo "===== Checking for pom.xml ====="
                    if [ -f pom.xml ]; then echo "✅ pom.xml found"; else echo "❌ pom.xml NOT found"; exit 1; fi

                    echo "Running Maven build with coverage inside Docker..."
                    docker run --rm \
                        -v "$PWD":"$PWD" -w "$PWD" \
                        ${DOCKER_IMAGE} \
                        bash -c "mvn clean verify site -Dcommons.jacoco.haltOnFailure=false"
                    echo "Build complete"
                '''
            }
        }

        stage('SonarQube Scan') {
            steps {
                withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
                    sh '''
                        echo "Running SonarQube scan for ${SONAR_PROJECT_KEY}..."
                        
                        SONAR_CMD="mvn sonar:sonar \
                            -Dsonar.host.url=${SONAR_HOST} \
                            -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                            -Dsonar.projectName=${SONAR_PROJECT_NAME} \
                            -Dsonar.login=${SONAR_TOKEN} \
                            -Dsonar.java.binaries=target/classes \
                            -Dsonar.coverage.jacoco.xmlReportPaths=target/site/jacoco/jacoco.xml \
                            -Dsonar.exclusions=**/test/**,**/src/test/**,**/target/**"
                        
                        if [ -n "${CHANGE_ID}" ]; then
                            SONAR_CMD="${SONAR_CMD} \
                                -Dsonar.branch.name=${SOURCE_BRANCH} \
                                -Dsonar.branch.target=${TARGET_BRANCH} \
                                -Dsonar.analysis.leak.period=${TARGET_BRANCH}"
                            echo "🔍 PR scan mode enabled"
                        fi
                        
                        echo "Executing: ${SONAR_CMD}"
                        
                        docker run --rm \
                            -v "$PWD":"$PWD" -w "$PWD" \
                            ${DOCKER_IMAGE} \
                            bash -c "${SONAR_CMD}"
                        
                        echo "✅ Scan complete for ${SONAR_PROJECT_KEY}"
                    '''
                }
            }
        }

        stage('Quality Gate Check') {
            when {
                expression { env.CHANGE_ID != null }
            }
            steps {
                script {
                    echo "⏳ Waiting for SonarQube analysis to complete..."
                    
                    def maxAttempts = 30
                    def waitTime = 10
                    def newCodePassed = true
                    
                    for (int i = 0; i < maxAttempts; i++) {
                        def projectStatusJson = sh(
                            script: """
                                curl -s -u ${SONAR_TOKEN}: "${SONAR_HOST}/api/qualitygates/project_status?projectKey=${SONAR_PROJECT_KEY}"
                            """,
                            returnStdout: true
                        ).trim()
                        
                        def status = sh(
                            script: """
                                echo '${projectStatusJson}' | jq -r '.projectStatus.status'
                            """,
                            returnStdout: true
                        ).trim()
                        
                        if (status && status != "null") {
                            echo "📊 Overall Quality Gate Status: ${status}"
                            
                            def newCodeConditions = sh(
                                script: """
                                    echo '${projectStatusJson}' | jq -r '.projectStatus.conditions[] | select(.period != null) | "\\(.metricKey)=\\(.status)"'
                                """,
                                returnStdout: true
                            ).trim()
                            
                            if (newCodeConditions) {
                                echo "📋 New Code Conditions:"
                                echo "${newCodeConditions}"
                                
                                def failedNewCode = sh(
                                    script: """
                                        echo '${projectStatusJson}' | jq -r '.projectStatus.conditions[] | select(.period != null and .status == "ERROR") | .metricKey'
                                    """,
                                    returnStdout: true
                                ).trim()
                                
                                if (failedNewCode) {
                                    newCodePassed = false
                                    echo "❌ New code failed on: ${failedNewCode}"
                                } else {
                                    newCodePassed = true
                                }
                                break
                            } else {
                                echo "⚠️ No new-code conditions found. Falling back to overall status."
                                if (status == "ERROR") {
                                    newCodePassed = false
                                } else {
                                    newCodePassed = true
                                }
                                break
                            }
                        }
                        
                        echo "⏳ Waiting for analysis... (${i+1}/${maxAttempts})"
                        sleep time: waitTime, unit: 'SECONDS'
                    }
                    
                    if (newCodePassed) {
                        echo "✅ New code quality gate PASSED!"
                        updateGitHubStatus('success', 'SonarQube: New code quality passed!')
                    } else {
                        echo "❌ New code quality gate FAILED!"
                        updateGitHubStatus('failure', 'SonarQube: New code introduced issues.')
                        error "New code quality gate failed. Check the report: ${SONAR_HOST}/dashboard?id=${SONAR_PROJECT_KEY}"
                    }
                }
            }
        }
    }

    post {
        always {
            script {
                if (env.CHANGE_ID && (currentBuild.result == 'SUCCESS' || currentBuild.result == 'ABORTED')) {
                    withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
                        sh """
                            echo "🗑️ Deleting temporary project: ${SONAR_PROJECT_KEY}"
                            curl -X POST "${SONAR_HOST}/api/projects/delete" \
                                -d "project=${SONAR_PROJECT_KEY}" \
                                -u ${SONAR_TOKEN}:
                            echo "✅ Project deleted"
                        """
                    }
                } else if (env.CHANGE_ID && currentBuild.result == 'FAILURE') {
                    echo "⚠️ Build failed. Keeping SonarQube project for debugging: ${SONAR_PROJECT_KEY}"
                }
            }
            cleanWs()
        }
        failure {
            script {
                if (env.CHANGE_ID) {
                    updateGitHubStatus('failure', 'Jenkins build failed. Check logs.')
                }
            }
        }
        aborted {
            script {
                if (env.CHANGE_ID) {
                    updateGitHubStatus('failure', 'Jenkins build aborted.')
                }
            }
        }
    }
}

def updateGitHubStatus(String state, String description) {
    withCredentials([string(credentialsId: 'github-token', variable: 'GITHUB_TOKEN')]) {
        sh """
            curl -X POST "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/statuses/${env.CHANGE_BRANCH}" \
                -H "Authorization: token ${GITHUB_TOKEN}" \
                -H "Accept: application/vnd.github.v3+json" \
                -d '{
                    "state": "${state}",
                    "target_url": "${env.BUILD_URL}",
                    "description": "${description}",
                    "context": "SonarQube/New Code Quality"
                }'
            echo "✅ GitHub status updated to: ${state}"
        """
    }
}
