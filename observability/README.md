# EFK pipeline

## scale
Just in case you need to scale up:

```sh
# get NODEGROUP_NAME
eksctl get nodegroup --cluster $CLUSTER_NAME --region $AWS_REGION

NG_NAME=ng-c6d806c4
eksctl scale nodegroup \
  --cluster $CLUSTER_NAME \
  --region $AWS_REGION \
  --name $NG_NAME \
  --nodes 3 \
  --nodes-min 1 \
  --nodes-max 3

aws eks describe-nodegroup \
  --cluster-name $CLUSTER_NAME \
  --nodegroup-name $NG_NAME
```

## Monitoring
Add monitoring stack:
```sh
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace

# verify
kubectl get pods -n monitoring

kubectl port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090 -n monitoring --address 0.0.0.0


# access grafana
kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring --address 0.0.0.0
# Grafana service port 80
# Forwarded to EC2 port 3000
# Bound to all interfaces (0.0.0.0)
# http://EC2_PUBLIC_IP:3000 (⚠️don't forget to give inbound access to port 3000)

# grafana cred
# username: admin
kubectl get secret monitoring-grafana \
  -n monitoring \
  -o jsonpath="{.data.admin-password}" | base64 --decode



```

create failures intentionally
→ observe them
→ learn their signatures


Prometheus expressions:
```md
kube_pod_container_status_restarts_total{namespace="default"}

```



