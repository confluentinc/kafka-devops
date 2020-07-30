#!/usr/bin/env bash

set -e

if [[ ! -x "$(command -v kubectl)" ]]; then
    echo "kubectl not found"
    exit 1
fi

if [[ ! -x "$(command -v helm)" ]]; then
    echo "helm not found"
    exit 1
fi

if [[ ! -x "$(command -v fluxctl)" ]]; then
    echo "fluxctl not found"
    exit 1
fi

REPO_GIT_INIT_PATHS="environments/dev\,secrets/sealed/dev"
REPO_ROOT=$(git rev-parse --show-toplevel)
REPO_URL=${1:-git@github.com:confluentinc/kafka-devops}
REPO_BRANCH=master
TEMP=${REPO_ROOT}/.temp
REPO_GIT_USER=rspurgeon
REPO_GIT_EMAIL=rspurgeon@confluent.io

rm -rf ${TEMP} && mkdir ${TEMP}

helm repo add fluxcd https://charts.fluxcd.io

echo ">>> Installing Flux for ${REPO_URL} only watching the ${REPO_GIT_INIT_PATHS} directory"
kubectl create ns flux || true
helm upgrade -i flux fluxcd/flux --wait \
--set git.url=${REPO_URL} \
--set git.user=${REPO_GIT_USER} \
--set git.email=${REPO_GIT_EMAIL} \
--set git.branch=${REPO_BRANCH} \
--set git.path=${REPO_GIT_INIT_PATHS} \
--set git.pollInterval=1m \
--set manifestGeneration=true \
--set registry.pollInterval=1m \
--set sync.state=secret \
--set syncGarbageCollection.enabled=true \
--namespace flux

echo ">>> GitHub deploy key"
kubectl -n flux logs deployment/flux | grep identity.pub | cut -d '"' -f2

# wait until flux is able to sync with repo
echo ">>> Waiting on user to add above deploy key to Github with write access"
until kubectl logs -n flux deployment/flux | grep event=refreshed
do
  sleep 5
done
echo ">>> Github deploy key is ready"

echo ">>> Cluster bootstrap done!"
