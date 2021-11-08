#!/bin/bash
RED='\033[0;31m'
NC='\033[0m'
bb=$(tput bold)
nn=$(tput sgr0)

DIR="$( cd "$( dirname "$BASH_SOURCE[0]" )" && pwd )"
echo ${DIR}
TRUST_DOMAIN_CLOUD=$1
TRUST_DOMAIN_EDGE=$2

echo "${bb}${RED}Federation for domains: $TRUST_DOMAIN_CLOUD and $TRUST_DOMAIN_EDGE"

echo "${bb}${RED}Extracting trust bundle for cloud${NC}${nn}"
kubectl --kubeconfig ~/.kube/cloud exec -n spire spire-server-0 -- /opt/spire/bin/spire-server bundle show -format spiffe > ${DIR}/azure-cloud.bundle
echo "${bb}${RED}Extracting trust bundle for edge${NC}${nn}"
kubectl --kubeconfig ~/.kube/edge exec -n spire spire-server-0 -- /opt/spire/bin/spire-server bundle show -format spiffe > ${DIR}/rpi-edge.bundle

echo "${bb}${RED}Setting trust bundles for cloud${NC}${nn}"
kubectl --kubeconfig ~/.kube/cloud exec -i -n spire spire-server-0 -- /opt/spire/bin/spire-server bundle set -format spiffe -id spiffe://${TRUST_DOMAIN_EDGE} < ${DIR}/rpi-edge.bundle
echo "${bb}${RED}Setting trust bundles for edge${NC}${nn}"
kubectl --kubeconfig ~/.kube/edge exec -i -n spire spire-server-0 -- /opt/spire/bin/spire-server bundle set -format spiffe -id spiffe://${TRUST_DOMAIN_CLOUD} < ${DIR}/azure-cloud.bundle
sleep 3
echo "${bb}${RED}Checking bundle for azure${NC}${nn}"
kubectl --kubeconfig ~/.kube/cloud exec -it -n spire spire-server-0 -- cat server.log | grep '"Bundle refreshed"\|"Bundle set successfully"'
echo "${bb}${RED}Checking bundle for raspberry pi${NC}${nn}"
kubectl --kubeconfig ~/.kube/edge exec -it -n spire spire-server-0 -- cat server.log | grep '"Bundle refreshed"\|"Bundle set successfully"'
