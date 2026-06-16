
```sh
source .env

eksctl create cluster \
  --name $CLUSTER_NAME \
  --region $AWS_REGION \
  --nodes 1 \
  --node-type t3.small \
  --managed \
  --spot

# ❌ DELETE the cluster ❌
# eksctl delete cluster --name $CLUSTER_NAME --region $AWS_REGION

aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME

kubectl get nodes

# --name=standard-workers and argument spot cannot be used at the same time
# this `#` inbetween will break (e.g., instance m5.large)
eksctl create nodegroup \
  --cluster pixel-monitor \
  --region us-east-1 \
  #--name standard-workers \
  --node-type t3.small \
  --nodes 1 \
  --managed \
  -- spot

```
## RDS

```sh
export VPC_ID=$(aws eks describe-cluster \
  --name $CLUSTER_NAME \
  --region $AWS_REGION \
  --query "cluster.resourcesVpcConfig.vpcId" \
  --output text)

echo $VPC_ID

export DB_SG_ID=$(aws ec2 create-security-group \
  --group-name ${APP_NAME}-rds-sg \
  --description "RDS access for EKS app" \
  --vpc-id $VPC_ID \
  --region $AWS_REGION \
  --query "GroupId" \
  --output text)

echo $DB_SG_ID

export SUBNET_IDS=$(aws ec2 describe-subnets \
  --subnet-ids $(aws eks describe-cluster \
    --name $CLUSTER_NAME \
    --region $AWS_REGION \
    --query "cluster.resourcesVpcConfig.subnetIds" \
    --output text) \
  --region $AWS_REGION \
  --query "Subnets[?MapPublicIpOnLaunch==\`false\`].SubnetId" \
  --output text)

printf "private EKS subnets => %s\n" "$SUBNET_IDS"

SUBNET_IDS=$(echo "$SUBNET_IDS" | tr '\t' ' ')
printf '%q\n' "$SUBNET_IDS"

# Key fix: in zsh, use ${=SUBNET_IDS} when you need a space-separated variable expanded into multiple CLI args.

DB_SUBNET_GROUP_NAME=pixel-monitor
aws rds create-db-subnet-group \
  --db-subnet-group-name $DB_SUBNET_GROUP_NAME \
  --db-subnet-group-description "RDS subnet group for EKS app" \
  --subnet-ids ${=SUBNET_IDS} \
  --region $AWS_REGION

# create DB instance in that subnet group (takes ~5min)
aws rds create-db-instance \
  --db-instance-identifier "$DB_INSTANCE_ID" \
  --db-instance-class "$DB_INSTANCE_CLASS" \
  --engine postgres \
  --engine-version 17.9 \
  --allocated-storage 20 \
  --storage-type gp3 \
  --master-username "$DB_USER" \
  --master-user-password "$DB_PASSWORD" \
  --db-name "$DB_NAME" \
  --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" \
  --vpc-security-group-ids "$DB_SG_ID" \
  --no-publicly-accessible \
  --backup-retention-period 1 \
  --region "$AWS_REGION"

# wait until it becomes available
aws rds wait db-instance-available \
  --db-instance-identifier $DB_INSTANCE_ID \
  --region $AWS_REGION

# get the endpoint
export DB_HOST=$(aws rds describe-db-instances \
  --db-instance-identifier $DB_INSTANCE_ID \
  --region $AWS_REGION \
  --query "DBInstances[0].Endpoint.Address" \
  --output text)

# save this to `db.env`
echo $DB_HOST
# save it to db.env
# pixel-monitor-db.cf7ttjzo2qnh.us-east-1.rds.amazonaws.com

# get RDS endpoint:
aws rds describe-db-instances \
  --query 'DBInstances[*].Endpoint.Address'

export EKS_CLUSTER_SG=$(aws eks describe-cluster \
  --name $CLUSTER_NAME \
  --region $AWS_REGION \
  --query "cluster.resourcesVpcConfig.clusterSecurityGroupId" \
  --output text)
echo $EKS_CLUSTER_SG

# authorize inbound Postgres traffic from the node's security group:
## adds the inbound rule on the DB security group 👇 (The node is the client here; RDS is the server.)
aws ec2 authorize-security-group-ingress \
  --group-id $DB_SG_ID \
  --protocol tcp \
  --port 5432 \
  --source-group $EKS_CLUSTER_SG \
  --region $AWS_REGION

