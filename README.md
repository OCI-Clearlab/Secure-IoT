# Scenario

This demo shows how to deploy IoT workloads in different environments (Edge and Cloud) in a secure manner.

## Assumptions

1. You have access to kubernetes clusters both in edge and cloud.
2. Kubernetes configuration file for cloud is located `~/.kube/cloud`
3. Kubernetes configuration file for edge is located `~/.kube/edge`
4. All deployments will be from edge device.
5. This repo was cloned and you navigated to this repo in your edge device.

## Software Stack

This section explains the tools that are used in the project.
- Edge
    - Kubernetes
        - Metallb
        - NFS
        - Python App (Publishes the sensor data to the cloud)
        - Flux
- Cloud (AKS)
    - Mosquitto broker
    - Telegraf
    - Grafana
    - InfluxDB
    - Flux

## Hardware

Edge Side:

- 4 Raspberry PI
- 1 dumb switch
- 2 Arduino Nano 33
- 2 DHT11 sensors

Server Side:

- Azure Kubernetes Services


## Kubernetes

We use Kubernetes for orchestration. Below code blocks will be run the edge devices.

ALL NODES
The code blocks that are listed will be run on all nodes.

```bash
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
```

```bash
sudo modprobe overlay
sudo modprobe br_netfilter
```

```bash
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
```

```bash
sudo sysctl --system
sudo apt-get update && sudo apt-get install -y containerd
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
sudo systemctl restart containerd
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
```

