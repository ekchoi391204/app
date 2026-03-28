pipeline {
    agent {
        kubernetes {
            yaml """
apiVersion: v1
kind: Pod
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
        EKS_CLUSTER_NAME = 'frodo'          // 클러스터 이름 반영
        K8S_DEPLOYMENT_NAME = 'myapp'       // 실제 배포된 Deployment 이름
        K8S_CONTAINER_NAME = 'myapp'        // Deployment 내 컨테이너 이름
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
                script {
                    // 기본 jnlp 컨테이너에서 git 태그 추출
                    def commitHash = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                    env.IMAGE_TAG = commitHash
                    echo "Current Image Tag: ${env.IMAGE_TAG}"
                }
                
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
                container('aws-kubectl') {
                    // 분리된 두 개의 Credentials(Secret text)를 각각 매핑
                    withCredentials([
                        string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')
                    ]) {
                        sh """
                        # 1. EKS 접속 설정 업데이트
                        aws eks update-kubeconfig --name ${EKS_CLUSTER_NAME} --region ${AWS_REGION}
                        
                        # 2. kubectl 바이너리 설치 (최신 안정 버전)
                        curl -LO "https://dl.k8s.io/release/\$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
                        chmod +x ./kubectl
                        
                        # 3. 이미지 업데이트 적용
                        ./kubectl set image deployment/${K8S_DEPLOYMENT_NAME} \
                          ${K8S_CONTAINER_NAME}=${DOCKER_USERNAME}/${DOCKER_REPO}:${env.IMAGE_TAG}
                        
                        # 4. 배포 상태 모니터링
                        ./kubectl rollout status deployment/${K8S_DEPLOYMENT_NAME}
                        """
                    }
                }
            }
        }
    }
}