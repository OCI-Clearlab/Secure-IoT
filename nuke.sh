#!/bin/bash
set -e

bb=$(tput bold)
nn=$(tput sgr0)
RED='\033[0;31m'
NC='\033[0m'

echo "${bb}${RED}Cleaning applications on the cloud${NC}${nn}"
cd app/azure-cloud
kubectl --kubeconfig ~/.kube/cloud delete -k .
kubectl --kubeconfig ~/.kube/cloud delete -f broker-svc.yaml

echo "${bb}${RED}Cleaning applications on the edge${NC}${nn}"
cd ../rpi-edge
kubectl --kubeconfig ~/.kube/edge delete -k .


echo "${bb}${RED}Cleaning SPIRE agent and server deployment on the cloud${NC}${nn}"
cd ../../spire/azure-cloud
kubectl --kubeconfig ~/.kube/cloud delete -k .
kubectl --kubeconfig ~/.kube/cloud delete -f server-service.yaml
kubectl --kubeconfig ~/.kube/cloud delete -f spire-namespace.yaml

echo "${bb}${RED}Cleaning SPIRE agent and server deployment on the edge${NC}${nn}"
cd ../rpi-edge
kubectl --kubeconfig ~/.kube/edge delete -k .

echo "${bb}${RED}Cleaning is DONE${NC}${nn}"