```

### verify info
```sh
aws rds describe-db-instances \
  --db-instance-identifier pixel-monitor-db \
  --query 'DBInstances[0].{
    Endpoint:Endpoint.Address,
    Port:Endpoint.Port,
    Status:DBInstanceStatus,
    Engine:Engine,
    EngineVersion:EngineVersion,
    VpcId:DBSubnetGroup.VpcId,
    MultiAZ:MultiAZ,
    PubliclyAccessible:PubliclyAccessible,
    AvailabilityZone:AvailabilityZone,
    Subnets:DBSubnetGroup.Subnets[*].SubnetIdentifier,
    SecurityGroups:VpcSecurityGroups[*].VpcSecurityGroupId
  }' \
  --output yaml
```

### config 
```sh
kubectl create configmap db-config \
  --from-env-file=db.env \
  --dry-run=client -o yaml > db-configmap.yaml

kubectl create configmap s3-config \
  --from-env-file=s3.env \
  --dry-run=client -o yaml > s3-configmap.yaml


kubectl apply -f db-configmap.yaml
kubectl apply -f s3-configmap.yaml
```
### secret

Easy way. For development.
```sh
kubectl create secret generic app-db-secret \
  --from-literal=DB_PASS="$DB_PASSWORD"

kubectl create secret generic django-secret-key \
  --from-literal=DJANGO_SECRET_KEY="$DJANGO_SECRET_KEY"

```

We'll use ESO for prod. (see bellow 👇)


## manifest
Kubernetes Services route traffic based on label matching, not names. So this must always match:
> Deployment → template.metadata.labels
> Service → spec.selector

### S3 access: pod ident

```sh
kubectl apply -f pod-ident-sa.yml

# addon
# This add-on enables Pod Identity, 
# which is AWS's newer alternative to IAM Roles for Service Accounts (IRSA).
# It lets the Kubernetes pods securely access AWS services (like S3, DynamoDB, etc.) 
# without hardcoding credentials.
aws eks create-addon \
  --cluster-name $CLUSTER_NAME \
  --addon-name eks-pod-identity-agent \
  --region $AWS_REGION

# ⚙️ What gets installed
# When we run the above command, AWS deploys a component (as a DaemonSet) that:
# - Runs on every node
# - Intercepts credential requests from pods
# - Provides temporary IAM credentials to pods
kubectl get daemonset -n kube-system

| Feature                       | Pod Identity  | IRSA          |
| ----------------------------- | ------------  | ------------- |
| Setup complexity              | Easier        | More manual   |
| Uses OIDC provider            | ❌ No         | ✅ Yes       |
| AWS recommended going forward | ✅ Yes        | ⚠️ Legacy-ish|

# With EKS Pod Identity, the flow is:

# 1) Pod → ServiceAccount
# 2) ServiceAccount → IAM Role
# 3) IAM Role → Policies (permissions)


```

iam policy + iam role & association

```sh
# requires S3_BUCKET to be set accordingly.
envsubst < s3-policy.json.tpl > s3-policy.json

aws iam create-policy \
  --policy-name $IAM_POLICY_NAME \
  --policy-document file://s3-policy.json

# ⚠️ The IAM role must trust Pod Identity, not EC2 or OIDC.
# {
#   "Principal": {
#     "Service": "pods.eks.amazonaws.com"
#   }
# }
aws iam create-role \
  --role-name $IAM_ROLE_NAME \
  --assume-role-policy-document file://pod-ident-trust.json

# attach the policy to the IAM role
aws iam attach-role-policy \
  --role-name $IAM_ROLE_NAME \
  --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/$IAM_POLICY_NAME


aws eks list-pod-identity-associations \
  --cluster-name $CLUSTER_NAME \
  --region $AWS_REGION

aws eks create-pod-identity-association \
  --cluster-name $CLUSTER_NAME \
  --namespace $CLUSTER_NS \
  --service-account pod-ident-sa \
  --role-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:role/${IAM_ROLE_NAME}" \
  --region $AWS_REGION

# check again:
aws eks list-pod-identity-associations --cluster-name $CLUSTER_NAME --region $AWS_REGION

association_id=a-z5jsgfv08qfy3nzgt
aws eks describe-pod-identity-association \
  --cluster-name $CLUSTER_NAME \
  --association-id $association_id \
  --region $AWS_REGION
```

verify

```sh
kubectl apply -f aws-test.yaml
kubectl exec -it aws-test -- bash

