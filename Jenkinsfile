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
        # 1. 논리적 주소 (ELB 주소)
        - name: JENKINS_URL
          value: "http://k8s-jenkins-jenkins-d36603890d-3a5db5674f925c53.elb.ap-northeast-2.amazonaws.com:8080/"
        # 2. 물리적 통신 주소 (내부 서비스 DNS로 직결하여 포트 차단 해결)
        - name: JENKINS_TUNNEL
          value: "jenkins.jenkins.svc.cluster.local:50000"
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
        EKS_CLUSTER_NAME = 'frodor' // 실제 EKS 클러스터 이름으로 수정
        K8S_DEPLOYMENT_NAME = 'myapp'       // 실제 배포 이름으로 수정
        K8S_CONTAINER_NAME = 'myapp'
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
                container('kaniko') {
                    script {
                        // 커밋 해시를 태그로 사용
                        def commitHash = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                        env.IMAGE_TAG = commitHash
                        
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
        }

        stage('Deploy to EKS') {
            steps {
                container('aws-kubectl') {
                    withCredentials([
                        usernamePassword(credentialsId: 'aws-credentials-id', // Jenkins에 등록한 AWS Credential ID
                                         passwordVariable: 'AWS_SECRET_ACCESS_KEY', 
                                         usernameVariable: 'AWS_ACCESS_KEY_ID')
                    ]) {
                        sh """
                        aws eks update-kubeconfig --name ${EKS_CLUSTER_NAME} --region ${AWS_REGION}
                        
                        kubectl set image deployment/${K8S_DEPLOYMENT_NAME} \
                          ${K8S_CONTAINER_NAME}=${DOCKER_USERNAME}/${DOCKER_REPO}:${env.IMAGE_TAG}
                        
                        kubectl rollout status deployment/${K8S_DEPLOYMENT_NAME}
                        """
                    }
                }
            }
        }
    }
}