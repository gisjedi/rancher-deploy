#!/usr/bin/sh

yum install -y docker
systemctl enable docker
systemctl start docker

mkdir certs
openssl req -newkey rsa:4096 -nodes -sha256 -keyout certs/domain.key -x509 -days 365 -out certs/domain.crt -subj '/CN=registry.rancher' -extensions san -config <( echo '[req]'; echo 'distinguished_name=req'; echo '[san]'; echo 'subjectAltName=DNS:registry.rancher')
docker run -d -p 443:443 -v $(pwd)/certs:/certs --restart=always --name registry \
-e REGISTRY_HTTP_ADDR=0.0.0.0:443 \
-e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt \
-e REGISTRY_HTTP_TLS_KEY=/certs/domain.key \
registry:2 

IMAGES="argoproj/argocli:v2.12.10
argoproj/argoexec:v2.12.10
argoproj/workflow-controller:v2.12.10"
for IMAGE in $IMAGES; do docker pull $IMAGE; docker tag $IMAGE registry.rancher/$IMAGE; docker push registry.rancher/$IMAGE; done

