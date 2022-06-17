#!/bin/bash

# standard bash error handling
set -o errexit;
set -o pipefail;
set -o nounset;
# debug commands
set -x;

# working dir to install binaries etc, cleaned up on exit
BIN_DIR="$(mktemp -d)"
# binaries will be here
MINIKUBE="${BIN_DIR}/minikube"
HELM="${BIN_DIR}/helm"

# cleanup on exit (useful for running locally)
cleanup() {
    "${MINIKUBE}" delete --all || true
    rm -rf "${BIN_DIR}"
}
trap cleanup EXIT

install_minikube_release() {
    MINIKUBE_BINARY_URL="https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64"
    wget -O "${MINIKUBE}" "${MINIKUBE_BINARY_URL}"
    chmod +x "${MINIKUBE}"
}

install_helm_release() {
    HELM_BINARY_URL="https://get.helm.sh/helm-v3.9.0-linux-amd64.tar.gz"
    wget -O "${HELM}" "${MINIKUBE_BINARY_URL}"
    chmod +x "${HELM}"
}

main() {
    # get binaries
    install_minikube_release
    install_helm_release

    # create a cluster
    "${MINIKUBE}" start --force --wait=all

    # create kustomize resources
    "${MINIKUBE}" kubectl -- apply -k resources

    # deploy z2jh helm chart
    "${HELM}" repo add jupyterhub https://jupyterhub.github.io/helm-chart/
    "${HELM}" repo update
    "${HELM}" upgrade --cleanup-on-fail \
              --install z2jh jupyterhub/jupyterhub \
              --namespace default \
              --create-namespace \
              --version=1.2.0 \
              --wait

    # wait to resources to start running
    "${MINIKUBE}" kubectl -- wait pods -n default -l app=postgres --for condition=Ready --timeout=90s

    "${MINIKUBE}" kubectl -- get pods -A
    # TODO: invoke your tests here
    # teardown will happen automatically on exit
}

main
