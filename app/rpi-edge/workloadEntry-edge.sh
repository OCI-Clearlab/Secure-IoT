#/bin/bash

set -e

bb=$(tput bold)
nn=$(tput sgr0)

register() {
    kubectl --kubeconfig ~/.kube/edge exec -n spire spire-server-0 -c spire-server -- /opt/spire/bin/spire-server entry create $@
}

echo "${bb}Creating registration entry for the publisher - envoy...${nn}"
register \
    -parentID spiffe://rpi.edge/ns/spire/sa/spire-agent \
    -spiffeID spiffe://rpi.edge/ns/default/sa/serviceaccount-publisher/publisher \
    -selector k8s:ns:default \
    -selector k8s:sa:serviceaccount-publisher \
    -federatesWith "spiffe://azure.cloud"

echo "${bb}Listing created registration entries...${nn}"
kubectl --kubeconfig ~/.kube/edge exec -n spire spire-server-0 -- /opt/spire/bin/spire-server entry show
