pipeline {
    agent any

    parameters {
        choice(name: 'TARGET_ENV', choices: ['auto', 'test', 'prod'], description: 'Deployment target. auto maps main/master to prod and all other branches to test.')
        string(name: 'DOCKERHUB_REPO', defaultValue: 'yogisre12345/simple-nginx-app', description: 'Docker Hub repository, for example username/simple-nginx-app')
        string(name: 'GIT_BRANCH', defaultValue: 'main', description: 'Branch to checkout')
        string(name: 'TEST_KUBE_CONTEXT', defaultValue: 'kind-test-cluster', description: 'kubectl context for the test kind cluster')
        string(name: 'PROD_KUBE_CONTEXT', defaultValue: 'kind-prod-cluster', description: 'kubectl context for the prod kind cluster')
    }

    environment {
        DOCKERHUB_CREDENTIALS_ID = 'dockerhub-credentials'
        GITHUB_CREDENTIALS_ID = 'github-credentials'
        APP_NAME = 'simple-nginx-app'
    }

    stages {
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
                script {
                    runCmd('docker --version')
                    runCmd('kubectl version --client=true')
                    runCmd("kubectl kustomize k8s/${env.DEPLOY_ENV}")
                }
            }
        }

        stage('Build & Tag') {
            steps {
                script {
                    runCmd("docker build --build-arg APP_ENV=${env.APP_ENV} -t ${env.IMAGE_URI} .")
                }
            }
        }

        stage('Push') {
            steps {
                withCredentials([usernamePassword(credentialsId: env.DOCKERHUB_CREDENTIALS_ID, usernameVariable: 'DOCKERHUB_USERNAME', passwordVariable: 'DOCKERHUB_TOKEN')]) {
                    script {
                        if (isUnix()) {
                            sh 'echo "$DOCKERHUB_TOKEN" | docker login --username "$DOCKERHUB_USERNAME" --password-stdin'
                        } else {
                            powershell '$env:DOCKERHUB_TOKEN | docker login --username $env:DOCKERHUB_USERNAME --password-stdin'
                        }
                        runCmd("docker push ${env.IMAGE_URI}")
                    }
                }
            }
        }

        stage('Deploy') {
            steps {
                script {
                    runCmd("kubectl --context ${env.KUBE_CONTEXT} create namespace ${env.KUBE_NAMESPACE} --dry-run=client -o yaml | kubectl --context ${env.KUBE_CONTEXT} apply -f -")
                    if (isUnix()) {
                        sh "kubectl --context ${env.KUBE_CONTEXT} kustomize k8s/${env.DEPLOY_ENV} | sed 's|DOCKERHUB_USERNAME/simple-nginx-app|${params.DOCKERHUB_REPO}|g' | kubectl --context ${env.KUBE_CONTEXT} apply -f -"
                    } else {
                        powershell "kubectl --context ${env.KUBE_CONTEXT} kustomize k8s/${env.DEPLOY_ENV} | ForEach-Object { \$_ -replace 'DOCKERHUB_USERNAME/simple-nginx-app', '${params.DOCKERHUB_REPO}' } | kubectl --context ${env.KUBE_CONTEXT} apply -f -"
                    }
                    runCmd("kubectl --context ${env.KUBE_CONTEXT} rollout status deployment/${env.APP_NAME} -n ${env.KUBE_NAMESPACE} --timeout=120s")
                }
            }
        }
    }

    post {
        always {
            script {
                runCmd('docker logout', true)
            }
        }
        success {
            echo "Deployment succeeded: ${IMAGE_URI} to ${KUBE_CONTEXT}/${KUBE_NAMESPACE}"
        }
    }
}

def runCmd(String command, boolean returnStatus = false) {
    if (isUnix()) {
        return sh(script: command, returnStatus: returnStatus)
    }
    return powershell(script: command, returnStatus: returnStatus)
}
