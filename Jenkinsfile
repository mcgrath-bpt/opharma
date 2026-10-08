pipeline {
  agent any
  options { disableConcurrentBuilds(); timestamps() }
  stages {
    stage('Dependencies') {
      steps {
        sh 'cd pharma-commercial-lab && python3 -m venv .venv'
        sh 'cd pharma-commercial-lab && .venv/bin/python -m pip install -r requirements-dev.txt'
      }
    }
    stage('Contract schema and compatibility') {
      steps {
        sh 'cd pharma-commercial-lab && .venv/bin/python src/odcs.py'
        sh 'cd pharma-commercial-lab && .venv/bin/python src/check_contract_changes.py'
      }
    }
    stage('Regression and recovery') {
      steps { sh 'cd pharma-commercial-lab && .venv/bin/python -m unittest discover -s tests -v' }
    }
    stage('Independent recurring acceptance') {
      steps {
        sh 'cd pharma-commercial-lab && .venv/bin/python src/ci_acceptance.py --out build/acceptance'
        sh 'cd pharma-commercial-lab && .venv/bin/python src/export_integrations.py'
      }
    }
  }
  post {
    always {
      archiveArtifacts artifacts: 'pharma-commercial-lab/build/acceptance/evidence/**/*.json,pharma-commercial-lab/contracts/odcs/*.json,pharma-commercial-lab/integrations/**/*', allowEmptyArchive: true
    }
  }
}
