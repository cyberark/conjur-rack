pipeline {
  agent { label 'executor-v2' }

  triggers {
    cron(getDailyCronString())
  }

  options {
    timestamps()
    buildDiscarder(logRotator(daysToKeepStr: '30'))
  }

  stages {

    stage('Run tests') {
      steps {
        sh './test.sh'
      }
    }

    // Only publish to RubyGems if the HEAD is
    // tagged with the same version as in version.rb

    stage('Publish to RubyGems') {
      agent { label 'executor-v2' }

      when {
        expression { currentBuild.resultIsBetterOrEqualTo('SUCCESS') }
        branch "master"
        expression {
          def exitCode = sh returnStatus: true, script: ''' set +x
            echo "Determining if publishing is requested..."

            VERSION=`cat lib/conjur/rack/version.rb | grep VERSION | sed 's/.* "//;s/"//'`
            echo Declared version: $VERSION

            # Jenkins git plugin is broken and always fetches with `--no-tags`
            # (or `--tags`, neither of which is what you want), so tags end up
            # not being fetched. Try to fix that.
            # (Unfortunately this fetches all remote heads, so we may have to find
            # another solution for bigger repos.)
            git fetch -q

            # note when tag not found git rev-parse will just print its name
            TAG=`git rev-list -n 1 "v$VERSION" 2>/dev/null || :`
            echo Tag v$VERSION: $TAG

            HEAD=`git rev-parse HEAD`
            echo HEAD: $HEAD

            test "$HEAD" = "$TAG"
          '''
          return exitCode == 0
        }
      }
      steps {
        // Clean up first
        sh '''docker run -i --rm -v $PWD://usr/src/app -w /usr/src/app --entrypoint /bin/sh alpine/git \
            -c "git config --global --add safe.directory /usr/src/app && \
            git clean -fxd" '''

        sh './publish.sh'

        // Clean up again...
        sh '''docker run -i --rm -v $PWD://usr/src/app -w /usr/src/app --entrypoint /bin/sh alpine/git \
            -c "git config --global --add safe.directory /usr/src/app && \
            git clean -fxd" '''
        deleteDir()

      }
    }

  }
  
  post {
    always {
      cleanupAndNotify(currentBuild.currentResult)
    }
  }
}
