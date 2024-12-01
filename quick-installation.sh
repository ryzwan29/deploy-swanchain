#!/bin/bash

# Update sistem
sudo apt update && sudo apt upgrade -y

# Install Go
GO_VERSION="1.21.7"
wget -c https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz -O - | sudo tar -xz -C /usr/local
echo "export PATH=\$PATH:/usr/local/go/bin" >> ~/.bashrc
source ~/.bashrc

# Verifikasi Go
go version

# Tambahkan repositori Kubernetes
sudo apt update && sudo apt install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Install kubeadm, kubectl, kubelet
sudo apt update && sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Verifikasi instalasi
kubeadm version && kubectl version --client && kubelet --version

# Install Docker
sudo apt update && sudo apt install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker

# Install cri-dockerd
sudo apt update && sudo apt install -y git golang-go
git clone https://github.com/Mirantis/cri-dockerd.git
cd cri-dockerd
mkdir bin
go build -o bin/cri-dockerd
sudo mv bin/cri-dockerd /usr/local/bin/
sudo cp -a packaging/systemd/* /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable cri-docker
sudo systemctl start cri-docker

# Buat direktori untuk registry
sudo mkdir /docker_repo
sudo chmod -R 777 /docker_repo

# Jalankan container registry
sudo docker run --detach \
  --restart=always \
  --name registry \
  --volume /docker_repo:/docker_repo \
  --env REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY=/docker_repo \
  --publish 5000:5000 \
  registry:2

# Tambahkan konfigurasi ke /etc/docker/daemon.json
read -p "Insert your server ip: " SERVER_IP
echo '{
  "insecure-registries": ["$SERVER_IP:5000"]
}' | sudo tee /etc/docker/daemon.json

# Restart Docker
sudo systemctl restart docker

# Install Calico
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.1/manifests/tigera-operator.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.1/manifests/custom-resources.yaml

# Hapus taint pada control-plane node (jika menggunakan single-node cluster)
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
kubectl taint nodes --all node-role.kubernetes.io/master-

# Verifikasi instalasi Calico
kubectl get pods -n calico-system

# Install driver NVIDIA (pastikan repositori driver sudah tersedia)
sudo apt update && sudo apt install -y nvidia-driver-470

# Install NVIDIA Kubernetes Plugin
kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.13.0/nvidia-device-plugin.yml

# Verifikasi instalasi
kubectl get pods -n kube-system

# Install ingress-nginx
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.7.1/deploy/static/provider/cloud/deploy.yaml

# Verifikasi instalasi
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx

# Clone repository
git clone https://github.com/swanchain/go-computing-provider.git
cd go-computing-provider
git checkout releases

# Build untuk mainnet
make clean && make mainnet
make install

# Inisialisasi repo
computing-provider init --multi-address=/ip4/<YOUR_PUBLIC_IP>/tcp/<YOUR_PORT> --node-name=<YOUR_NODE_NAME>

# Edit konfigurasi (sesuaikan sesuai kebutuhan Anda)
vi ~/.swan/computing/config.toml

# Jalankan service
export CP_PATH=~/.swan/computing
nohup computing-provider run >> cp.log 2>&1 &

