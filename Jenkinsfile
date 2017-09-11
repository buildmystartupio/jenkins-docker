  env.DOCKERHUB_USERNAME = 'buildmystartup'

  node("docker-test") {
    checkout scm

    stage("Unit Test") {
      sh "docker run --rm -v ${WORKSPACE}:/go/src/jenkins-docker golang go test jenkins-docker -v --run Unit"
    }
    stage("Integration Test") {
      try {
        sh "docker build -t jenkins-docker ."
        sh "docker rm -f jenkins-docker || true"
        sh "docker run -d -p 8080:8080 --name=jenkins-docker jenkins-docker"
        // env variable is used to set the server where go test will connect to run the test
        sh "docker run --rm -v ${WORKSPACE}:/go/src/jenkins-docker --link=jenkins-docker -e SERVER=jenkins-docker golang go test jenkins-docker -v --run Integration"
      }
      catch(e) {
        error "Integration Test failed"
      }finally {
        sh "docker rm -f jenkins-docker || true"
        sh "docker ps -aq | xargs docker rm || true"
        sh "docker images -aq -f dangling=true | xargs docker rmi || true"
      }
    }
    stage("Build") {
      sh "docker build -t ${DOCKERHUB_USERNAME}/jenkins-docker:${BUILD_NUMBER} ."
    }
    stage("Publish") {
      withDockerRegistry([credentialsId: 'DockerHub']) {
        sh "docker push ${DOCKERHUB_USERNAME}/jenkins-docker:${BUILD_NUMBER}"
      }
    }
  }

  node("docker-stage") {
    checkout scm

    stage("Staging") {
      try {
        sh "docker rm -f jenkins-docker || true"
        sh "docker run -d -p 8080:8080 --name=jenkins-docker ${DOCKERHUB_USERNAME}/jenkins-docker:${BUILD_NUMBER}"
        sh "docker run --rm -v ${WORKSPACE}:/go/src/jenkins-docker --link=jenkins-docker -e SERVER=jenkins-docker golang go test jenkins-docker -v"

      } catch(e) {
        error "Staging failed"
      } finally {
        sh "docker rm -f jenkins-docker || true"
        sh "docker ps -aq | xargs docker rm || true"
        sh "docker images -aq -f dangling=true | xargs docker rmi || true"
      }
    }
  }

  node("docker-prod") {
    stage("Production") {
      try {
        // Create the service if it doesn't exist otherwise just update the image
        sh '''
          SERVICES=$(docker service ls --filter name=jenkins-docker --quiet | wc -l)
          if [[ "$SERVICES" -eq 0 ]]; then
            docker network rm jenkins-docker || true
            docker network create --driver overlay --attachable jenkins-docker
            docker service create --replicas 3 --network jenkins-docker --name jenkins-docker -p 8080:8080 ${DOCKERHUB_USERNAME}/jenkins-docker:${BUILD_NUMBER}
          else
            docker service update --image ${DOCKERHUB_USERNAME}/jenkins-docker:${BUILD_NUMBER} jenkins-docker
          fi
          '''
        // run some final tests in production
        checkout scm
        sh '''
          sleep 60s
          for i in `seq 1 20`;
          do
            STATUS=$(docker service inspect --format '{{ .UpdateStatus.State }}' jenkins-docker)
            if [[ "$STATUS" != "updating" ]]; then
              docker run --rm -v ${WORKSPACE}:/go/src/jenkins-docker --network jenkins-docker -e SERVER=jenkins-docker golang go test jenkins-docker -v --run Integration
              break
            fi
            sleep 10s
          done

        '''
      }catch(e) {
        sh "docker service update --rollback  jenkins-docker"
        error "Service update failed in production"
      }finally {
        sh "docker ps -aq | xargs docker rm || true"
      }
    }
  }
