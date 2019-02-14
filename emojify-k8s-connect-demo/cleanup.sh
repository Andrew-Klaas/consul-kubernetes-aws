#! /bin/bash

kubectl delete -f emojify-enterprise
kubectl delete -f emojify-connect
kubectl delete -f emojify
helm delete --purge consul
# Delete Consul synched services
kubectl delete service --all
kubectl delete PersistentVolume --all
