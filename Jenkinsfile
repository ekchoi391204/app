pipeline {
    agent {
        kubernetes {
            yaml """
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: jenkins-kaniko
spec:
  serviceAccountName: jenkins
  containers:
    - name: kaniko
      image: gcr.io/kaniko-project/executor:latest
      command:
        - /busybox/cat
      tty: true
      volumeMounts:
        - name: docker-config
          mountPath: /kaniko/.docker
    - name: kubectl
      image: bitnami/kubectl:latest
      command:
        - cat
      tty: true
  volumes:
    - name: docker-config
      secret:
        secretName: kaniko-docker-config
        items:
          - key: config.json
            path: config.json
"""
        }
    }

    environment {
        AWS_REGION = 'ap-northeast-2'
        EKS_CLUSTER_NAME = 'your-eks-cluster'
        K8S_DEPLOYMENT_NAME = 'your-deployment'
        K8S_CONTAINER_NAME = 'your-container'
        DOCKER_USERNAME = 'ekchoi391204'
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

        stage('Build and Push Image with Kaniko') {
            steps {
                container('kaniko') {
                    sh """
                      /kaniko/executor \
                        --dockerfile=Dockerfile \
                        --context=${WORKSPACE} \
                        --destination=${DOCKER_USERNAME}/${DOCKER_REPO}:${COMMIT_TAG} \
                        --destination=${DOCKER_USERNAME}/${DOCKER_REPO}:latest
                    """
                }
            }
        }

        stage('Deploy to EKS') {
            steps {
                container('kubectl') {
                    withCredentials([
                        string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')
                    ]) {
                        sh """
                          aws eks update-kubeconfig --name ${EKS_CLUSTER_NAME} --region ${AWS_REGION}
                          kubectl set image deployment/${K8S_DEPLOYMENT_NAME} \
                            ${K8S_CONTAINER_NAME}=${DOCKER_USERNAME}/${DOCKER_REPO}:${COMMIT_TAG}
                          kubectl rollout status deployment/${K8S_DEPLOYMENT_NAME}
                        """
                    }
                }
            }
        }
    }
}