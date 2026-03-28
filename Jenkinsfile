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
      image: gcr.io/kaniko-project/executor:v1.19.0-debug
      command: ["/busybox/cat"]
      tty: true
      volumeMounts:
        - name: docker-config
          mountPath: /kaniko/.docker
    - name: aws-kubectl
      image: bitnami/kubectl:latest # 또는 amazon/aws-cli:latest (환경에 맞춰 선택)
      command: ["cat"]
      tty: true
    - name: jnlp
      image: jenkins/inbound-agent:3355.v388858a_47b_33-3-jdk21
      env:
        # 에이전트가 접속할 마스터 URL을 ELB 주소로 강제 지정
        - name: JENKINS_URL
          value: "http://k8s-jenkins-jenkins-d36603890d-3a5db5674f925c53.elb.ap-northeast-2.amazonaws.com:8080/"
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
        EKS_CLUSTER_NAME = 'your-eks-cluster' // 실제 EKS 클러스터명으로 변경
        K8S_DEPLOYMENT_NAME = 'your-deployment'
        K8S_CONTAINER_NAME = 'your-container'
        DOCKER_USERNAME = 'ekchoi391204'
        DOCKER_REPO = 'app'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Get Commit Tag') {
            steps {
                script {
                    try {
                        def rawMsg = sh(script: "git log -1 --pretty=%B | tr -dc '[:alnum:]' | cut -c1-50", returnStdout: true).trim()
                        env.COMMIT_TAG = rawMsg ?: "build-${env.BUILD_NUMBER}"
                    } catch (e) {
                        env.COMMIT_TAG = "build-${env.BUILD_NUMBER}"
                    }
                    echo "Final COMMIT_TAG: ${env.COMMIT_TAG}"
                }
            }
        }

        stage('Build and Push Image') {
            steps {
                container('kaniko') {
                    sh """
                    /kaniko/executor \
                      --dockerfile=Dockerfile \
                      --context=${WORKSPACE} \
                      --destination=${DOCKER_USERNAME}/${DOCKER_REPO}:${env.COMMIT_TAG} \
                      --destination=${DOCKER_USERNAME}/${DOCKER_REPO}:latest
                    """
                }
            }
        }

        stage('Deploy to EKS') {
            steps {
                container('aws-kubectl') {
                    // Jenkins Credentials에 등록된 ID (aws-credentials-id) 사용
                    withCredentials([
                        usernamePassword(credentialsId: 'aws-credentials-id', 
                                         passwordVariable: 'AWS_SECRET_ACCESS_KEY', 
                                         usernameVariable: 'AWS_ACCESS_KEY_ID')
                    ]) {
                        sh """
                        # AWS CLI가 설치되어 있다고 가정 (필요시 설치 로직 추가)
                        aws eks update-kubeconfig --name ${EKS_CLUSTER_NAME} --region ${AWS_REGION}
                        
                        kubectl set image deployment/${K8S_DEPLOYMENT_NAME} \
                          ${K8S_CONTAINER_NAME}=${DOCKER_USERNAME}/${DOCKER_REPO}:${env.COMMIT_TAG}
                        
                        kubectl rollout status deployment/${K8S_DEPLOYMENT_NAME}
                        """
                    }
                }
            }
        }
    }
}