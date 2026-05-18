
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

