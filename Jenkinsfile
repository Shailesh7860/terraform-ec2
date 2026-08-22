pipeline {
    agent any

    tools {
        // This must exactly match the Name you gave the tool in Step 2
        terraform 'terraform-1.5'
    }

    options {
        // Essential for infrastructure stability to prevent race conditions
        disableConcurrentBuilds()
        skipDefaultCheckout(true)
        timestamps()
    }

    environment {
        TF_IN_AUTOMATION   = 'true'
        TF_INPUT           = 'false'
        TF_DIR             = 'prod'
        REPOSITORY         = 'https://github.com/Shailesh7860/terraform-ec2.git'
        AWS_DEFAULT_REGION = 'ap-south-1'
        // Jenkins credentials ID for AWS (Configured in Manage Jenkins)
        AWS_CREDS_ID       = 'Tony'
        // Secure local storage directory on the master server outside the public workspace
        MASTER_STATE_STORE = "/var/jenkins_home/terraform_secure_store/${env.JOB_NAME}"
    }

    stages {
        stage('Prepare Directories') {
            steps {
                // Ensure the secure master state directory exists on the host machine
                sh "mkdir -p ${env.MASTER_STATE_STORE}"
            }
        }

        stage('Checkout') {
            steps {
                checkout([$class: 'GitSCM',
                    branches: [[name: '*/main']],
                    userRemoteConfigs: [[url: "${env.REPOSITORY}"]]
                ])
            }
        }

        stage('Restore Master State') {
            steps {
                dir(env.TF_DIR) {
                    script {
                        // Copy state files from the secure master backup directory into the workspace
                        if (sh(script: "ls ${env.MASTER_STATE_STORE}/terraform.tfstate", returnStatus: true) == 0) {
                            echo "Found existing state file on Master server. Restoring..."
                            sh "cp ${env.MASTER_STATE_STORE}/terraform.tfstate* ."
                        } else {
                            echo "No state file found on Master storage. Initialising empty infrastructure configuration."
                        }
                    }
                }
            }
        }

        stage('Terraform Init') {
            steps {
                dir(env.TF_DIR) {
                    withAWS(credentials: "${env.AWS_CREDS_ID}", region: "${env.AWS_DEFAULT_REGION}") {
                        sh 'terraform init -input=false'
                    }
                }
            }
        }

        stage('Choose Action') {
            steps {
                script {
                    env.TF_ACTION = input(
                        message: 'What would you like to do?',
                        ok: 'Continue',
                        parameters: [choice(
                            name: 'ACTION',
                            choices: ['Plan Only', 'Deploy', 'Destroy'],
                            description: 'Select a Terraform action'
                        )]
                    )
                }
            }
        }

        stage('Execute Action') {
            steps {
                dir(env.TF_DIR) {
                    withAWS(credentials: "${env.AWS_CREDS_ID}", region: "${env.AWS_DEFAULT_REGION}") {
                        script {
                            if (env.TF_ACTION == 'Plan Only') {
                                sh '''
                                    terraform plan -input=false -out=tfplan
                                    terraform show -no-color tfplan > terraform-plan.txt
                                '''
                            } 
                            else if (env.TF_ACTION == 'Deploy') {
                                sh '''
                                    terraform plan -input=false -out=tfplan
                                    terraform show -no-color tfplan > terraform-plan.txt
                                    terraform apply -input=false tfplan
                                '''
                            } 
                            else if (env.TF_ACTION == 'Destroy') {
                                input message: "CRITICAL: Confirm destruction of ${env.TF_DIR} infrastructure?", ok: "Destroy Everything"
                                sh 'terraform destroy -auto-approve'
                            }
                        }
                    }
                }
            }
        }
    }

    post {
        always {
            // Backup the newly updated state files back into the secure master directory
            dir(env.TF_DIR) {
                script {
                    if (fileExists('terraform.tfstate')) {
                        echo "Backing up local state files to secure master directory..."
                        sh "cp terraform.tfstate* ${env.MASTER_STATE_STORE}/"
                    }
                }
            }
            // Keep the text plans visible on the Jenkins UI interface dashboard
            archiveArtifacts artifacts: 'prod/tfplan,prod/terraform-plan.txt',
                allowEmptyArchive: true,
                fingerprint: true,
                onlyIfSuccessful: false
        }
    }
}