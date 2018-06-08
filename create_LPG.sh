#!/bin/bash

#•Ï”’è‹`
. ./set_env_v1.sh

jsondata=$(< <(cat <<EOS
{
    "name": "TestLargePersonGroup",
    "userData": "LPG for test"
}
EOS
))

$curl -s -X PUT ${endPoint}largepersongroups/$lpgName -H "Content-Type: application/json" -H "Ocp-Apim-Subscription-Key: $apiKey" -d "$jsondata"
