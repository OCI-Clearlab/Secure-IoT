#/bin/bash

set -e

bb=$(tput bold)
nn=$(tput sgr0)

register() {
    kubectl --kubeconfig ~/.kube/cloud exec -n spire spire-server-0 -c spire-server -- /opt/spire/bin/spire-server entry create $@
}

echo "${bb}Creating registration entry for the broker - envoy...${nn}"
register \
    -parentID spiffe://azure.cloud/ns/spire/sa/spire-agent \
    -spiffeID spiffe://azure.cloud/ns/default/sa/serviceaccount-broker/broker \
    -selector k8s:ns:default \
    -selector k8s:sa:serviceaccount-broker \
    -federatesWith "spiffe://rpi.edge"

echo "${bb}Listing created registration entries...${nn}"
kubectl --kubeconfig ~/.kube/cloud exec -n spire spire-server-0 -- /opt/spire/bin/spire-server entry show
