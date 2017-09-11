FROM golang
MAINTAINER James Knott <devops@buildmystartup.io>


ADD . /go/src/jenkins-docker
RUN go install jenkins-docker
CMD /go/bin/jenkins-docker

EXPOSE 8080
