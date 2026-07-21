#!/usr/bin/env bash
set -euo pipefail

source cloudfront.env

mkdir -p tmp

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

cat > tmp/distribution.json <<EOF
{
  "CallerReference": "${PROJECT}-$(date +%s)",
  "Comment": "${PROJECT} CloudFront distribution",
  "Enabled": true,

  "Origins": {
    "Quantity": 3,
    "Items": [

      {
        "Id": "frontend-s3",
        "DomainName": "${FRONTEND_BUCKET}.s3.${AWS_REGION}.amazonaws.com",
        "S3OriginConfig": {
          "OriginAccessIdentity": ""
        },
        "OriginAccessControlId": "${OAC_ID}"
      },

      {
        "Id": "django-alb",
        "DomainName": "${ALB_DOMAIN}",
        "CustomOriginConfig": {
          "HTTPPort": 80,
          "HTTPSPort": 443,
          "OriginProtocolPolicy": "http-only",
          "OriginSslProtocols": {
            "Quantity": 1,
            "Items": [
              "TLSv1.2"
            ]
          }
        }
      },

      {
        "Id": "storage-s3",
        "DomainName": "${STORAGE_BUCKET}.s3.${AWS_REGION}.amazonaws.com",
        "S3OriginConfig": {
          "OriginAccessIdentity": ""
        },
        "OriginAccessControlId": "${OAC_ID}"
      }

    ]
  },

  "DefaultCacheBehavior": {
    "TargetOriginId": "frontend-s3",
    "ViewerProtocolPolicy": "redirect-to-https",

    "AllowedMethods": {
      "Quantity": 2,
      "Items": [
        "GET",
        "HEAD"
      ],
      "CachedMethods": {
        "Quantity": 2,
        "Items": [
          "GET",
          "HEAD"
        ]
      }
    },

    "ForwardedValues": {
      "QueryString": false,
      "Cookies": {
        "Forward": "none"
      }
    },

    "Compress": true,

    "MinTTL": 0,
    "DefaultTTL": 86400,
    "MaxTTL": 31536000
  },


  "CacheBehaviors": {

    "Quantity": 4,

    "Items": [

      {
        "PathPattern": "/api/*",
        "TargetOriginId": "django-alb",
        "ViewerProtocolPolicy": "redirect-to-https",

        "AllowedMethods": {
          "Quantity": 7,
          "Items": [
            "GET",
            "HEAD",
            "OPTIONS",
            "PUT",
            "POST",
            "PATCH",
            "DELETE"
          ],
          "CachedMethods": {
            "Quantity": 2,
            "Items": [
              "GET",
              "HEAD"
            ]
          }
        },

        "ForwardedValues": {
          "QueryString": true,
          "Cookies": {
            "Forward": "all"
          },
          "Headers": {
            "Quantity": 1,
            "Items": [
              "Authorization"
            ]
          }
        },

        "Compress": true,

        "MinTTL": 0,
        "DefaultTTL": 86400,
        "MaxTTL": 31536000
      },


      {
        "PathPattern": "/admin/*",
        "TargetOriginId": "django-alb",
        "ViewerProtocolPolicy": "redirect-to-https",

        "AllowedMethods": {
          "Quantity": 7,
          "Items": [
            "GET",
            "HEAD",
            "OPTIONS",
            "PUT",
            "POST",
            "PATCH",
            "DELETE"
          ],
          "CachedMethods": {
            "Quantity": 2,
            "Items": [
              "GET",
              "HEAD"
            ]
          }
        },

        "ForwardedValues": {
          "QueryString": true,
          "Cookies": {
            "Forward": "all"
          }
        },

        "Compress": true,

        "MinTTL": 0,
        "DefaultTTL": 86400,
        "MaxTTL": 31536000
      },


      {
        "PathPattern": "/media/*",
        "TargetOriginId": "storage-s3",
        "ViewerProtocolPolicy": "redirect-to-https",

        "AllowedMethods": {
          "Quantity": 2,
          "Items": [
            "GET",
            "HEAD"
          ],
          "CachedMethods": {
            "Quantity": 2,
            "Items": [
              "GET",
              "HEAD"
            ]
          }
        },

        "ForwardedValues": {
          "QueryString": false,
          "Cookies": {
            "Forward": "none"
          }
        },

        "Compress": true,

        "MinTTL": 0,
        "DefaultTTL": 86400,
        "MaxTTL": 31536000
      },


      {
        "PathPattern": "/static/*",
        "TargetOriginId": "storage-s3",
        "ViewerProtocolPolicy": "redirect-to-https",

        "AllowedMethods": {
          "Quantity": 2,
          "Items": [
            "GET",
            "HEAD"
          ],
          "CachedMethods": {
            "Quantity": 2,
            "Items": [
              "GET",
              "HEAD"
            ]
          }
        },

        "ForwardedValues": {
          "QueryString": false,
          "Cookies": {
            "Forward": "none"
          }
        },

        "Compress": true,

        "MinTTL": 0,
        "DefaultTTL": 86400,
        "MaxTTL": 31536000
      }

    ]
  },


  "CustomErrorResponses": {
    "Quantity": 2,

    "Items": [

      {
        "ErrorCode": 403,
        "ResponsePagePath": "/index.html",
        "ResponseCode": "200",
        "ErrorCachingMinTTL": 0
      },

      {
        "ErrorCode": 404,
        "ResponsePagePath": "/index.html",
        "ResponseCode": "200",
        "ErrorCachingMinTTL": 0
      }

    ]
  },


  "Restrictions": {
    "GeoRestriction": {
      "RestrictionType": "none",
      "Quantity": 0
    }
  },


  "ViewerCertificate": {
    "CloudFrontDefaultCertificate": true
  }

}
EOF

echo "Generated tmp/distribution.json"
