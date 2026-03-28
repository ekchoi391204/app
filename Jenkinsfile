pipeline {
    agent {
        kubernetes {
            cloud 'kubernetes'
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
        - /busybox/sh
      args:
        - -c
        - sleep 9999999
      tty: true
      volumeMounts:
        - name: docker-config
          mountPath: /kaniko/.docker

    - name: deploy
      image: amazon/aws-cli:2.15.0
      command:
        - sh
      args:
        - -c
        - sleep 9999999
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
        EKS_CLUSTER_NAME = 'frodo'
        K8S_DEPLOYMENT_NAME = 'myapp'
        K8S_CONTAINER_NAME = 'myapp'
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

        stage('Generate Tag') {
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
                    echo "TAG: ${env.COMMIT_TAG}"
                }
            }
        }

        stage('Build & Push (Kaniko)') {
            steps {
                container('kaniko') {
                    sh """
                      /kaniko/executor \
                        --dockerfile=${WORKSPACE}/Dockerfile \
                        --context=${WORKSPACE} \
                        --destination=${DOCKER_USERNAME}/${DOCKER_REPO}:${COMMIT_TAG} \
                        --destination=${DOCKER_USERNAME}/${DOCKER_REPO}:latest \
                        --cache=true
                    """
                }
            }
        }

        stage('Deploy to EKS') {
            steps {
                container('deploy') {
                    withCredentials([
                        string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')
                    ]) {
                        sh """
                          curl -LO https://dl.k8s.io/release/v1.29.14/bin/linux/amd64/kubectl
                          install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

                          aws eks update-kubeconfig \
                            --name ${EKS_CLUSTER_NAME} \
                            --region ${AWS_REGION}

                          kubectl set image deployment/${K8S_DEPLOYMENT_NAME} \
                            ${K8S_CONTAINER_NAME}=${DOCKER_USERNAME}/${DOCKER_REPO}:${COMMIT_TAG}

                          kubectl rollout status deployment/${K8S_DEPLOYMENT_NAME}
                        """
                    }
                }
            }
        }
    }

    post {
        success {
            echo 'CI/CD SUCCESS'
        }
        failure {
            echo 'CI/CD FAILED'
        }
    }
}