[TOC]
# 背景
持续集成和持续交付,在比较大的软件中，会不断的对产品进行优化，我理解的的集成就是不断的往一套体系中添加新的东西。拿个人计算机的发展来讲，刚开始只有一个主机和屏幕，后来有了音响、摄像头等。持续集成就是不断地将音响、摄像头等往计算机这个体系中存放。持续交付，不断开发新功能，或者不断的修复了bug，最终要让客户看看，因为最终由他们来掏钱。交付的方式有很多种，我看见客户，双手把产品交给客户，客户告诉我地址，我发快递给他。这两种属于传统行业的交付方式，当然还有很多种交付方式。软件这边交付会省去这些，软件开发完成了，通过互联网就可以直接交付给客户，因此客户可以快速的看到结果再反馈问题给供应商。持续交付就是可以快速的响应这种需求，且提供给客户。这是我认识的CICD，在这个领域，各家都有各家的实现，没有一个普适的解决方案，大体的思路是一致的。
# 名词解释
## CICD
持续集成和持续交付和持续部署
## GitLabRunner(gr)
gr是一个应用程序，但看起来它更像一个服务。拿到gitlab仓库的key，将仓库注册在gr中，称之为项目中的runners。
# 任务描述
python语言程序，dockerfile构建程序运行环境，pytest单元测试，tornado提供web服务。
# 开始之前
## 之前
一次vue中，我的代码在开发机中，跑代码的服务器在21gpu上，用容器映射了一个目录。开发机commit代码，push代码，21gpu上的那个目录也是代码，它只做pull操作，node.js在容器中run着，所以一直持续的动作就是commit->push->pull，因此想省了21gpu中pull的动作，看了gr，就尝试去做了起来，搞了一天失败了。
## 现在
brand项目中要对代码进行测试，期望在gitlab repo的pipeline中看到测试的结果，这样对管理者来说是一件便捷的事情，可以省去环境构建等操作，其本质是加快了测试的进度。实现的原理就是，gitlab repo与gr的通信，发一些请求，返回过来一些数据，gitlab repo的pipeline根据数据进行展示。
## 本质
尝试解释这件事情的本质，代码和环境的传输表现。开发机commit->push到gitlab服务器，gitalb服务器通知gr来执行任务，将代码交给gr服务器，gr由代码有环境，完成打包，测试和发布的工作。
# SOP
这里采用了时间顺序，以第一次构建、测试和发布的顺序来介绍，dev代表开发工程师、ops代表运维工程师、cicd不知道是什么工程师来做。
## dev
### server_code
下面是一个使用tornado实现的一个简单的web服务的接口，提供了get和post两种请求方式，返回的都是一个字符串。这其中会包含一些包的信息，由于太过简单，我就不在提供requirements.txt的说明。
```
import tornado.ioloop
import tornado.web

class MainHandler(tornado.web.RequestHandler):

    def get(self):
        self.write("test gitlab_cicd api success")

    def post(self):
        self.write("test gitlab_cicd api success")


def make_app():
    return tornado.web.Application([
        (r"/test", MainHandler),
    ], debug=True)


if __name__ == "__main__":
    app = make_app()
    app.listen(8744)
    tornado.ioloop.IOLoop.current().start()
```
### test_code
这是使用pytest的一个简单的示例测试代码，期望的是helloworld，结果需要调用某个函数或者某个流程，是单元测试还是集成测试，可以写在这里。
```
import pytest

def test_gitlab_cicd():
    expected = 'helloworld'
    results = 'helloworld'
    assert expected == results
```
## ops
运维写的dockerfile，包括了时区设置和一些常用的Linux工具，将项目代码复制到镜像中和安装一些项目依赖的pypi包，最后暴露一个容器接口。
```
FROM python:3.8

# set shanghai timezone
RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && echo 'Asia/Shanghai' >/etc/timezone

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
    pip config set global.index-url https://mirrors.aliyun.com/pypi/simple

# 项目代码复制到镜像内部
COPY ./ ./

# project dependent 
RUN pip install -r requirements.txt

EXPOSE 8744
```
## cicd
### 关键字说明
1. stages:代表这个pipeline的阶段，这里面有三个阶段：build、test、deploy，每个阶段可以有多个job。
2. services:
3. variables:定义的变量，后续可以通过名称来使用
4. job_build:自定义的job名称
5. image:镜像，代表这个job用容器来执行
6. stage:隶属哪个stages
7. script:脚本执行命令
8. only:指定哪个分支运行
### 思路说明
1. 构建项目所需的环境，称为build
2. 测试项目所需测试的逻辑，称为test
3. 将项目进行部署，称为deploy
### 进一步的思考
一般情况下，只需要build一次，之后可以一直使用这个环境，除非环境变化了，比如Java的maven中引进了新的package，python的pypi中引入了新的package。需要多次测试，初次发布服务或者新增功能或者修复bug都需测试。服务的发布，但凡是代码或者环境的变化都会导致服务重新发布，可以采用替换式发布，也可以采用增量式发布，也即，旧的不变，会有新的地址供访问。依照这些，特性，如何高效的设计？镜像中是否包含代码和环境？如何动态的检测到环境的变动？环境变动即重新build镜像，环境没变化就不去build镜像，测试和发布使用原有的镜像。如果代码在镜像外面，如何测试？挂载吗？job的执行方式如何选择？
```
stages:
  - build
  - test
  - deploy

services:
    - name: docker:dind
      entrypoint: ["env", "-u", "DOCKER_HOST"]
      command: ["dockerd-entrypoint.sh"]

variables:
    DOCKER_HOST: tcp://docker:2375/
    DOCKER_DRIVER: overlay2
    DOCKER_TLS_CERTDIR: ""


job_build:
  image: docker:stable
  stage: build
  script:
    - echo "=============== docker build image  ==============="
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
    - docker build -t $CI_REGISTRY_IMAGE:0.0.2 .
    - docker push $CI_REGISTRY_IMAGE:0.0.2
  only:
    - mainx

job_test:
  image: $CI_REGISTRY_IMAGE:0.0.2
  stage: test
  script:
    - echo "=============== app unit test  ==============="
    - pytest test/cicd.py
  only:
    - mainx

job_deploy:
  image: docker:stable
  stage: deploy
  script:
    - echo "=============== deploy  server ==============="
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
    - docker run -itd --name trun -p 20200:8744 $CI_REGISTRY_IMAGE:0.0.2 python server.py
  only:
    - mainx
```
## gr的安装以及仓库注册到gr
### gr安装
这个应该有很多教程，推荐使用docker，这个项目里我没有进行安装，因为gr已经存在与服务中
### 仓库注册到gr
1. setting-->cicd-->runners-->Specific runners.拿到url和token.
2. 转向gr服务器，需要有点Linux命令经验。
```
docker run -it --rm -v /srv/gitlab-runner/config:/etc/gitlab-runner gitlab/gitlab-runner register \
  --non-interactive \
  --executor "docker" \
  --docker-privileged \
  --docker-image docker:stable \
  --url "https://gitlab.com/" \
  --registration-token "lfdkajsflasfd" \
  --description "test_gitlab_cicd" \
  --tag-list "test_gitlab_cicd" \
  --run-untagged="true" \
  --locked="false" \
  --access-level="not_protected";
```
# 参考
1. [gitlab_cicd](https://docs.gitlab.com/ee/ci/)
2. 参考了网络上各位大佬的博客，没有记录下来，这里不一一列举
# 杂谈
- 就像开头说的，cicd是一个很宏大的话题。我理解到它涵盖的知识以及人员是非常丰富的，比如项目经理的角色，开发、测试、运维等。可以用cicd将这些角色的工作内容串联起来，如果一个团队有很多人， 可想而知这样的系统是相当的复杂的，但我据我所聊天的经历得知，一些大厂应该已经投入使用了这些，但是他们并没有公开他们的策略，我也一直觉得在这个领域没有一个标准化操作（SOP），但大家都会使用自己的能力来完成工作所需要的完成的任务。一直觉得这像，八仙过海各显神通。
- 这次是对于上次使用vue失败的一个跟进，上次任务停留在仓库向gr注册那一步。我想，可能是因为我们公司的gilab服务器和我们组的21服务器是不通的，以至于我后来放弃了，之前zoneyet的网络也是值得忧虑的事情。这里我有一些我的想法和思考，我也根据我的策略实现了我想要的效果，虽然这种想法和设计是不完备不完美的，但看起来他能完成一些之前需要我手动来完成的事情了。
- 关于Jenkins和gitrunner。起初是想要使用Jenkins，算是久负盛名？Jenkins是java写的，配置文件一股子Java味道，我的思考是因为文档多于gitrunner。手里使用的代码仓库是gitlab，对gitlab的容器注册和包注册有一些了解，主要是领导想在仓库的pipeline中看到任务，当然Jenkins也可以完成这样的事情。在使用了gitlab和gitlabrunner后，我发现gitlab在cicd领域是走的挺靠前的，不能说是最好的用的工具，可以说是最积极的一个工具。
- 开始写和写到这里的时候，无时不刻的觉得自己在cicd的浅薄，望结交大佬，多一些指点和交流。
- 最后我会把代码和仓库放在github上去，最后会附上地址。这是因为gitlab中我commit了太多次，很多私密信息都到了gitlab的仓库中，因此就不放gitlab的仓库地址了。
# tags
- python
- docker
- gitlab
- gitrunner
- cicd