```md
ubuntu:observability$ kgp -w
NAME                            READY   STATUS    RESTARTS        AGE
cpu-hog-774f8d9994-wp2gt        1/1     Running   0               18m
cpu-load-sim-789976ff57-rp7w8   1/1     Running   0               2s
memory-hog-7877f975ff-96dbr     1/1     Running   2 (3m53s ago)   24m
memory-hog-7877f975ff-96dbr     0/1     OOMKilled   2 (10m ago)     30m
memory-hog-7877f975ff-96dbr     1/1     Running     3 (1s ago)      30m
cpu-hog-b59f96668-gwhxg         0/1     Pending     0               0s
cpu-hog-b59f96668-gwhxg         0/1     Pending     0               0s
cpu-hog-b59f96668-gwhxg         0/1     ContainerCreating   0               0s
cpu-hog-b59f96668-gwhxg         1/1     Running             0               2s
cpu-hog-774f8d9994-wp2gt        1/1     Terminating         0               34m
cpu-hog-774f8d9994-wp2gt        1/1     Terminating         0               34m
cpu-hog-774f8d9994-wp2gt        0/1     Error               0               34m
cpu-hog-774f8d9994-wp2gt        0/1     Error               0               34m
cpu-hog-774f8d9994-wp2gt        0/1     Error               0               34m
^Cubuntu:observability$ kgp -w
NAME                            READY   STATUS    RESTARTS        AGE
cpu-hog-b59f96668-gwhxg         1/1     Running   0               45s
cpu-load-sim-789976ff57-rp7w8   1/1     Running   0               16m
memory-hog-7877f975ff-96dbr     1/1     Running   3 (9m51s ago)   40m
memory-hog-7877f975ff-96dbr     0/1     OOMKilled   3 (10m ago)     41m
memory-hog-7877f975ff-96dbr     1/1     Running     4 (2s ago)      41m
crashy-bcdb8749-btscw           0/1     Pending     0               0s
crashy-bcdb8749-btscw           0/1     Pending     0               0s
crashy-bcdb8749-btscw           0/1     ContainerCreating   0               1s
crashy-bcdb8749-btscw           0/1     Error               0               2s
crashy-bcdb8749-btscw           0/1     Error               1 (1s ago)      3s
crashy-bcdb8749-btscw           0/1     CrashLoopBackOff    1 (2s ago)      4s
crashy-bcdb8749-btscw           0/1     Error               2 (15s ago)     17s
crashy-bcdb8749-btscw           0/1     CrashLoopBackOff    2 (13s ago)     30s
crashy-bcdb8749-btscw           0/1     Error               3 (28s ago)     45s
crashy-bcdb8749-btscw           0/1     CrashLoopBackOff    3 (14s ago)     59s
crashy-bcdb8749-btscw           0/1     Error               4 (50s ago)     95s
crashy-bcdb8749-btscw           0/1     CrashLoopBackOff    4 (13s ago)     108s
crashy-bcdb8749-btscw           0/1     Error               5 (93s ago)     3m8s
crashy-bcdb8749-btscw           0/1     CrashLoopBackOff    5 (13s ago)     3m21s
crashy-bcdb8749-btscw           0/1     Error               6 (2m50s ago)   5m58s
crashy-bcdb8749-btscw           0/1     CrashLoopBackOff    6 (14s ago)     6m12s
memory-hog-7877f975ff-96dbr     0/1     OOMKilled           4 (10m ago)     51m
memory-hog-7877f975ff-96dbr     1/1     Running             5 (2s ago)      51m
crashy-bcdb8749-btscw           0/1     Error               7 (5m9s ago)    11m
crashy-bcdb8749-btscw           0/1     CrashLoopBackOff    7 (10s ago)     11m
crashy-bcdb8749-btscw           0/1     Error               8 (5m7s ago)    16m
crashy-bcdb8749-btscw           0/1     CrashLoopBackOff    8 (14s ago)     16m
memory-hog-7877f975ff-96dbr     0/1     OOMKilled           5 (10m ago)     61m
memory-hog-7877f975ff-96dbr     1/1     Running             6 (1s ago)      61m
crashy-bcdb8749-btscw           0/1     Error               9 (5m3s ago)    21m
crashy-bcdb8749-btscw           0/1     CrashLoopBackOff    9 (10s ago)     21m
crashy-bcdb8749-btscw           1/1     Running             10 (5m7s ago)   26m
crashy-bcdb8749-btscw           0/1     Error               10 (5m8s ago)   26m
crashy-bcdb8749-btscw           0/1     CrashLoopBackOff    10 (15s ago)    26m
memory-hog-7877f975ff-96dbr     0/1     OOMKilled           6 (10m ago)     71m
memory-hog-7877f975ff-96dbr     1/1     Running             7 (1s ago)      71m
unready-app-6b894b86bd-4cxv2    0/1     Pending             0               0s
unready-app-6b894b86bd-4cxv2    0/1     Pending             0               0s
unready-app-6b894b86bd-4cxv2    0/1     ContainerCreating   0               0s
unready-app-6b894b86bd-4cxv2    0/1     Running             0               1s
crashy-bcdb8749-btscw           0/1     Error               11 (5m7s ago)   31m
crashy-bcdb8749-btscw           0/1     CrashLoopBackOff    11 (15s ago)    31m
crashy-bcdb8749-btscw           0/1     Error               12 (5m7s ago)   36m
crashy-bcdb8749-btscw           0/1     CrashLoopBackOff    12 (13s ago)    36m
memory-hog-7877f975ff-96dbr     0/1     OOMKilled           7 (10m ago)     82m
memory-hog-7877f975ff-96dbr     1/1     Running             8 (1s ago)      82m
crashy-bcdb8749-btscw           0/1     Error               13 (5m7s ago)   41m
liveness-fail-776f7b6bc7-vrf2x   0/1     Pending             0               0s
liveness-fail-776f7b6bc7-vrf2x   0/1     Pending             0               1s
liveness-fail-776f7b6bc7-vrf2x   0/1     ContainerCreating   0               1s
liveness-fail-776f7b6bc7-vrf2x   1/1     Running             0               2s
crashy-bcdb8749-btscw            0/1     CrashLoopBackOff    13 (11s ago)    41m
liveness-fail-776f7b6bc7-vrf2x   1/1     Running             1 (0s ago)      46s
liveness-fail-776f7b6bc7-vrf2x   1/1     Running             2 (1s ago)      92s
liveness-fail-776f7b6bc7-vrf2x   1/1     Running             3 (1s ago)      2m17s
liveness-fail-776f7b6bc7-vrf2x   1/1     Running             4 (1s ago)      3m2s
liveness-fail-776f7b6bc7-vrf2x   1/1     Running             5 (1s ago)      3m47s
liveness-fail-776f7b6bc7-vrf2x   0/1     CrashLoopBackOff    5 (0s ago)      4m31s
crashy-bcdb8749-btscw            0/1     Error               14 (5m7s ago)   46m
crashy-bcdb8749-btscw            0/1     CrashLoopBackOff    14 (14s ago)    47m

```

