#!/bin/bash
set -e
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root or with sudo."
    exit 1
fi
echo "Downloading Containerd..."
curl -LO https://github.com/containerd/containerd/releases/download/v1.7.25/containerd-1.7.25-linux-amd64.tar.gz
echo "extracting..."
tar Cxzvf /usr/local /home/ubuntu/containerd-1.7.25-linux-amd64.tar.gz
echo "Running Containerd Service.."
curl https://raw.githubusercontent.com/containerd/containerd/main/containerd.service > /home/ubuntu/containerd.service
mv /home/ubuntu/containerd.service /usr/lib/systemd/system/
systemctl daemon-reload
systemctl enable --now containerd
echo "Containerd Status..."
systemctl is-active containerd
echo "Istalling runc Status..."
curl -LO https://github.com/opencontainers/runc/releases/download/v1.2.5/runc.amd64
install -m 755 runc.amd64 /usr/local/sbin/runc
echo "done"
sudo mkdir /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
echo "restarting containerd service.."
service containerd restart
# echo "installing cni"
# curl -LO https://github.com/containernetworking/plugins/releases/download/v1.6.2/cni-plugins-linux-amd64-v1.6.2.tgz
# mkdir -p /opt/cni/bin
# tar Cxzvf /opt/cni/bin /home/ubuntu/cni-plugins-linux-amd64-v1.6.2.tgz
# echo "done"
echo "Checking IP forwarding..."
if grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    echo "IP forwarding is already enabled in /etc/sysctl.conf."
else
    echo "IP forwarding not enabled, enabling"
    echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf > /dev/null
    echo "IP forwarding has been added to /etc/sysctl.conf."
    sysctl -p
    echo "verifying changes"
    if [ "$(sysctl -n net.ipv4.ip_forward)" -eq 1 ]; then
    echo "IP forwarding is enabled successfully."
    else
        echo "Failed to enable IP forwarding."
        exit 1
    fi
fi
echo "Installing kubeadm"
apt-get update
apt-get install -y apt-transport-https ca-certificates curl gpg
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable --now kubelet

