FROM python:3.8

# set shanghai timezone
RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && echo 'Asia/Shanghai' >/etc/timezone


COPY ./ ./

# install dev tools
RUN apt-get update --allow-unauthenticated &&\
    apt-get install vim -y && \
    apt-get install curl -y && \
    apt-get install net-tools -y && \
    apt-get install less && \
    apt-get install lrzsz && \
    apt-get install -y tmux && \
    echo set nu >> /etc/vim/vimrc && \
    echo set fileencoding=utf-8 >> /etc/vim/vimrc && \
    echo set tabstop=4 >> /etc/vim/vimrc && \
    echo set autoindent  >> /etc/vim/vimrc && \
    echo set cursorline  >> /etc/vim/vimrc && \
    echo set smartindent  >> /etc/vim/vimrc && \
    echo set shiftwidth=4  >> /etc/vim/vimrc && \
    pip config set global.index-url https://mirrors.aliyun.com/pypi/simple &&\
    pip install -r requirements.txt

EXPOSE 8744
