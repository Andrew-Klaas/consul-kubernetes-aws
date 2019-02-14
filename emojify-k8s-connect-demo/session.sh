#! /bin/bash
#doitlive prompt: {dir.bold.magenta} $
tree emojify
kubectl apply -f ./emojify
kubectl get svc
kubectl describe svc emojify-ingress | awk -F\: '/LoadBalancer Ingress/ {gsub(/ /, "", $0); print $2}'
tree emojify-connect
git diff --no-index -- emojify/api.yml emojify-connect/api.yml
kubectl apply -f ./emojify-connect
git diff --no-index -- emojify-connect/api.yml emojify-enterprise/api.yml
kubectl apply -f ./emojify-enterprise
