#!/bin/bash

#•Ï”’è‹`
. ./set_env_v1.sh

$curl -s -X DELETE ${endPoint}largepersongroups/$lpgName -H "Ocp-Apim-Subscription-Key: $apiKey"