# bash-5.2# aws sts get-caller-identity
# {
#     "UserId": "AROA3V3HAYPXARQB3YZZ3:eks-pixel-moni-aws-test-a5b9452e-0846-485e-9574-5c8e73550bfc",
#     "Account": "802838070254",
#     "Arn": "arn:aws:sts::802838070254:assumed-role/PixelMonitorS3Role/eks-pixel-moni-aws-test-a5b9452e-0846-485e-9574-5c8e73550bfc"
# }
# bash-5.2# 
# bash-5.2# aws s3 ls

# aws: [ERROR]: An error occurred (AccessDenied) when calling the ListBuckets operation: User: arn:aws:sts::802838070254:assumed-role/PixelMonitorS3Role/eks-pixel-moni-aws-test-a5b9452e-0846-485e-9574-5c8e73550bfc is not authorized to perform: s3:ListAllMyBuckets because no identity-based policy allows the s3:ListAllMyBuckets action
# bash-5.2# 
```

## ESO

```sh
aws secretsmanager create-secret \
  --name prod/app/db \
  --secret-string '{"DB_PASS":"TopSecretDBPassword!"}'

# aws secretsmanager update-secret \
#   --secret-id prod/app/db \
#   --secret-string '{"DB_PASS":"#2TopSecretDBPassword!"}'


aws secretsmanager create-secret \
  --name prod/app/django \
  --secret-string '{"DJANGO_SECRET_KEY":"SuperSecretKey<>"}'

```

```sh
eksctl utils associate-iam-oidc-provider \
  --cluster $CLUSTER_NAME \
  --region $AWS_REGION \
  --approve