## Logging

```sh
eksctl create iamserviceaccount \
    --name ebs-csi-controller-sa \
    --namespace kube-system \
    --cluster $CLUSTER_NAME \
    --role-name AmazonEKS_EBS_CSI_DriverRole \
    --role-only \
    --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
    --approve

# get the ROLE ARN
ROLE_ARN=$(aws iam get-role --role-name AmazonEKS_EBS_CSI_DriverRole --query 'Role.Arn' --output text)
```
In case you get this error:
> Error: unable to create iamserviceaccount(s) without IAM OIDC provider enabled
```sh
eksctl utils associate-iam-oidc-provider \
  --region $AWS_REGION \
  --cluster $CLUSTER_NAME \
  --approve
```


Next, we need a driver that can create the EBS driver for us:
```sh
eksctl create addon --cluster $CLUSTER_NAME \
  --name aws-ebs-csi-driver \
  --version latest \
  --service-account-role-arn $ROLE_ARN \
  --force

# verify
kubectl get pods -n kube-system | grep ebs
```


storage class
```sh
kubectl get storageclass

kubectl apply -f gp3-sc.yaml

# NAME   PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
# gp2    kubernetes.io/aws-ebs   Delete          WaitForFirstConsumer   false                  63m
# gp3    ebs.csi.aws.com         Delete          WaitForFirstConsumer   true                   20s

```

```sh
helm repo add elastic https://helm.elastic.co
helm repo update

kubectl create namespace logging

# helm install <release-name> <chart>
helm install elasticsearch elastic/elasticsearch \
  --set replicas=1 \
  --set volumeClaimTemplate.storageClassName=gp3 \
  --set persistence.labels.enabled=true \
  -n logging
# just in case you get this:
#  ⚠️ 0/3 nodes are available: 3 Insufficient memory. no new claims to deallocate,

helm uninstall elasticsearch -n logging
kubectl delete pvc -n logging --all

# Then upgrade with smaller memory settings:
# This is much more realistic for a small EKS lab cluster.
helm upgrade --install elasticsearch elastic/elasticsearch \
  -n logging \
  --set replicas=1 \
  --set volumeClaimTemplate.storageClassName=gp3 \
  --set volumeClaimTemplate.resources.requests.storage=5Gi \
  --set persistence.labels.enabled=true \
  --set resources.requests.memory=512Mi \
  --set resources.requests.cpu=250m \
  --set resources.limits.memory=1Gi \
  --set esJavaOpts="-Xms512m -Xmx512m"

# watch (may take between 3 to 12 min)
kubectl get pods -n logging -w
```



```sh
# kibana
# helm install kibana --set service.type=LoadBalancer elastic/kibana -n logging
helm uninstall kibana -n logging

# helm install kibana elastic/kibana \
#   -n logging \
#   --set service.type=LoadBalancer \
#   --set resources.requests.cpu=100m \
#   --set resources.requests.memory=256Mi \
#   --set resources.limits.memory=512Mi

helm install kibana elastic/kibana \
  -n logging \
  --set service.type=ClusterIP \
  --set resources.requests.cpu=100m \
  --set resources.requests.memory=256Mi \
  --set resources.limits.memory=512Mi

# wait (takes about ~10min; we set limited resources above)
kgp -n logging  -w

# user: elastic
# password (you need it to have in `fluent bit values` 👇)
kubectl get secrets --namespace=logging elasticsearch-master-credentials \
  -ojsonpath='{.data.password}' | base64 -d

kubectl get svc -n logging

kubectl port-forward svc/kibana-kibana 5601:5601 -n logging --address 0.0.0.0

# http://localhost:5601

```
in Kibana UI
- add integrations
- discover > create data view
- - name: logstash
- - index patter: logstash-*
- - ts field: @timestamp
- - save data viwe to kibana

### FluentBit

