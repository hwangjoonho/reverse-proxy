pipeline {
    agent any
    options {
        skipDefaultCheckout()  // 자동 git clone 제거
    }
    environment {

        // GIT 관련 변수 작성 필요
        
        GIT_CREDENTIALS_ID = "github-token"
        GIT_URL = "github.com/hwangjoonho/reverse-proxy.git" // (http:// 또는 https:// 제거)
        BRANCH="main"

    }
    parameters {
        string(name: 'FRONT_PROJECT_NAME', defaultValue: 'front-project', description: 'Front Project Name')
        string(name: 'FRONT_PROJECT_ENV', defaultValue: 'local', description: 'Front Project Environment')
        string(name: 'FRONT_PROJECT_CONTAINER_PORT', defaultValue: '80', description: 'Front Project Container Port')
    }   
    stages {
        stage("Clean"){
            steps {
                script {
                    echo '🧹 기존 파일 삭제 중...'
                    sh 'rm -rf ./source/* .* || true'
                }
            }
        }
        stage("Git Clone") {
            steps {
                dir('source') {
                    script {

                        echo "Workspace: ${WORKSPACE}"
                            
                        sh 'pwd'
                        
                        try {
                        echo 'Git Clone'    
                        git credentialsId: "${GIT_CREDENTIALS_ID}", url: "http://${GIT_URL}", branch: "${BRANCH}", poll: true, changelog: true
                            }
                        catch(Exception e) {
                            currentBuild.result = 'FAILURE'
                        }
                    }
                }
            }
        }
        stage('Load ENV') {
            steps {
                dir('source') {
                    script {

                        echo "Workspace: ${WORKSPACE}"
                            
                        sh 'pwd'
                        if (fileExists('./.env')) {
                            def lines = readFile("./.env").split("\n")

                            for (line in lines) {
                                line = line.trim()
                                if (!line || line.startsWith("#")) continue  // 빈 줄 또는 주석 무시
                                if (line.contains("=")) {
                                    def (key, value) = line.split("=", 2)
                                    key = key.trim()
                                    value = value.trim()
                                    // Jenkins 전역 env 변수로 설정s
                                    env."${key}" = value
                                    echo "Set env.${key} = ${value}"
                                }
                            }
                        } else {
                            error(".env 파일이 존재하지 않음")
                        }
                    }
                }
            }
        }
        stage('Print ENV') {
            steps {
                echo "REVERSE_NGINX_VERSION: ${env.REVERSE_NGINX_VERSION}"
                echo "REVERSE_PROJECT_ENV: ${env.REVERSE_PROJECT_ENV}"
                echo "FRONT_PROJECT_NAME: ${params.FRONT_PROJECT_NAME}"
                echo "FRONT_PROJECT_ENV: ${params.FRONT_PROJECT_ENV}"
                echo "FRONT_PROJECT_CONTAINER_PORT: ${params.FRONT_PROJECT_CONTAINER_PORT}"
            }
        }
        stage('Build') {
            steps {
                script {
                    def result = sh(script: "docker images --format '{{.Repository}}:{{.Tag}}' | grep -q '${params.FRONT_PROJECT_NAME}' && echo 'FOUND' || echo 'NOT_FOUND'", returnStdout: true).trim()

                    def confExists = fileExists("conf.d/default.conf")

                    sh"""
                    pwd
                    ls -la
                    whoami
                    """

                    
                    if (confExists && result == 'FOUND') {
                        sh """
                        

                            echo "🗂 원래 존재하던 Image , reverse-proxy 컨테이너 변화 없음"
                            echo "🗂 conf.d/default.conf 존재"

                        """
                    }
                    else if (fileExists('conf.d/default.conf') && result == 'NOT_FOUND'){
    
                            sh """
                                echo "🗂 backup 디렉토리에 default.conf 파일 존재"

                                mkdir -p backup || true
                                
                                mv conf.d/default.conf backup/default.conf || true
                            """

                            // 기존 default.conf 읽기
                            def configFile = readFile 'backup/default.conf'

                            // 마지막 중괄호 `}` 제거
                            if (configFile.trim().endsWith("}")) {
                                configFile = configFile.trim()[0..-2].trim()  
                            }

                            configFile += """
                                location /${params.FRONT_PROJECT_ENV}/${params.FRONT_PROJECT_NAME}/ {
                                    proxy_pass http://${params.FRONT_PROJECT_NAME}:${params.FRONT_PROJECT_CONTAINER_PORT}/;
                                    proxy_set_header Host \$host;
                                    proxy_set_header X-Real-IP \$remote_addr;
                                    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                                }
                            }
                            """  

                            // 변경된 내용 저장
                            writeFile file: 'conf.d/default.conf', text: configFile

                            sh """
                                timestamp=\$(date +'%Y%m%d%H%M%S')

                                mv backup/default.conf backup/default.conf_\${timestamp} || true
                            """
                    }   
                    else {

                        sh """
                            mkdir -p conf.d || true
                            mkdir -p backup || true   

                            echo 'server {
                                listen ${params.REVERSE_CONTAINER_PORT};
                                server_name localhost;
                                location / {
                                    root /usr/share/nginx/html;
                                }
                            }' > conf.d/default.conf
                        """
                    }
                } 
            }
        }
        stage('Reverse Build') {
            steps {
                script {
                // 만약 reverse-proxy 도커 이미지가 존재하면
                    def imageExists = sh(script: "docker images -q reverse-proxy | grep -q . && echo 'FOUND' || echo 'NOT_FOUND'", returnStdout: true).trim()

                    if (imageExists == 'FOUND') {
                        sh """
                            docker restart reverse-proxy
                        """
                    }else{
                        sh """
                            docker-compose -f source/docker-compose.yml --profile ${params.FRONT_PROJECT_ENV} up -d 
                        """
                    }
                }
            }
        }
    }
}