```bash
sudo apt-get update && sudo apt-get install -y apt-transport-https curl

curl -s [https://packages.cloud.google.com/apt/doc/apt-key.gpg](https://packages.cloud.google.com/apt/doc/apt-key.gpg) | sudo apt-key add -

cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb [https://apt.kubernetes.io/](https://apt.kubernetes.io/) kubernetes-xenial main
EOF

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

ON MASTER
The code block below will be run on master node only. After running kubeadm command, the token and IP that are needed for next step will be printed to the screen.

```bash
sudo kubeadm init --pod-network-cidr 10.244.0.0/16

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubectl version
kubectl apply -f https://github.com/coreos/flannel/raw/master/Documentation/kube-flannel.yml
kubectl get pods -n kube-system
```

ON NODES

Please use the command generated as output of kubeadm command on worker nodes. Syntax looks like as below.

```bash
sudo kubeadm join --token <token> <IP>:6443
```

## Setting Up NFS
Since kubernetes on edge side is not managed, we need to configure it manually. Below steps will give to the kubernetes cluster ability to provision volume claims dynamically.
### On Master Node

1. Install packages required to create NSF 
    
    ```bash
    sudo apt-get update
    sudo apt-get install  nfs-kernel-server -y
    ```
    
2. Create directory for NFS
    
    ```bash
    sudo mkdir -p /mnt/nfs
    ```
    
3. Find the group name using `groups` command ** JJP- need more context here so the user knows what you need them to do. Show an example of running the command. **
4. Change folder access to mnt. Reset owner to account being used instead of root.
    
    ```bash
    sudo chown -R clearlab:users /mnt/nfs
    sudo find /mnt/nfs/ -type d -exec chmod 755 {} \;
    sudo find /mnt/nfs/ -type d -exec chmod 644 {} \;
    ```
    
5. Find group id and user is using `id clearlab` and note gid and uid.
6. Edit the export file, add ip-range that will be able to access this drive. This file is a map of IP addresses to the filesystems.
    
    ```bash
    sudo nano /etc/exports
    ```
    
7. Add the following to the file. We are not setting the allowed network (*) but are requiring that only user with id=1000 and group=100 can access. For more information, visit [http://manpages.ubuntu.com/manpages/focal/man5/exports.5.html](http://manpages.ubuntu.com/manpages/focal/man5/exports.5.html)
    
    ```bash
    /mnt/nfs *(rw,root_squash,subtree_check,anonuid=1000,anongid=100)
    ```
    
8. Update the table using `sudo exportfs -ra`
9. Find your IP `hostname -I` or `ifconfig`

#### Mount the disk at startup

1. Get all mounting points available for cluster. (note that /dev/sdx is the one we are interested in)
    
    ```bash
    sudo fdisk -l
    ```
    
2. Create a unique identifier for your SSD ( or USB stick)
    
    Ex. Output: /dev/sda1: UUID="5AEB-8BFD" TYPE="exfat" PARTUUID="f154165f-01"
    
    ```bash
    sudo blkid /dev/sda1
    ```
    
3. Create mount point in fstab. Open fstab in nano and add line (replace UUID with UUID found in above):
    
    ```bash
    sudo nano /etc/fstab
    ```
    
4. Add this to the end of this file. Make sure you updated UUID and mounting point for your setup.
    
    ```bash
    UUID="5AEB-8BFD" /mnt/nfs auto nosuid,nodev,nofail,noatime 0 0
    ```
    
5. Enable and start the NSF server service and rpcbind.
    
    ```bash
    sudo systemctl enable rpcbind.service
    sudo systemctl enable nfs-server.service
    sudo systemctl start rpcbind.service
    sudo systemctl start nfs-server.service
    ```
    
6. Create test file on the NFS to verify all works properly.
    
    ```bash
    echo "hello , howdy??" >> /mnt/nfs/nfs_test
    ```
    
7. Verify that the file exists in the proper location.

### On Worker Nodes (one at a time)

1. Install NFS tools
    
    ```bash
    sudo apt-get install nfs-common -y
    ```
    
2. Add following to /etc/fstab in your worker nodes. Make sure you updated IP and mounting point. For more info use `man fstab` command in your terminal.
    
    ```bash
    192.168.4.101:/mnt/nfs /mnt nfs defaults 0 0
    ```
    
3. Test functionality by mounting the NFS location
    
    ```bash
    sudo mount 192.168.4.101:/mnt/nfs /mnt
    ```
    

Then check if you can see the file you created in above steps. `cat /mnt/nfs_test`
    
    For more information about external provisioner, visit  [https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner)


## Installing Flux
We use Flux for continuous and progressive delivery solutions. 

This step will be performed in your master node.

```bash
curl -s https://fluxcd.io/install.sh | sudo bash
```

### Adding bash completion

add `. <(flux completion bash)` to end of your bashrc the run `source ~/.bashrc`

### Check Flux installation

Run following command to verify Flux

`flux check --pre`

### Adding SSH key to your Git Repo

If you haven't created ssh key in your master node.

`ssh-keygen -t rsa`

Copy and paster your public key to your git account.

`cat ~/.ssh/id_rsa.pub`

### Bootstrapping with Flux

** JJP- This part can be tricky (I remember doing it). Let's give a bit more context here and walk the user through what they are doing **

1. Create a new project in your preferred repository.
2. Use following command to bootstrap your clusters;
(Below is for GitHub, if you use GitLab or other git enterprise solutions, check out the following link https://fluxcd.io/docs/get-started/.)

#### Edge Side 

```bash
flux bootstrap github \
  --context=<your context for edge> \
  --repository=<the repo you created in step one>  \
  --branch=<my-branch> \
  --owner=< your GitHub username> \
  --personal \
  --path=clusters/edge
```

#### Cloud Side 

```bash
flux bootstrap github \
  --context=<your context for cloud> \
  --repository=<the repo you created in step one>  \
  --branch=<my-branch> \
  --owner=< your GitHub username> \
  --personal \
  --path=clusters/cloud
```
### Adding Source and Kustomization 
Below steps configure the repo that flux monitors. (You will be use this repo as your project. Please make sure you either forked or cloned and uploaded to your repo.)

#### Edge Side 
```bash
flux create source git iotedge \
  --context=<your context for edge> \
  --url=https://github.com/<your github username>/<your project> \
  --branch=<my-branch> \
  --interval=30s \
  --username=<github username> \
  --password=<token that you generated from github settings>
```

```bash
flux create kustomization iotedge \
  --context=<your context for edge> \
  --target-namespace=default \
  --source=iotedge \
  --path="./rpi-edge/app/envoy" \
  --prune=true \
  --validation=client \
  --interval=5m
```

#### Cloud Side 

```bash
flux create source git iocloud \
  --context=<your context for cloud> \
  --url=https://github.com/<your github username>/<your project> \
  --branch=<my-branch> \
  --interval=30s \
  --username=<github username> \
  --password=<token that you generated from github settings>
```

```bash
flux create kustomization iotcloud \
  --context=<your context for cloud> \
  --target-namespace=default \
  --source=iotcloud \
  --path="./azure-cloud/app/envoy" \
  --prune=true \
  --validation=client \
  --interval=5m
