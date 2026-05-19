
```sh

docker compose pull

docker compose run --rm --entrypoint sh tf

# once inside the container:
cd deploy
terraform init
```

NOTE:
don't forget to add `.terraform` to `.gitignore`
`.terraform/` → cache + downloaded providers/modules

## Network

```sh
aws ec2 describe-nat-gateways \
  --query 'NatGateways[*].[NatGatewayId,State,SubnetId]'

# [
#     [
#         "nat-08b7a07e90057c4cc",
#         "available",
#         "subnet-0bdaa97dada053bde"
#     ]
# ]

aws ec2 describe-route-tables \
  --filters "Name=association.subnet-id,Values=<private-subnet-id>"

# 0.0.0.0/0 -> nat-xxxx

aws ec2 describe-route-tables \
  --filters "Name=association.subnet-id,Values=<public-subnet-id>"

# 0.0.0.0/0 -> igw-xxxx
```

## SSM

```sh
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb"

sudo dpkg -i session-manager-plugin.deb

# verify
session-manager-plugin
# The Session Manager plugin was installed successfully. Use the AWS CLI to start a session.

# check whether SSM sees any managed instances
# you may need to wait a minute if you see []
aws ssm describe-instance-information \
  --query 'InstanceInformationList[*].[InstanceId,PingStatus,AgentVersion,PlatformName]'

# [
#     [
#         "i-0d922773895d62843",
#         "Online",
#         "3.3.4108.0",
#         "Amazon Linux"
#     ]
# ]

# verify the instance profile actually attached
SSM_BOX_ID=i-0d922773895d62843
aws ec2 describe-instances \
  --instance-ids $SSM_BOX_ID \
  --query 'Reservations[0].Instances[0].IamInstanceProfile'

# {
#     "Arn": "arn:aws:iam::802838070254:instance-profile/ec2-ssm-profile",
#     "Id": "AIPA3V3HAYPXB53FA7G7H"
# }

aws ssm start-session --target $SSM_BOX_ID

## RDS 
SECRET_ID="arn:aws:secretsmanager:us-east-1:802838070254:secret:rds!db-8762ee7c-03e6-46b8-a67c-0d089f6422d3-4XDFfg"

SECRET_JSON=$(aws secretsmanager get-secret-value \
  --secret-id ${SECRET_ID} \
  --query SecretString \
  --output text)
echo $SECRET_JSON

# {"username":"appuser","password":"J$?$L8-F_vF$uU)EJsuha8wE3|*8"}

# sudo dnf install -y jq nmap-ncat postgresql17

export PGHOST="pixel-monitor-default-postgres.cf7ttjzo2qnh.us-east-1.rds.amazonaws.com"
export PGPORT=5432
export PGUSER=$(echo "$SECRET_JSON" | jq -r .username)
export PGPASSWORD=$(echo "$SECRET_JSON" | jq -r .password)
export PGDATABASE=pixeldb

psql

# verify:
# select current_user, current_database();
# select version();
# select now();
# create table if not exists healthcheck_test(id int);
# \dt
```

## ECR
Login
```sh
aws ecr get-login-password --region $AWS_REGION | \
docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
```
Build, tag, push:
```sh
aws ecr create-repository --repository-name $APP_NAME --region $AWS_REGION

docker build -t $APP_NAME .
# docker run --rm -it --entrypoint sh $APP_NAME

docker tag $APP_NAME:latest $IMAGE_URI

docker push $IMAGE_URI
# docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$APP_NAME:v1

```


## ECS

Make sure give inbound access to ecs in rds sg.

### run exec commands
We could run `python manage.py migrate` or `python manage.py collectstatic --noinput`:
```sh
aws ecs list-tasks \
  --cluster $CLUSTER_NAME \
  --service-name $SERVICE_NAME \
  --region $AWS_REGION

TASK_ID=24631f434ae2493c8dbcbd8917440d0b

aws ecs execute-command \
  --cluster $CLUSTER_NAME \
  --task $TASK_ID \
  --container api \
  --interactive \
  --command "/bin/sh" \
  --region $AWS_REGION

```

S3

```sh
aws ecs list-task-definitions --region us-east-1

TASK_DEF="arn:aws:ecs:us-east-1:802838070254:task-definition/pixel-monitor-default-task:7"

aws ecs describe-task-definition \
  --task-definition $TASK_DEF \
  --region us-east-1

# cat > s3-policy.json <<EOF
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Sid": "S3StaticAccess",
#       "Effect": "Allow",
#       "Action": [
#         "s3:GetObject",
#         "s3:PutObject",
#         "s3:DeleteObject",
#         "s3:ListBucket"
#       ],
#       "Resource": [
#         "arn:aws:s3:::pixel-monitor-storage-bucket",
#         "arn:aws:s3:::pixel-monitor-storage-bucket/*"
#       ]
#     }
#   ]
# }
# EOF

# aws iam put-role-policy \
#   --role-name ecs-task-role \
#   --policy-name pixel-monitor-s3-policy \
#   --policy-document file://s3-policy.json

```

S3 public policy
```sh
cat > public-static-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadStatic",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::pixel-monitor-storage-bucket/static/*"
    }
  ]
}
EOF


aws s3api put-bucket-policy \
  --bucket pixel-monitor-storage-bucket \
  --policy file://public-static-policy.json

# verify
aws s3api get-bucket-policy \
  --bucket pixel-monitor-storage-bucket

# test public access
curl -I https://pixel-monitor-storage-bucket.s3.amazonaws.com/static/admin/css/base.css
```



## Frontend

```sh

aws s3 mb s3://pixel-monitor-frontend

# enable static website hosting
aws s3 website s3://pixel-monitor-frontend \
  --index-document index.html \
  --error-document index.html

# make bucket public
cat > frontend-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicRead",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::pixel-monitor-frontend/*"
    }
  ]
}
EOF

aws s3api put-bucket-policy \
  --bucket pixel-monitor-frontend \
  --policy file://frontend-policy.json
```

Now 
```sh
npm run build

# upload build
aws s3 sync dist/ s3://pixel-monitor-frontend

```

open website:
```sh

http://pixel-monitor-frontend.s3-website-us-east-1.amazonaws.com

```

## checklist
Having the `ALB_DNS` we need to set it in 
```sh
# 1) ./frontend/.env
VITE_API_URL=http://{ALB_DNS}/api

# next, build & push to S3.

# 2) allowed_hosts as ENV variable to ECS/django
allowed_hosts=ALB_DNS
```

Run migration in ECS TASK:
```sh
# python manage.py makemigrations
python manage.py migrate

python manage.py createsuperuser

```
