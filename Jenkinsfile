pipeline {
    agent any
    environment {
        AWS_REGION = 'us-east-1'
        ECR_REPOSITORY_URI = '533267266376.dkr.ecr.us-east-1.amazonaws.com/node-api'
        DOCKER_IMAGE = "${ECR_REPOSITORY_URI}:latest"
        CLUSTER_NAME = 'node-api-cluster'
        TASK_FAMILY = 'node-api-task'
        SERVICE_NAME = 'node-api-service'
        SUBNET_ID = 'subnet-0b9ef3f7c5d6314dd'
        SECURITY_GROUP = 'sg-0f80801807bd738a1'
        AWS_CREDENTIALS_ID = 'aws-credentials'
        SONAR_PROJECT_KEY = 'primer-escaneo'
        SONAR_PROJECT_NAME = 'api-node'
        SONAR_PROJECT_VERSION = '1.0'
    }
    stages {
        stage('Acceder al repositorio') {
            steps {
                git 'https://github.com/alberub/api-node'
            }
        }
        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube server') {
                    sh '''                    
                    sonar-scanner \
                    -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                    -Dsonar.projectName=${SONAR_PROJECT_NAME} \
                    -Dsonar.projectVersion=${SONAR_PROJECT_VERSION} \
                    -Dsonar.sources=. \
                    -Dsonar.exclusions=**/node_modules/**
                    '''
                }
            }
        }
        stage('Crea la imagen de Docker') {
            steps {
                script {
                    sh 'docker build -t ${DOCKER_IMAGE} .'
                }
            }
        }
        stage('Login en ECR') {
            steps {
                script {
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: "${AWS_CREDENTIALS_ID}"]]) {
                        sh '''
                        aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REPOSITORY_URI}
                        '''
                    }
                }
            }
        }
        stage('Push de imagen de Docker en ECR') {
            steps {
                script {
                    try {
                        sh 'docker push ${DOCKER_IMAGE}'
                    } catch (Exception e) {
                        echo "Ha ocurrido un error al hacer push de la imagen ECR: ${e.getMessage()}"
                        throw e
                    }
                }
            }
        }
        stage('Crear Task Definition') {
            steps {
                script {
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: "${AWS_CREDENTIALS_ID}"]]) {
                        sh '''
                        aws ecs register-task-definition \
                        --family ${TASK_FAMILY} \
                        --network-mode awsvpc \
                        --requires-compatibilities FARGATE \
                        --cpu 256 --memory 512 \
                        --execution-role-arn arn:aws:iam::533267266376:role/ecsTaskExecutionRole \
                        --container-definitions "[{
                            \\"name\\": \\"node-api-container\\",
                            \\"image\\": \\"${DOCKER_IMAGE}\\",
                            \\"portMappings\\": [{
                                \\"containerPort\\": 3000,
                                \\"hostPort\\": 3000,
                                \\"protocol\\": \\"tcp\\"
                            }]
                        }]"
                        '''
                    }
                }
            }
        }
        stage('Crea o actualiza el ECS Service') {
            steps {
                script {
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: "${AWS_CREDENTIALS_ID}"]]) {
                        sh '''
                        # Verificar si el cluster existe
                        CLUSTER_STATUS=$(aws ecs describe-clusters --clusters ${CLUSTER_NAME} --query 'clusters[0].status' --output text)

                        if [ "$CLUSTER_STATUS" != "ACTIVE" ]; then
                            echo "Dame el puto error"
                            aws ecs create-cluster --cluster-name ${CLUSTER_NAME}
                        fi

                        # Verificar si el servicio existe
                        SERVICE_ARN=$(aws ecs describe-services --cluster ${CLUSTER_NAME} --services ${SERVICE_NAME} --query 'services[*].serviceArn' --output text)

                        if [ -z "$SERVICE_ARN" ]; then
                            echo "Service does not exist, creating a new one..."
                            aws ecs create-service \
                            --cluster ${CLUSTER_NAME} \
                            --service-name ${SERVICE_NAME} \
                            --task-definition ${TASK_FAMILY} \
                            --desired-count 1 \
                            --launch-type FARGATE \
                            --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_ID}],securityGroups=[${SECURITY_GROUP}],assignPublicIp=ENABLED}"
                        else
                            echo "Service exists, updating service..."
                            aws ecs update-service \
                            --cluster ${CLUSTER_NAME} \
                            --service ${SERVICE_NAME} \
                            --task-definition ${TASK_FAMILY} \
                            --force-new-deployment
                        fi
                        '''
                    }
                }
            }
        }
    }
    post {
        always {
            script {
                sh 'docker system prune -f'
            }
        }
    }
}
