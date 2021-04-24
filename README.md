# terraformer
Codespace template for convenient terraforming

## Process

* SSH key for repo, add to machine
* Inject AWS settings
* Copy assets from from staging buckets:


## Rancher Air Gap

https://rancher.com/docs/rancher/v2.5/en/installation/other-installation-methods/air-gap/

Followed instructions here to prepare infrastructure:

https://rancher.com/docs/rancher/v2.5/en/installation/other-installation-methods/air-gap/prepare-nodes/

### Asset retrieval

Using instructions at https://rancher.com/docs/rancher/v2.5/en/installation/other-installation-methods/air-gap/populate-private-registry/

Using release https://github.com/rancher/rancher/releases/tag/v2.5.7

From bastion: 
```
export R_VER=v2.5.7
export H_VER=v3.5.3
export CM_VERSION=v1.1.1
wget https://github.com/rancher/rancher/releases/download/${R_VER}/rancher-images.txt
wget https://github.com/rancher/rancher/releases/download/${R_VER}/rancher-load-images.sh
wget https://github.com/rancher/rancher/releases/download/${R_VER}/rancher-save-images.sh
wget https://get.helm.sh/helm-${H_VER}-linux-amd64.tar.gz
tar xvf helm-${H_VER}-linux-amd64.tar.gz linux-amd64/helm
sudo mv linux-amd64/helm /usr/local/bin/helm
rm -fr linux-amd64

helm repo add jetstack https://charts.jetstack.io
helm repo update

helm fetch jetstack/cert-manager --version ${CM_VERSION}
helm template ./cert-manager-${CM_VERSION}.tgz | grep -oP '(?<=image: ").*(?=")' >> ./rancher-images.txt
sort -u rancher-images.txt -o rancher-images.txt

chmod +x rancher-save-images.sh
sudo ./rancher-save-images.sh --image-list ./rancher-images.txt
chmod +x rancher-load-images.sh
sudo ./rancher-load-images.sh --image-list ./rancher-images.txt --registry registry.rancher:5000
```

## RKE2

Following instructions at: https://docs.rke2.io/install/airgap/#install-rke2

From node with CLI and bucket privileges
```
export RKE2_VER=v1.20.4%2Brke2r1
/var/lib/rancher/rke2/agent/images/
wget https://github.com/rancher/rke2/releases/download/${RKE2_VER}/rke2-images.linux-amd64.tar.gz
wget https://github.com/rancher/rke2/releases/download/${RKE2_VER}/rke2.linux-amd64
chmod +x rke2.linux-amd64 
mkdir stage 
mv rke2-images.linux-amd64.tar.gz rke2.linux-amd64 stage/

cat << EOF > stage/registry.yaml
mirrors:
  docker.io:
    endpoint:
      - "https://registry.rancher"
configs:
  "registry.rancher":
    tls:
      insecure_skip_verify: true
EOF

aws s3 mb s3://rancher-node-staging
aws s3 sync stage s3://rancher-node-staging
```

From registry node
```
export RKE2_VER=v1.20.4%2Brke2r1
wget https://github.com/rancher/rke2/releases/download/${RKE2_VER}/rke2-images.linux-amd64.tar.gz
gunzip -c rke2-images.linux-amd64.tar.gz | sudo docker load

for IMAGE in $(sudo docker images | awk '{print $1,$2}'|sed 's^ ^:^' | grep -v REPO); do sudo docker tag $IMAGE registry.rancher/$IMAGE; sudo docker push registry.rancher/$IMAGE; done

```

Server Install
```
aws s3 sync s3://rancher-node-staging stage
sudo mv stage/rke2.linux-amd64 /usr/local/bin/rke2
sudo cp stage/registry.yaml /etc/rancher/rke2/registries.yaml
chmod +x /usr/local/bin/rke2
sudo /usr/local/bin/rke2 server
```

Agent Install
```
aws s3 sync s3://rancher-node-staging stage
sudo mv stage/rke2.linux-amd64 /usr/local/bin/rke2
sudo mkdir -p /etc/rancher/rke2/
sudo cp stage/registry.yaml /etc/rancher/rke2/registries.yaml
chmod +x /usr/local/bin/rke2
sudo /usr/local/bin/rke2 agent -s https://10.0.10.102:9345 -t K106ad5e9342ab7086ae549e2fca6de24adae17481bf65ba95b401d0e83a61059a9::server:a0d0b600b2c895f7fb9a81ed88ce317f
```

## RKE2 Bastion Only

Following instructions at: https://docs.rke2.io/install/airgap/#install-rke2

From node with CLI and bucket privileges
```
export RKE2_VER=v1.20.4%2Brke2r1
/var/lib/rancher/rke2/agent/images/
wget https://github.com/rancher/rke2/releases/download/${RKE2_VER}/rke2-images.linux-amd64.tar.zst
wget https://github.com/rancher/rke2/releases/download/${RKE2_VER}/rke2.linux-amd64
mkdir stage 
curl -sfL https://get.rke2.io --output stage/install.sh
mv rke2-images.linux-amd64.tar.zst rke2.linux-amd64 stage/
aws s3 mb s3://rancher-node-staging
# Gimme some argo
docker save argoproj/argocli:v2.12.10 argoproj/workflow-controller:v2.12.10 argoproj/argoexec:v2.12.10 | gzip > stage/argo.tar.gz
aws s3 cp --re stage s3://entservicesops-dataloading-warpgate/rke2/
aws s3 sync stage s3://rancher-node-staging
```

From registry node
```
export RKE2_VER=v1.20.4%2Brke2r1
wget https://github.com/rancher/rke2/releases/download/${RKE2_VER}/rke2-images.linux-amd64.tar.gz
gunzip -c rke2-images.linux-amd64.tar.gz | sudo docker load

for IMAGE in $(sudo docker images | awk '{print $1,$2}'|sed 's^ ^:^' | grep -v REPO); do sudo docker tag $IMAGE registry.rancher/$IMAGE; sudo docker push registry.rancher/$IMAGE; done
```

Server Install
```
aws s3 sync s3://rancher-node-staging stage
sudo mv stage/rke2.linux-amd64 /usr/local/bin/rke2
sudo cp stage/registry.yaml /etc/rancher/rke2/registries.yaml
chmod +x /usr/local/bin/rke2
sudo /usr/local/bin/rke2 server
```

Agent Install
```
aws s3 sync s3://rancher-node-staging stage
sudo mv stage/rke2.linux-amd64 /usr/local/bin/rke2
sudo mkdir -p /etc/rancher/rke2/
sudo cp stage/registry.yaml /etc/rancher/rke2/registries.yaml
chmod +x /usr/local/bin/rke2
sudo /usr/local/bin/rke2 agent -s https://10.0.10.102:9345 -t K106ad5e9342ab7086ae549e2fca6de24adae17481bf65ba95b401d0e83a61059a9::server:a0d0b600b2c895f7fb9a81ed88ce317f
```