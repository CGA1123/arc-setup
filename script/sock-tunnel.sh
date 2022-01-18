#!/bin/bash

function external_ip() {
  kubectl get services --namespace ingress-nginx ingress-nginx-controller --output jsonpath='{.status.loadBalancer.ingress[0].ip}'
}

while [ -z "$(external_ip)" ]; do
  echo "waiting for minikube tunnel..."
  sleep 0.5
done

EXTERNAL_IP="$(external_ip)"
echo "tunnel localhost:80 to ${EXTERNAL_IP}:80"

sudo socat TCP-LISTEN:80,fork TCP:"${EXTERNAL_IP}":80
