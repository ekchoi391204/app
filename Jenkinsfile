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
      image: gcr.io/kaniko-project/executor:v1.19.0-debug # debug 버전이 shell 실행에 유리함
      command: ["/busybox/cat"]
      tty: true
      volumeMounts:
        - name: docker-config
          mountPath: /kaniko/.docker
    - name: aws-kubectl
      image: amazon/aws-cli:latest # aws cli가 포함된 이미지 사용
      command: ["cat"]
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

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Get Commit Tag') {
            steps {
                script {
                    // git log 실패 시 에러 방지를 위해 try-catch 또는 returnStatus 활용
                    try {
                        env.COMMIT_TAG = sh(script: "git log -1 --pretty=%B | tr -dc '[:alnum:]' | cut -c1-50", returnStdout: true).trim()
                    } catch (e) {
                        env.COMMIT_TAG = "build-${env.BUILD_NUMBER}"
                    }
                    if (!env.COMMIT_TAG) env.COMMIT_TAG = "build-${env.BUILD_NUMBER}"
                }
            }
        }

        stage('Build and Push') {
            steps {
                container('kaniko') {
                    // --digest-file 등을 추가하면 이미지 추적이 더 용이합니다.
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
                    withCredentials([
                        usernamePassword(credentialsId: 'aws-credentials-id', 
                                         passwordVariable: 'AWS_SECRET_ACCESS_KEY', 
                                         usernameVariable: 'AWS_ACCESS_KEY_ID')
                    ]) {
                        sh """
                        # kubectl 설치 (aws-cli 이미지에는 kubectl이 없을 수 있으므로 설치 로직 필요 또는 병합 이미지 사용)
                        # 여기서는 클러스터 접근 권한 설정만 수행
                        aws eks update-kubeconfig --name ${EKS_CLUSTER_NAME} --region ${AWS_REGION}
                        
                        # kubectl 명령 실행 (만약 aws-cli 이미지에 kubectl이 없다면 위 Pod 정의에서 이미지를 바꿀 것)
                        curl -LO "https://dl.k8s.io/release/\$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
                        chmod +x kubectl
                        ./kubectl set image deployment/${K8S_DEPLOYMENT_NAME} ${K8S_CONTAINER_NAME}=${DOCKER_USERNAME}/${DOCKER_REPO}:${env.COMMIT_TAG}
                        ./kubectl rollout status deployment/${K8S_DEPLOYMENT_NAME}
                        """
                    }
                }
            }
        }
    }
}