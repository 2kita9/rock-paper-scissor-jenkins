pipeline {
    agent any

    tools {
        maven 'Maven-3'
    }

    environment {
        DOCKER_IMAGE = 'sivapuram29/devops-pipeline-gates-docker-project'
        IMAGE_TAG = "${BUILD_NUMBER}"
        SONAR_PROJECT_KEY = 'rock-paper-scissor'
    }

    stages {

        stage('Checkout') {
            steps {
                echo 'Cloning source code from GitHub...'

                git branch: 'master',
                    url: 'https://github.com/2kita9/rock-paper-scissor-jenkins.git'
            }
        }

        stage('Maven Build') {
            steps {
                echo 'Building Maven project...'

                sh 'mvn clean package'
            }
        }

        stage('Unit Tests') {
            steps {
                echo 'Running unit tests...'

                sh 'mvn test'
            }

            post {
                always {
                    junit 'target/surefire-reports/*.xml'
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                echo 'Running SonarQube analysis...'

                withSonarQubeEnv('Sonarqube') {
                    sh '''
                        echo "=== Maven version ==="
                        mvn --version

                        echo "=== SonarQube environment ==="
                        env | grep SONAR || true

                        echo "=== Running SonarQube scanner ==="
                        mvn org.sonarsource.scanner.maven:sonar-maven-plugin:sonar \
                            -Dsonar.projectKey=${SONAR_PROJECT_KEY}
                    '''
                }
            }
        }

        stage('Quality Gate') {
            steps {
                echo 'Waiting for SonarQube Quality Gate...'

                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Trivy Filesystem Scan') {
            steps {
                echo 'Scanning source code with Trivy...'

                sh '''
                    trivy fs \
                    --severity HIGH,CRITICAL \
                    --exit-code 1 \
                    .
                '''
            }
        }

        stage('Docker Build') {
            steps {
                echo "Building Docker image: ${DOCKER_IMAGE}:${IMAGE_TAG}"

                sh '''
                    docker build \
                    -t ${DOCKER_IMAGE}:${IMAGE_TAG} \
                    -t ${DOCKER_IMAGE}:latest \
                    .
                '''
            }
        }

        stage('Trivy Docker Image Scan') {
            steps {
                echo 'Scanning Docker image with Trivy...'

                sh '''
                    trivy image \
                    --severity HIGH,CRITICAL \
                    --exit-code 1 \
                    ${DOCKER_IMAGE}:${IMAGE_TAG}
                '''
            }
        }

        stage('Push to Docker Hub') {
            steps {
                echo 'Pushing image to Docker Hub...'

                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub-credentials',
                        usernameVariable: 'DOCKER_USERNAME',
                        passwordVariable: 'DOCKER_PASSWORD'
                    )
                ]) {

                    sh '''
                        echo "$DOCKER_PASSWORD" | docker login \
                            -u "$DOCKER_USERNAME" \
                            --password-stdin

                        docker push ${DOCKER_IMAGE}:${IMAGE_TAG}

                        docker push ${DOCKER_IMAGE}:latest

                        docker logout
                    '''
                }
            }
        }

        stage('AWS Connection Test') {
            steps {
                echo 'Testing AWS connection...'

                withCredentials([
                    [$class: 'AmazonWebServicesCredentialsBinding',
                     credentialsId: 'aws-jenkins-ecs']
                ]) {
                    sh '''
                        aws sts get-caller-identity
                    '''
                }
            }
        }

        stage('Deploy to ECS') {
            steps {
                echo "Deploying ${DOCKER_IMAGE}:${IMAGE_TAG} to ECS..."
        
                withCredentials([
                    [$class: 'AmazonWebServicesCredentialsBinding',
                     credentialsId: 'aws-jenkins-ecs']
                ]) {
        
                    sh '''
        set -e
        
        echo "======================================"
        echo "Getting current ECS task definition"
        echo "======================================"
        
        aws ecs describe-task-definition \
            --task-definition rock-paper-scissor-task \
            --region ap-south-1 \
            --query taskDefinition \
            > task-definition.json
        
        echo "Current task definition downloaded."
        
        echo "======================================"
        echo "Creating new task definition"
        echo "======================================"
        
        export NEW_IMAGE="${DOCKER_IMAGE}:${IMAGE_TAG}"
        
        python3 -c 'import json, os; f=open("task-definition.json"); task=json.load(f); f.close(); task["containerDefinitions"][0]["image"]=os.environ["NEW_IMAGE"]; [task.pop(k, None) for k in ["taskDefinitionArn","revision","status","requiresAttributes","compatibilities","registeredAt","registeredBy","deregisteredAt"]]; f=open("new-task-definition.json","w"); json.dump(task,f); f.close()'
        
        echo "New task definition created."
        
        echo "======================================"
        echo "Registering new ECS task definition"
        echo "======================================"
        
        NEW_TASK_DEFINITION=$(aws ecs register-task-definition \
            --cli-input-json file://new-task-definition.json \
            --region ap-south-1 \
            --query 'taskDefinition.taskDefinitionArn' \
            --output text)
        
        echo "New task definition:"
        echo "$NEW_TASK_DEFINITION"
        
        echo "======================================"
        echo "Updating ECS service"
        echo "======================================"
        
        aws ecs update-service \
            --cluster rock-paper-scissor-cluster \
            --service rock-paper-scissor-service \
            --task-definition "$NEW_TASK_DEFINITION" \
            --region ap-south-1
        
        echo "ECS service update submitted."
        
        echo "======================================"
        echo "Waiting for ECS service to become stable"
        echo "======================================"
        
        aws ecs wait services-stable \
            --cluster rock-paper-scissor-cluster \
            --services rock-paper-scissor-service \
            --region ap-south-1
        
        echo "======================================"
        echo "ECS DEPLOYMENT COMPLETED SUCCESSFULLY"
        echo "======================================"
        
        echo "Deployed image: ${DOCKER_IMAGE}:${IMAGE_TAG}"
        echo "Task definition: ${NEW_TASK_DEFINITION}"
                    '''
                }
            }
        }

    }

    post {

        success {
            echo '======================================'
            echo 'PIPELINE COMPLETED SUCCESSFULLY'
            echo '======================================'

            echo "Docker image: ${DOCKER_IMAGE}:${IMAGE_TAG}"
            echo "ECS cluster: rock-paper-scissor-cluster"
            echo "ECS service: rock-paper-scissor-service"
        }

        failure {
            echo '======================================'
            echo 'PIPELINE FAILED'
            echo '======================================'

            echo 'Check the failed stage above.'
        }

        always {
            echo 'Cleaning workspace...'

            cleanWs()
        }
    }
}
