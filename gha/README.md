
GitHub Actions gets the temporary credentials from AWS STS using OIDC (OpenID Connect).

What happens in GitHub Actions
- A workflow runs in GitHub.
- GitHub issues a signed OIDC identity token for that workflow run.
- The action (usually aws-actions/configure-aws-credentials) sends that token to AWS STS.
- AWS checks the role trust policy.
- If the token matches the conditions (aud, sub, etc.), AWS returns temporary credentials.
- The action exports the followings for the rest of the workflow: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`


Conceptually
```yml
GitHub Workflow
       │
       ▼
OIDC Token
       │
       ▼
sts:AssumeRoleWithWebIdentity
       │
       ▼
github-actions-eks-deployer
       │
       ▼
Temporary AWS Credentials
```
```



In `~/.aws/config` add a role profile that uses the default profile as the source:
```sh

[profile gha-eks-deployer]
role_arn = arn:aws:iam::865274826587:role/github-actions-eks-deployer
source_profile = default
region = us-east-1
```

Verify:
```sh
aws sts get-caller-identity
# the default user


aws sts get-caller-identity --profile gha-eks-deployer

```


```sh
aws iam get-role \
  --role-name github-actions-eks-deployer \
  --query 'Role.AssumeRolePolicyDocument' \
  --output json

{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::865274826587:oidc-provider/token.actions.githubusercontent.com"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
                },
                "StringLike": {
                    "token.actions.githubusercontent.com:sub": "repo:/:ref:refs/heads/main"
                }
            }
        }
    ]
}
```


`Could not assume role with OIDC: Not authorized to perform sts:AssumeRoleWithWebIdentity`

```sh
aws iam list-open-id-connect-providers

{
    "OpenIDConnectProviderList": [
        {
            "Arn": "arn:aws:iam::865274826587:oidc-provider/token.actions.githubusercontent.com"
        }
    ]
}

aws iam get-role \
  --role-name github-actions-eks-deployer \
  --query 'Role.AssumeRolePolicyDocument' \
  --output json


{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::865274826587:oidc-provider/token.actions.githubusercontent.com"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
                },
                "StringLike": {
                    "token.actions.githubusercontent.com:sub": "repo:/:ref:refs/heads/main"
                }
            }
        }
    ]
}
```