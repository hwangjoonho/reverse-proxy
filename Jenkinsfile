pipeline {
    agent any
    options {
        skipDefaultCheckout()  // 자동 git clone 제거
    }
    environment {

        // GIT 관련 변수 작성 필요
        GIT_CREDENTIALS_ID = "github-token"

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

                         // scm 객체에서 url, branch 추출
                        def scmUrl = scm.getUserRemoteConfigs()[0].getUrl()
                        def scmBranch = scm.getBranches()[0].getName()

                        // 디버깅 출력 (선택)
                        echo "URL from SCM: ${scmUrl}"
                        echo "Branch from SCM: ${scmBranch}"

                        // git step 호출
                        git credentialsId: "${env.GIT_CREDENTIALS_ID}", url: scmUrl, branch: scmBranch
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
                    def result = sh(script: "grep -q '${params.FRONT_PROJECT_NAME}' conf.d/default.conf && echo 'FOUND' || echo 'NOT_FOUND'", returnStdout: true).trim()

                    def confExists = fileExists("conf.d/default.conf")

                    sh"""
                    pwd
                    ls -la
                    whoami
                    """
                    sh "echo confExists: ${confExists}"
                    sh "echo result: ${result}"


                    // default.conf 존재 여부에 따른 조건
                    if(confExists) {
                        sh 'echo conf.d/default.conf 존재'
                    } else {
                        sh 'echo conf.d/default.conf 존재하지 않음'

                        sh """
                            mkdir -p conf.d || true
                            mkdir -p backup || true   
                            echo 'server {
                                listen       80;
                                listen  [::]:80;
                                server_name localhost;
                                location / {
                                    root /usr/share/nginx/html;
                                }
                            }' > conf.d/default.conf
                        """
                    }


                    // default.conf 에 ${params.FRONT_PROJECT_NAME} 존재 여부에 따른 조건
                    if (result == 'FOUND') {
                        sh """
                        

                            echo "🗂 params.FRONT_PROJECT_NAME 존재"

                        """
                    }
                    else if (result == 'NOT_FOUND'){
    
                            sh """
                                echo "🗂 default.conf 에 params.FRONT_PROJECT_NAME 존재하지 않음"

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
                } 
            }
        }
        stage('Start Empty Container') {
            steps {
                script {
                    // Extract proxy_pass hosts using awk
                    def reverse_hosts = sh(
                        script: '''
                            awk '/proxy_pass/ {
                                gsub(";", "", $0)
                                match($0, /http:\/\/([^:/]+)/, a)
                                if (a[1] != "") print a[1]
                            }' default.conf | sort | uniq
                        ''',
                        returnStdout: true
                    ).trim().split("\n")

                    echo "Hosts found: ${reverse_hosts}"

                    // Check and start containers for each host
                    reverse_hosts.each { host ->
                        echo "Checking Docker container for host: ${host}"
                        
                        // Check if container exists and is running
                        def containerStatus = sh(
                            script: "docker ps -a --format '{{.Names}}' | grep -w '${host}' || true",
                            returnStdout: true
                        ).trim()
                        
                        def isRunning = sh(
                            script: "docker ps --format '{{.Names}}' | grep -w '${host}' || true",
                            returnStdout: true
                        ).trim()

                        if (isRunning) {
                            echo "Container running for host: ${host}"
                        } else if (containerStatus) {
                            echo "Container exists but not running for host: ${host}"
                            sh "docker start ${host}"
                        } else {
                            echo "No container found for host: ${host}"
                            sh "docker run -d --name ${host} alpine sleep infinity"
                        }
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
                            docker restart reverse-proxy || true
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