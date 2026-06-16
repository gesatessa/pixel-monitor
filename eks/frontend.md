## collectstatic

```sh
aws s3api put-public-access-block \
  --bucket pixel-monitor-s3-bucket \
  --public-access-block-configuration \
  BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false

cat > /tmp/static-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadStatic",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::pixel-monitor-s3-bucket/static/*"
    }
  ]
}
EOF

aws s3api put-bucket-policy \
  --bucket pixel-monitor-s3-bucket \
  --policy file:///tmp/static-policy.json


# verify:
curl -I https://pixel-monitor-s3-bucket.s3.amazonaws.com/static/admin/css/base.css
## HTTP/1.1 200 OK
```
###

```sh
H_=http://3.238.123.121:32105

curl -X POST \
  "$H_/api/user/create/" \ 
  -H "Content-Type: application/json" \
  -d @payloads/kimi.json

# get ADMIN_TOKEN
curl -X 'POST' \
  "${H_}/api/user/token/" \
  -H 'Content-Type: application/json' \
  -d @payloads/kimi.json

curl -X POST \
  "$H_/api/movies/" \
  -H "Authorization: Token $ADMIN_TOKEN" \
  -F "title=Whiplash" \
  -F "description=Jazz drummer pushed to the edge" \
  -F "release_year=2014" \
  -F "poster=@./posters/whiplash.png"

curl -X POST \
  "$H_/api/movies/" \
  -H "Authorization: Token $ADMIN_TOKEN" \
  -F "title=Marriage Story" \
  -F "description=An emotional drama that follows a couple navigating love, separation, and the challenges of divorce." \
  -F "release_year=2019" \
  -F "poster=@./posters/mar_story.png"
```

## frontend
```sh
# make bucket
aws s3 mb s3://pixel-monitor-frontend

```

Enable static website hosting:
```sh
aws s3 website s3://pixel-monitor-frontend \
  --index-document index.html \
  --error-document index.html
```
- `aws s3 website` → Enables/configures the bucket's website endpoint.
- `s3://pixel-monitor-frontend` → The bucket being configured.
- `--index-document index.html` → When someone visits the root URL (/), S3 serves index.html.
- `--error-document index.html` → When a page isn't found (404) or another website error occurs, S3 also serves index.html


Next: uncheck "block public access" for the bocket.

Make the bucket public
```sh
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

Next,

```sh
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash

# source ~/.bashrc
source ~/.zshrc

nvm install --lts

node -v
npm -v

```
```sh
cd frontend

# if you need:
npm install

# ⚠️ MAKE SURE to set this properly in the .env
# VITE_API_URL=http://{ALB_DNS}/api
npm run build

# upload build
aws s3 sync dist/ s3://pixel-monitor-frontend
# upload: dist/assets/index-C6onRlkd.css to s3://pixel-monitor-frontend/assets/index-C6onRlkd.css
# upload: dist/favicon.svg to s3://pixel-monitor-frontend/favicon.svg
# upload: dist/icons.svg to s3://pixel-monitor-frontend/icons.svg   
# upload: dist/assets/index-6SB22cl7.js to s3://pixel-monitor-frontend/assets/index-6SB22cl7.js
# upload: dist/index.html to s3://pixel-monitor-frontend/index.html 

rm -rf dist/
```

The frontend link:
> http://pixel-monitor-frontend.s3-website-us-east-1.amazonaws.com