```sh
helm repo add fluent https://fluent.github.io/helm-charts

# moidfy the password in `HTTP_Passwd` with the one above 👆
helm upgrade --install fluent-bit fluent/fluent-bit \
  -f fb-values.yml \
  -n logging

kubectl get pods -n logging -w

# verify password is correct
# no `HTTP status=401`
kubectl logs -n logging daemonset/fluent-bit --tail=20
```

What Fluent Bit is doing is basically:
```yml
kubectl logs -> Fluent Bit -> Elasticsearch -> Kibana
```

So Kibana becomes:
- centralized log aggregation
- searchable
- filterable
- persistent
- multi-pod aware

instead of manually doing `kubectl logs <pod>` every time.

### t3.large

```sh
# ~ 3min
helm upgrade --install elasticsearch elastic/elasticsearch \
  -n logging \
  --set replicas=1 \
  --set volumeClaimTemplate.storageClassName=gp3 \
  --set volumeClaimTemplate.resources.requests.storage=10Gi \
  --set persistence.labels.enabled=true \
  --set resources.requests.cpu=500m \
  --set resources.requests.memory=2Gi \
  --set resources.limits.memory=3Gi \
  --set esJavaOpts="-Xms1g -Xmx1g"

helm upgrade --install kibana elastic/kibana \
  -n logging \
  --set service.type=ClusterIP \
  --set resources.requests.cpu=250m \
  --set resources.requests.memory=512Mi \
  --set resources.limits.memory=1Gi

```

### test logging

Deploy a tiny pod that continuously prints logs.
```sh
kubectl create deployment log-generator \
  --image=busybox \
  -- sh -c 'i=0; while true; do echo "$(date) INFO test log $i"; i=$((i+1)); sleep 2; done'

# verify
kubectl logs -f deployment/log-generator
# Fri May 22 ... INFO test log 1
# Fri May 22 ... INFO test log 2
```

Then test Elasticsearch directly:
```sh

kubectl get secrets --namespace=logging elasticsearch-master-credentials \
-ojsonpath='{.data.password}' | base64 -d

curl -k -u elastic:<PASSWORD> \
https://localhost:9200/logstash-*/_search?pretty \
-H 'Content-Type: application/json' \
-d '{
  "size": 20,
  "query": {
    "match": {
      "log": "INFO test log"
    }
  }
}'

```

### ingress for observability

```sh
kubectl apply -f monitoring-ingress.yaml
kubectl apply -f logging-ingress.yaml

observability$ k get ing -n monitoring
# NAME                 CLASS   HOSTS                                         ADDRESS                                                             PORTS   AGE
# monitoring-ingress   alb     grafana.local,prometheus.local,alerts.local   k8s-observatory-89d9d29f14-1427828137.us-east-1.elb.amazonaws.com   80      4m

observability$ k get ing -n logging
# NAME              CLASS   HOSTS          ADDRESS                                                             PORTS   AGE
# logging-ingress   alb     kibana.local   k8s-observatory-89d9d29f14-1427828137.us-east-1.elb.amazonaws.com   80      2m30s

```

## DDX

```sh
kubectl get configmap -n logging fluent-bit -o yaml

```

ES
```sh
kubectl port-forward svc/elasticsearch-master 9200:9200 -n logging

# curl -k -u elastic:<PASSWORD> \
curl -k -u elastic:ntWZPhDsz1UUjWKA \
https://localhost:9200/logstash-*/_search?pretty \
-H 'Content-Type: application/json' \
-d '{
  "size": 10,
  "query": {
    "match_all": {}
  }
}'

curl -k -u elastic:<password> \
https://localhost:9200/logstash-*/_search?pretty \
-H 'Content-Type: application/json' \
-d '{
  "size": 20,
  "query": {
    "match": {
      "kubernetes.namespace_name": "default"
    }
  }
}'

curl -k -u elastic:ntWZPhDsz1UUjWKA \
https://localhost:9200/logstash-*/_search?pretty \
-H 'Content-Type: application/json' \
-d '{
  "size": 20,
  "sort": [
    {
      "@timestamp": {
        "order": "desc"
      }
    }
  ]
}'

curl -k -u elastic:ieAuaxJF9HAS7WyC \
https://localhost:9200/_cat/indices?v

```

## Tracing
