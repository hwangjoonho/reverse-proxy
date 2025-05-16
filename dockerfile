# 환경 변수 설정
ARG REVERSE_NGINX_VERSION
ARG REVERSE_PROJECT_HOST_PORT
ARG REVERSE_PROJECT_CONTAINER_PORT

# Base image
FROM nginx:${REVERSE_NGINX_VERSION}

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    curl \
    unzip \
    net-tools \
    vim \
    procps \
    && rm -rf /var/lib/apt/lists/*

# 필요한 설정이나 파일 추가 (필요시)
# COPY ./some-file /path/in/container/

# 기본적으로 80 포트 노출
EXPOSE ${REVERSE_PROJECT_CONTAINER_PORT}

# 톰캣을 실행하는 명령어
CMD ["nginx", "-g", "daemon off;"]

