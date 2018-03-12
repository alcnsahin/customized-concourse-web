FROM node:7.2.0-slim

RUN echo deb http://http.debian.net/debian jessie-backports main >> /etc/apt/sources.list
RUN apt-get update -y && apt-get install -y -t jessie-backports ca-certificates-java  && apt-get install -y software-properties-common python-software-properties && apt-get install -y openjdk-8-jdk && update-alternatives --config java && update-java-alternatives --jre-headless --jre --set java-1.8.0-openjdk-amd64
RUN npm install -g elm@0.18.0
RUN npm install -g google-closure-compiler
RUN npm install -g elm-test@0.18.6
RUN wget https://storage.googleapis.com/golang/go1.9.2.linux-amd64.tar.gz && tar -xvf go1.9.2.linux-amd64.tar.gz && mv go /usr/local
ENV GOROOT="/usr/local/go"
ENV PATH=$GOPATH/bin:$GOROOT/bin:$PATH
RUN apt-get install -y git-core
RUN go get code.cloudfoundry.org/lager
RUN go get github.com/concourse/web
RUN go get github.com/concourse/web/proxyhandler
RUN go get -u github.com/jteeuwen/go-bindata/...
ENV PATH=/root/go/bin:$PATH
RUN apt-get install -y yui-compressor
RUN apt-get install -y vim
RUN npm install -g less
RUN less --clean-css="--advanced" assets/css/main.less
RUN apt-get install make
RUN npm install -g less-plugin-clean-css

