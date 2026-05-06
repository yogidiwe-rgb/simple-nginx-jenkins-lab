pipeline {
    agent any

    parameters {
        choice(name: 'TARGET_ENV', choices: ['auto', 'test', 'prod'], description: 'Deployment target. auto maps main/master to prod and all other branches to test.')
        string(name: 'DOCKERHUB_REPO', defaultValue: 'DOCKERHUB_USERNAME/simple-nginx-app', description: 'Docker Hub repository, for example username/simple-nginx-app')
        string(name: 'GIT_REPO_URL', defaultValue: 'https://github.com/GITHUB_USERNAME/simple-nginx-app.git', description: 'GitHub repository URL')
        string(name: 'GIT_BRANCH', defaultValue: 'main', description: 'Branch to checkout')
        string(name: 'TEST_KUBE_CONTEXT', defaultValue: 'kind-test', description: 'kubectl context for the test kind cluster')
        string(name: 'PROD_KUBE_CONTEXT', defaultValue: 'kind-prod', description: 'kubectl context for the prod kind cluster')
    }

    environment {
        DOCKERHUB_CREDENTIALS_ID = 'dockerhub-credentials'
        GITHUB_CREDENTIALS_ID = 'github-credentials'
        APP_NAME = 'simple-nginx-app'
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: params.GIT_BRANCH,
                    credentialsId: env.GITHUB_CREDENTIALS_ID,
                    url: params.GIT_REPO_URL
            }
        }

        stage('Resolve Environment') {
            steps {
                script {
                    def branchName = params.GIT_BRANCH?.trim()
                    def selectedEnv = params.TARGET_ENV == 'auto'
                        ? ((branchName == 'main' || branchName == 'master') ? 'prod' : 'test')
                        : params.TARGET_ENV

                    env.DEPLOY_ENV = selectedEnv
                    env.APP_ENV = selectedEnv.toUpperCase()
                    env.IMAGE_TAG = selectedEnv
                    env.IMAGE_URI = "${params.DOCKERHUB_REPO}:${env.IMAGE_TAG}"
                    env.KUBE_CONTEXT = selectedEnv == 'prod' ? params.PROD_KUBE_CONTEXT : params.TEST_KUBE_CONTEXT
                    env.KUBE_NAMESPACE = selectedEnv
                }
            }
        }

        stage('Static Validation') {
            steps {
                sh 'docker --version'
                sh 'kubectl version --client=true'
                sh 'kubectl kustomize k8s/${DEPLOY_ENV}'
            }
        }

        stage('Build & Tag') {
            steps {
                sh 'docker build --build-arg APP_ENV=${APP_ENV} -t ${IMAGE_URI} .'
            }
        }

        stage('Push') {
            steps {
                withCredentials([usernamePassword(credentialsId: env.DOCKERHUB_CREDENTIALS_ID, usernameVariable: 'DOCKERHUB_USERNAME', passwordVariable: 'DOCKERHUB_TOKEN')]) {
                    sh 'echo "$DOCKERHUB_TOKEN" | docker login --username "$DOCKERHUB_USERNAME" --password-stdin'
                    sh 'docker push ${IMAGE_URI}'
                }
            }
        }

        stage('Deploy') {
            steps {
                sh 'kubectl --context ${KUBE_CONTEXT} create namespace ${KUBE_NAMESPACE} --dry-run=client -o yaml | kubectl --context ${KUBE_CONTEXT} apply -f -'
                sh 'kubectl --context ${KUBE_CONTEXT} kustomize k8s/${DEPLOY_ENV} | sed "s|DOCKERHUB_USERNAME/simple-nginx-app|${DOCKERHUB_REPO}|g" | kubectl --context ${KUBE_CONTEXT} apply -f -'
                sh 'kubectl --context ${KUBE_CONTEXT} rollout status deployment/${APP_NAME} -n ${KUBE_NAMESPACE} --timeout=120s'
            }
        }
    }

    post {
        always {
            sh 'docker logout || true'
        }
        success {
            echo "Deployment succeeded: ${IMAGE_URI} to ${KUBE_CONTEXT}/${KUBE_NAMESPACE}"
        }
    }
}
