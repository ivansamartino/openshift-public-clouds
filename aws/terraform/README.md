# Terraform setup

## Pre-requisites

* AWS CLI [link](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
* Terraform CLI [link](https://www.terraform.io/downloads.html)

Configure aws CLI. It is suggested that you create a user:

```bash
aws iam create-group --group-name mygroup
aws iam create-user --user-name myuser
aws iam add-user-to-group --group-name mygroup --user-name myuser
# Navigate to AWS console and attach a Policy to the group with enough permissions 
# Navigate to AWS console -> IAM -> Users -> Security credentials -> Create access key
# Download the .csv file. You will get the Acces key ID and the Secret access key

# Now let's configure the CLI profile
aws configure
# Input Access Key ID, Secret, Desired region and format (I.e: Region: eu-central-1, format: json)
```

## Setup SSH key

Generate a SSH Key-pair

```bash
ssh-keygen -t rsa
# Select a path. (I.e: /home/user/.ssh/aws/id_rsa)
# Leave the passphrase empty for the key
```
Import SSH Key-pair into AWS

```bash
aws ec2 import-key-pair --key-name <some-name> --public-key-material fileb://<your_id_rsa.pub>
# Example
aws ec2 import-key-pair --key-name mykey --publi-key-material fileb:///home/user/.ssh/aws/id_rsa.pub
```

## Terraform

Edit the file [terraform.tfvars](terraform.tfvars) to input data relevant to your environment.

Execute the following commands to setup the infrastructure: 


```bash
# Initialize the project. Downloads required plugins (aws) 
terraform init
# Plan: Be able to understand what will be generated
terraform plan -out demo.tfplan
# Apply the plan
terraform apply demo.tfplan
# Destroy when you are done
terraform destroy
```

