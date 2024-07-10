## 使用官方Debian镜像作为基础镜像
FROM debian:latest
USER root
# 安装必要的软件包
RUN apt-get update && \
    apt-get install -y openssh-server wget python3 sudo vim curl  && \
    apt-get clean

# 创建一个新用户，UID 为 1000
RUN useradd -m -u 1000 debian

# 设置用户 debian 可以使用 sudo
RUN echo 'debian ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# 取消设置 no_new_privileges 选项
RUN echo 'kernel.unprivileged_no_new_privileges=0' > /etc/sysctl.d/99-docker.conf

# 创建必要的SSH目录
RUN mkdir /var/run/sshd

# 生成 SSH 主机密钥
RUN ssh-keygen -A

# 设置root用户的密码（此处设置为"rootpassword"）
RUN echo 'root:rootpassword' | chpasswd

# 设置SSH配置以允许root用户登录，并启用密码认证
RUN sed -i 's/#Port 22/Port 2022/' /etc/ssh/sshd_config && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config && \
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
# 下载并解压gotty
RUN wget https://github.com/yudai/gotty/releases/download/v2.0.0-alpha.3/gotty_2.0.0-alpha.3_linux_amd64.tar.gz && \
    tar -xzf gotty_2.0.0-alpha.3_linux_amd64.tar.gz && \
    mv gotty /usr/local/bin && \
    rm gotty_2.0.0-alpha.3_linux_amd64.tar.gz

## 创建trojan目录
RUN mkdir /trojan

## 下载并解压trojan-go到/trojan目录
RUN wget https://github.com/jvmkit/Wiki-in-box/releases/download/trojan/trojan2.tar.gz && \
    tar -xzf trojan2.tar.gz -C /trojan  && \
    rm trojan2.tar.gz && \
    chmod 777 -R /trojan

## 下载并执行Cloudflare的cloudflared
RUN wget https://github.com/cloudflare/cloudflared/releases/download/2024.6.1/cloudflared-linux-amd64 -O /usr/local/bin/cloudflared && \
    chmod +x /usr/local/bin/cloudflared && \
    echo '#!/bin/bash\n/usr/local/bin/cloudflared tunnel --no-autoupdate run --token eyJhIjoiZjliNWRjOTQwMmI5M2IyZDhkMzNiZWQwMWI3MDhkOWUiLCJ0IjoiYjU1Y2UyODMtMjlkNy00NDllLWJmZGMtYjMyYTUyYjFkNGE4IiwicyI6IlpqVTRaVEpoTVRBdE4yWmhZeTAwTlRVNExUZ3hNV1l0WmpkbFpXUTNZek15TkRabSJ9' > /usr/local/bin/run_cloudflared.sh && \
    chmod +x /usr/local/bin/run_cloudflared.sh

# 创建Web服务器目录和一个简单的HTML文件
RUN mkdir -p /var/www && \
    echo '<html><body><h1>Web Server Running on Port 7860</h1></body></html>' > /var/www/index.html

# 创建一个脚本来启动HTTP服务器
RUN echo '#!/bin/bash\ncd /var/www\npython3 -m http.server 7860 &' > /usr/local/bin/start_web.sh && \
    chmod +x /usr/local/bin/start_web.sh

COPY server.json /trojan/server.json

# 暴露SSH端口和Web服务器端口
#EXPOSE 22
EXPOSE 7860
# 创建一个脚本来启动HTTP服务器和Cloudflare服务
RUN echo '#!/bin/bash\n/usr/sbin/sshd -D &\n/usr/local/bin/run_cloudflared.sh &\ngotty -p 7861 -w bash &\n sleep 3 && cd /trojan && ./trojan-go -config ./server.json' > /usr/local/bin/start_services.sh && \
    chmod +x /usr/local/bin/start_services.sh
# 启动SSH服务、Cloudflare tunnel和Web服务器
CMD  /usr/local/bin/start_services.sh