```

## SPIRE Deployment

### Cloud Side
 
1. Cloud side LB IP of spire server will be needed in order to configure federation with edge side. ( It will be used in step 4.)
    
    ```
    cd spire/azure-cloud
    kubectl --kubeconfig ~/.kube/cloud apply -f spire-namespace.yaml
    kubectl --kubeconfig ~/.kube/cloud apply -f server-service.yaml
    
    ```
    
2. Following command will deploy rest of the resources
    
    ```
    kubectl --kubeconfig ~/.kube/cloud apply -k .
    
    ```
    
3. Please make sure if spire pods are running: `watch kubectl --kubeconfig ~/.kube/cloud get po -nspire`. If they are, please use following script to register agents to spire server
    
    ```
    sh create-node-registration-entry.sh
    
    ```
### Edge Side    
4. Before deploying resources for edge, bundle endpoint should be set in configuration file of spire server. This endpoint is LB IP of cloud side spire server that we deployed in step1. In order to update the `bundle_endpoint.address` please go to line 35 in `server-configmap.yaml` . Obtain the external IP of spire server by using `kubectl --kubeconfig ~/.kube/cloud get svc -nspire`
    
    ```
    cd ../rpi-edge
    nano server-configmap.yaml
    
    ```
    
5. Following command will configure spire for raspberry PIs.
    
    ```
    kubectl --kubeconfig ~/.kube/edge apply -k .
    
    ```
    
6. Please make sure if spire pods are running: `watch kubectl --kubeconfig ~/.kube/edge get po -nspire`. If they are using, use following script to register agents to spire server
    
    ```
    sh create-node-registration-entry.sh
    
    ```
    
7. Last step is to federate clusters;
    
    ```
    cd ..
    sh federate.sh azure.cloud rpi.edge
    
    ```
    
    Please make sure if you get successfully bundled message, before move on next step.
    
## Sensor Setup
1. This step requires Arduino IDE. It can be downladed from https://www.arduino.cc/en/software . 
2. The code requires the following Arduino libraries:
  - DHT Sensor Library: https://github.com/adafruit/DHT-sensor-library
  - Adafruit Unified Sensor Lib: https://github.com/adafruit/Adafruit_Sensor
3. Please upload sensor.ino to your Arduino nano 33.
4. Kubernetes manifests in application deployment step are configured for 2 DHT11 sensors and considered the sensors are connected to the k8s-worker-1 node. Please be aware that you will need to change that in next step, you used different hostaname and connected the sensors to the different node/s.

## Application Deployment
### Cloud Side
1. Load balancer IP of broker will be needed in order to configure publisher in edge side.
    
    ```
    cd ../app/azure-cloud
    kubectl --kubeconfig ~/.kube/cloud apply -f broker-svc.yaml
    
    ```
    
2. Following command will deploy rest of the resources. (Grafana, Telegraf, Broker, Grafana)
    
    ```
    kubectl --kubeconfig ~/.kube/cloud apply -k .
    
    ```
### Edge Side    
3. Before deploying resources for edge, broker LB should be set in configuration file of envoy. In order to update the `endpoint.socket_address` please go to line 55 in `envoy-config.yaml` . Obtain the external IP of broker by using `kubectl --kubeconfig ~/.kube/cloud get svc`
    
    ```
    cd ../rpi-edge
    nano envoy-config.yaml
    
    ```
    
4. Following command will configure publisher for raspberry PIs.
    
    ```
    kubectl --kubeconfig ~/.kube/edge apply -k .
    ```
    
5. Check both edge and cloud if applications are running
    
    ```bash
    watch kubectl --kubeconfig ~/.kube/cloud get po
    watch kubectl --kubeconfig ~/.kube/edge get po
    ```
    
   
6. Last step is to register workloads. In order to register please use below scripts;
    
    ```
    sh workloadEntry-edge.sh
    cd ../azure-cloud
    sh workloadEntry-cloud.sh
    
    ```

7. Application can be tested using Grafana dashboard. Please import sensor.json file from app/dashboard/ to your grafana dashbboard. (Username/password for gragana is admin/admin).  


## Clean

Below script can be used in order to clean environments. File is located at the root directory of the repo.

```
sh nuke.sh
```
