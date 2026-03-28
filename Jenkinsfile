pipeline {
    agent any

    environment {
        AWS_REGION = 'ap-northeast-2'
        EKS_CLUSTER_NAME = 'frodo'
        K8S_DEPLOYMENT_NAME = 'myapp'
        K8S_CONTAINER_NAME = 'myapp'
        DOCKER_REPO = 'app'
    }

    triggers {
        githubPush()
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Get Commit Message Tag') {
            steps {
                script {
                    def rawMsg = sh(
                        script: "git log -1 --pretty=%B | tr -dc '[:alnum:]' | cut -c1-50",
                        returnStdout: true
                    ).trim()

                    if (!rawMsg) {
                        rawMsg = "build${env.BUILD_NUMBER}"
                    }

                    env.COMMIT_TAG = rawMsg
                    echo "COMMIT_TAG=${env.COMMIT_TAG}"
                }
            }
        }

        stage('Docker Login') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-creds',
                    usernameVariable: 'DOCKER_USERNAME',
                    passwordVariable: 'DOCKER_PASSWORD'
                )]) {
                    sh '''
                        echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin
                    '''
                }
            }
        }

        stage('Build and Push Docker Image') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-creds',
                    usernameVariable: 'DOCKER_USERNAME',
                    passwordVariable: 'DOCKER_PASSWORD'
                )]) {
                    sh '''
                        docker build -t $DOCKER_USERNAME/$DOCKER_REPO:$COMMIT_TAG .
                        docker tag $DOCKER_USERNAME/$DOCKER_REPO:$COMMIT_TAG $DOCKER_USERNAME/$DOCKER_REPO:latest

                        docker push $DOCKER_USERNAME/$DOCKER_REPO:$COMMIT_TAG
                        docker push $DOCKER_USERNAME/$DOCKER_REPO:latest
                    '''
                }
            }
        }

        stage('Deploy to EKS') {
            steps {
                withCredentials([
                    string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                    string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY'),
                    withCredentials([usernamePassword(
                        credentialsId: 'dockerhub-creds',
                        usernameVariable: 'DOCKER_USERNAME',
                        passwordVariable: 'DOCKER_PASSWORD'
                    )])
                ]) {
                    sh '''
                        aws eks update-kubeconfig --name $EKS_CLUSTER_NAME --region $AWS_REGION

                        kubectl set image deployment/$K8S_DEPLOYMENT_NAME \
                          $K8S_CONTAINER_NAME=$DOCKER_USERNAME/$DOCKER_REPO:$COMMIT_TAG

                        kubectl rollout status deployment/$K8S_DEPLOYMENT_NAME
                    '''
                }
            }
        }
    }

    post {
        always {
            sh 'docker logout || true'
        }
        success {
            echo 'Build and deployment completed successfully.'
        }
        failure {
            echo 'Build or deployment failed.'
        }
    }
}