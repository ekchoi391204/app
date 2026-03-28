pipeline {
    agent {
        kubernetes {
            yaml """
apiVersion: v1
kind: Pod
metadata:
  labels:
    jenkins: slave
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
      image: amazon/aws-cli:latest
      command: ["cat"]
      tty: true
    - name: jnlp
      image: jenkins/inbound-agent:3355.v388858a_47b_33-3-jdk21
      env:
        - name: JENKINS_URL
          value: "http://k8s-jenkins-jenkins-d36603890d-3a5db5674f925c53.elb.ap-northeast-2.amazonaws.com:8080/"
        - name: JENKINS_TUNNEL
          value: "jenkins-agent.jenkins.svc.cluster.local:50000"
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
        EKS_CLUSTER_NAME = 'frodo' // 실제 클러스터명으로 변경 (예: eks-cluster)
        K8S_DEPLOYMENT_NAME = 'myapp'       // 실제 배포된 Deployment 이름
        K8S_CONTAINER_NAME = 'myapp'        // Deployment 내의 컨테이너 이름
        DOCKER_USERNAME = 'ekchoi391204'
        DOCKER_REPO = 'app'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build and Push Image') {
            steps {
                // 1. git이 있는 jnlp 컨테이너에서 태그 추출 (기본 컨테이너 실행)
                script {
                    def commitHash = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                    env.IMAGE_TAG = commitHash
                    echo "Current Image Tag: ${env.IMAGE_TAG}"
                }
                
                // 2. kaniko 컨테이너로 전환하여 빌드 및 푸시
                container('kaniko') {
                    sh """
                    /kaniko/executor \
                      --dockerfile=Dockerfile \
                      --context=${WORKSPACE} \
                      --destination=${DOCKER_USERNAME}/${DOCKER_REPO}:${env.IMAGE_TAG} \
                      --destination=${DOCKER_USERNAME}/${DOCKER_REPO}:latest
                    """
                }
            }
        }

        stage('Deploy to EKS') {
            steps {
                // 3. aws/kubectl이 있는 컨테이너로 전환하여 배포
                container('aws-kubectl') {
                    withCredentials([
                        usernamePassword(credentialsId: 'aws-credentials-id', // Jenkins에 등록한 AWS Credential ID
                                         passwordVariable: 'AWS_SECRET_ACCESS_KEY', 
                                         usernameVariable: 'AWS_ACCESS_KEY_ID')
                    ]) {
                        sh """
                        # kubectl 설치 확인 및 설정
                        aws eks update-kubeconfig --name ${EKS_CLUSTER_NAME} --region ${AWS_REGION}
                        
                        # 이미지 업데이트
                        kubectl set image deployment/${K8S_DEPLOYMENT_NAME} \
                          ${K8S_CONTAINER_NAME}=${DOCKER_USERNAME}/${DOCKER_REPO}:${env.IMAGE_TAG}
                        
                        # 배포 상태 확인
                        kubectl rollout status deployment/${K8S_DEPLOYMENT_NAME}
                        """
                    }
                }
            }
        }
    }
}