# AWS Terraform infrastructure

The AWS infrastructure is separated into two independently stateful Terraform root modules:

```text
terraform/
├── network/
│   ├── VPC, public/private/database subnet tiers and NAT gateways
│   ├── RDS DB subnet group
│   ├── shared security group
│   ├── GitHub OIDC provider and image-publisher IAM role
│   └── application deployment IAM role and scoped policies
└── application/
    ├── EKS cluster and managed node group
    ├── ECR repository and lifecycle policy
    └── SSM Parameter Store application configuration
```

The exact VPC and subnet CIDR allocation is documented in
[`network/README.md`](network/README.md).

The application stack reads the network stack's outputs from S3 remote state. It does not own or modify the VPC. EKS-specific roles remain managed by the EKS module because their lifecycle is tied to the cluster.

## Cost warning

EKS, EC2 worker nodes, and NAT gateways incur charges. The development example uses one NAT gateway. Before applying, confirm the project is on the paid plan and check its spend limit in **AWS Settings > Billing**.

## Prerequisites

- Terraform 1.10 or later.
- AWS CLI 2.32 or later.
- An authenticated `default` profile.
- An existing S3 state bucket in `ap-southeast-2`.

The project state bucket is:

```text
llm-inference-platform-tfstate-248471876315-ap-southeast-2
```

It has S3 Versioning, server-side encryption, bucket-owner-enforced object
ownership, and all four S3 Block Public Access settings enabled. The backend
uses native S3 lockfiles through `use_lockfile = true`.

## 1. Deploy the network stack

```bash
cd infrastructure/terraform/network
cp terraform.tfvars.example terraform.tfvars
cp backend.hcl.example backend.hcl

terraform init -backend-config=backend.hcl
terraform fmt -check -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

The network state key defaults to:

```text
llm-inference-platform/dev/network/terraform.tfstate
```

## 2. Deploy the application stack

After the network stack creates the deployment role, configure a local role profile:

```bash
DEPLOYER_ROLE_ARN=$(terraform -chdir=infrastructure/terraform/network output -raw application_deployer_role_arn)

aws configure set role_arn "$DEPLOYER_ROLE_ARN" --profile application-deployer
aws configure set source_profile default --profile application-deployer
aws configure set region ap-southeast-2 --profile application-deployer

aws sts get-caller-identity --profile application-deployer
```

This profile assumes a one-hour role session using the short-term credentials from `aws login`; it does not create access keys or an IAM user.

```bash
cd ../application
cp terraform.tfvars.example terraform.tfvars
cp backend.hcl.example backend.hcl

# Set network_state_bucket to the bucket used by the network stack.
# Replace the example trusted EKS API CIDR.
terraform init -backend-config=backend.hcl
terraform fmt -check -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

The deployment role can create, modify and delete project-scoped EKS, SSM and RDS resources, plus the IAM, EC2 and CloudWatch Logs resources those services require. It can delete only application-scoped resources; it cannot modify the network stack or administer unrelated AWS services.

The application state is kept under a different key:

```text
llm-inference-platform/dev/application/terraform.tfstate
```

Configure Kubernetes access:

```bash
aws eks update-kubeconfig \
  --region ap-southeast-2 \
  --name llm-inference-platform-dev \
  --profile application-deployer
```

## Connect GitHub Actions to ECR

The network stack owns the narrowly scoped GitHub role. Retrieve its ARN:

```bash
cd infrastructure/terraform/network
terraform output -raw github_actions_image_role_arn
```

The new AWS experience currently blocks IAM OIDC provider creation through its
managed service control policy, so `enable_github_oidc_publisher` defaults to
`false` and the output is `null`. If the project later enables this capability,
set the variable to `true`, create or supply the provider, and configure the
GitHub Actions repository secret `AWS_GITHUB_ACTIONS_ROLE_ARN` with the output.
The trust policy then accepts only `main` in
`Abhishekvarun2010/llm-inference-platform`, and the role can only push to this
project's ECR repository.

The separate image workflow publishes one immutable tag per commit:

```text
<project-id>.dkr.ecr.ap-southeast-2.amazonaws.com/llm-inference-platform:sha-<git-sha>
```

Promoting the resulting digest into a Helm environment values file remains a separate GitOps release operation.

## Destruction order

Destroy the application stack before the network stack so EKS no longer references network resources:

```bash
terraform -chdir=infrastructure/terraform/application destroy
terraform -chdir=infrastructure/terraform/network destroy
```