cat > eso-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": "arn:aws:secretsmanager:$AWS_REGION:$AWS_ACCOUNT_ID:secret:prod/app/*"
    }
  ]
}
EOF

# create the policy
aws iam create-policy \
  --policy-name ESOSecretsManagerReadPolicy \
  --policy-document file://eso-policy.json


# irsa 
eksctl create iamserviceaccount \
  --cluster $CLUSTER_NAME \
  --region $AWS_REGION \
  --namespace external-secrets \
  --name external-secrets \
  --attach-policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/ESOSecretsManagerReadPolicy \
  --approve \
  --override-existing-serviceaccounts

# install ESO usin the SA
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

helm upgrade --install external-secrets external-secrets/external-secrets \
  -n external-secrets \
  --create-namespace \
  --set serviceAccount.create=false \
  --set serviceAccount.name=external-secrets

# verify IRSA annotation
kubectl -n external-secrets get sa external-secrets -o yaml

# annotations:
#   eks.amazonaws.com/role-arn: arn:aws:iam::YOUR_ACCOUNT_ID:role/...

k apply -f eso/css.yml

k apply -f eso/ext-sec-db.yml
k apply -f eso/ext-sec-django.yml

```

```sh
k apply -f k8s.yml
```

## S3 (frontend)
### static files

```sh
kubectl exec -it pixel-monitor-5995f6cd57-vx65r -- python manage.py collectstatic --noinput

# curl -i http://18.207.123.206:32341/static/admin/css/base.css

curl -i https://pixel-monitor-s3-bucket.s3.amazonaws.com/static/admin/css/base.css

```

You may need to attack bucket policy
```md
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowPublicReadStatic",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::pixel-monitor-s3-bucket/static/*"
    }
  ]
}
```

and also, unblock public access.

## GHA

Required env. variables:
```sh
export AWS_ACCOUNT_ID=802838070254
export AWS_REGION=us-east-1

export GH_USER=gesatessa
export REPO_NAME=pixel-monitor
export ROLE_NAME=github-actions-eks-deployer
export ECR_REPO_NAME=pixel-monitor

```

Create GitHub OIDC Provider in AWS:
```sh
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 \
  --client-id-list sts.amazonaws.com

# verify:
aws iam list-open-id-connect-providers
```

Generate trust policy file:
```sh

cd eks/gha

cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:${GH_USER}/${REPO_NAME}:ref:refs/heads/main"
        }
      }
    }
  ]
}
EOF

# create role
aws iam create-role \
  --role-name ${ROLE_NAME} \
  --assume-role-policy-document file://trust-policy.json

```

If the `trust-policy.json` was corrupt, for example the env variables like `REPO_NAME` were not set, you can re-create the trust-policy.json & update the assume role policy:
```sh
aws iam update-assume-role-policy \
  --role-name ${ROLE_NAME} \
  --policy-document file://trust-policy.json

```

### 3. attach permissions

#### ECR access

```sh
# generate ECR policy file
cat > ecr-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ECRAuth",
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken"
      ],
      "Resource": "*"
    },
    {
      "Sid": "PushPullImage",
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:CompleteLayerUpload",
        "ecr:InitiateLayerUpload",
        "ecr:PutImage",
        "ecr:UploadLayerPart",
        "ecr:BatchGetImage"
      ],
      "Resource": "arn:aws:ecr:${AWS_REGION}:${AWS_ACCOUNT_ID}:repository/${ECR_REPO_NAME}"
    }
  ]
}
EOF

# create policy
aws iam create-policy \
  --policy-name GitHubActionsECRPushPolicy \
  --policy-document file://ecr-policy.json

# attach policy
aws iam attach-role-policy \
  --role-name ${ROLE_NAME} \
  --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/GitHubActionsECRPushPolicy

```

#### EKS access policy
We need permission to:
- describe cluster
- generate auth token

```sh
cat > eks-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "EKSDescribe",
      "Effect": "Allow",
      "Action": [
        "eks:DescribeCluster"
      ],
      "Resource": "*"
    }
  ]
}
EOF

# create policy
aws iam create-policy \
  --policy-name GitHubActionsEKSDescribePolicy \
  --policy-document file://eks-policy.json

# attach policy
aws iam attach-role-policy \
  --role-name ${ROLE_NAME} \
  --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/GitHubActionsEKSDescribePolicy

```

### 4. allow IAM role into K8s

EKS has:

AWS IAM auth
Kubernetes RBAC

The IAM role must map into Kubernetes users/groups.

```sh
# determine auth mode:
aws eks describe-cluster \
  --name $CLUSTER_NAME \
  --query "cluster.accessConfig.authenticationMode"

# CONFIG_MAP (most older clusters)
# API_AND_CONFIG_MAP
# API
```

`API_AND_CONFIG_MAP` means our cluster supports the newer EKS Access Entries API and the legacy `aws-auth` ConfigMap.

```sh
# create access entry
aws eks create-access-entry \
  --cluster-name ${CLUSTER_NAME} \
  --principal-arn arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME} \
  --type STANDARD

# verify
aws eks list-access-entries --cluster-name ${CLUSTER_NAME}

# 👀 arn:aws:iam::802838070254:role/github-actions-eks-deployer

```

👉 This IAM role is allowed to authenticate to Kubernetes.

Without this:
- ✅ IAM auth works
- ❌ Kubernetes rejects requests

#### attach K8s permissions

An access entry by itself does NOT grant permissions. The role still needs either:
- An EKS access policy association (recommended), or
- Kubernetes groups mapped to RBAC roles.

```sh
# ⚠️ (only for initial setup/testing)
# This way GHA effectively becomes cluster-admin.
# Equivalent to old `system:masters`
aws eks associate-access-policy \
  --cluster-name ${CLUSTER_NAME} \
  --principal-arn arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME} \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster

# verify
aws eks list-associated-access-policies \
  --cluster-name ${CLUSTER_NAME} \
  --principal-arn arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME}

```

### GHA extra

| Context                                | Syntax             |
| -------------------------------------- | ------------------ |
| shell (`run:`)                         | `$VAR` or `${VAR}` |
| GitHub YAML (`with:` / `env:` / `if:`) | `${{ env.VAR }}`   |


### DDX
```sh
# check the image
docker run --rm -it --entrypoint /bin/sh <your-image>
```

```sh

kubectl get deploy pixel-monitor -o yaml | grep image:
# image: 802838070254.dkr.ecr.us-east-1.amazonaws.com/pixel-monitor:9262d4a13b9529b2fe6b3683d0bb11de05481595
```

🔍 Check rollout history
```sh

kubectl rollout history deployment/pixel-monitor
```


```sh
kubectl run test-pixel \
  --image=802838070254.dkr.ecr.us-east-1.amazonaws.com/pixel-monitor:44f3d72ddbd17ef600eda23d22a4dc5a9fac52a1 \
  --restart=Never \
  --port=8000 \
  --env="ALLOWED_HOSTS=*" \
  --env="DEBUG=True"

kubectl exec -it test-pixel -- /bin/sh

apt update
apt install curl
curl -v http://localhost:8000/healthz

# option B: -------
kubectl port-forward pod/test-pixel 8000:8000

# now in another terminal
curl -i http://localhost:8000/healthz
```


```sh
kubectl get svc
# NAME                    TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
# pixel-monitor-service   NodePort    10.100.179.49   <none>        80:30241/TCP   70m

kubectl run curl-test \
  --image=curlimages/curl:8.5.0 \
  --rm -it --restart=Never -- \
  curl http://pixel-monitor-service/healthz/
```

## Helm

```sh
helm create pixel-monitor
# Chart.yaml
# values.yaml
# templates/

# create the resources in templates/ & then update the values.yaml accordingly.
```

From inside the pixel-monitor chart folder, run `helm template pixel-monitor .`
This shows what Helm will generate. Check that it looks like our old YAML.

```sh
# install with helm
# kubectl delete -f ../k8s.yml
helm upgrade --install pixel-monitor .

# verify
helm list
kubectl get pods
kubectl get svc

# make it a LB
kubectl patch svc pixel-monitor-service -p '{"spec": {"type": "LoadBalancer"}}'
```

Future image updates:
```sh
NEW_IMG_TAG=44f3d72ddbd17ef600eda23d22a4dc5a9fac52a1

helm upgrade --install pixel-monitor . \
  --set image.tag=$NEW_IMG_TAG

```

That is the main win. No more editing raw YAML every deployment.

## django migration
We are using `initContainer` approach for now. 

```sh
Deployment
 + initContainer(migrate)
 + app container
```

This is already operating at a much more mature level than:
- manually SSHing servers
- manually running migrations
- hand-editing containers

This is now proper declarative infrastructure behavior.

However, with replicas >1, multiple pods may all try migrations simultaneously during rollout.

Django migrations are usually safe, but eventually we may want:
- a migration Job
- or Helm hooks
- or ArgoCD sync waves

For now though, our `initContainer` approach is solid.

```sh
# psycopg.errors.ConnectionTimeout: connection timeout expired
# django.db.utils.OperationalError: connection timeout expired

# > A timeout means the TCP connection never completed.

# 1: check what Django is actually using:
kubectl get configmap db-config -o yaml

# 2:
kubectl logs pixel-monitor-66c55bcb79-kns2l -c run-migrations

kubectl logs pixel-monitor-66c55bcb79-kns2l -c run-migrations --previous

kubectl set env deployment/pixel-monitor --list

## DNS resolution failure
kubectl run dns-test --image=busybox:1.36 --rm -it --restart=Never -- sh

### If DNS fails, that's the issue: nslookup <rds-endpoint>
### If the RDS endpoint resolves to a private IP => DNS is working.

## network connectivity test
kubectl run netshoot \
  --image=nicolaka/netshoot \
  --rm -it --restart=Never -- bash

### nc -vz <rds-endpoint> 5432
### If it hangs and times out, security groups or routing are blocking traffic. (port 5432 failed: Operation timed out)
### expected: Connection to <rds-endpoint> (192.168.89.11) 5432 port [tcp/postgresql] succeeded!

```

## HPA

```sh
# kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# # wait
# kubectl rollout status deployment metrics-server -n kube-system

# verify
# ESK should have created it by default
# successfully created addon: metrics-server
kubectl get deployment metrics-server -n kube-system
# NAME             READY   UP-TO-DATE   AVAILABLE   AGE
# metrics-server   2/2     2            2           28m

# these should work (otherwise HPA will fail also)
kubectl top nodes
kubectl top pods
```

we need to have request limits
```yml
resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "250m"
    memory: "256Mi"
```

create HPA
```sh
k apply -f pixel-monitor-hpa.yml

k get hpa
# NAME                REFERENCE                  TARGETS       MINPODS   MAXPODS   REPLICAS   AGE
# pixel-monitor-hpa   Deployment/pixel-monitor   cpu: 1%/70%   2         10        2          41s
```

load test
```sh
hey -n 10000 -c 100 http://$H_/api/movies/

# watch
kubectl get hpa -w

kubectl top pods

```


## DDX cluster

```sh
aws eks describe-cluster --name $CLUSTER_NAME

aws eks list-nodegroups --cluster-name $CLUSTER_NAME
{
    "nodegroups": [
        "ng-a11e812c"
    ]
}

NG_NAME=ng-a11e812c

aws eks describe-nodegroup \
  --cluster-name $CLUSTER_NAME \
  --nodegroup-name $NG_NAME
```



```sh
kubectl get events -A
```