#! /bin/bash

DEMO_PROMPT="$ "
TYPE_SPEED=100

. ~/bin/demo-magic.sh

clear

pe "tree emojify"

pe "kubectl apply -f ./emojify"

echo $DEMO_PROMPT
wait
clear

pe "tree emojify-connect"

pe "git diff --no-index -- emojify/api.yml emojify-connect/api.yml"

clear

pe "kubectl apply -f ./emojify-connect"


echo $DEMO_PROMPT
wait
clear

pe "git diff --no-index -- emojify-connect/api.yml emojify-enterprise/api.yml"

clear

pe "kubectl apply -f ./emojify-enterprise"

echo $DEMO_PROMPT
wait

echo $DEMO_PROMPT
wait

echo $DEMO_PROMPT
wait