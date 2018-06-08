#!/bin/bash

#•Ï”’è‹`
. ./set_env_v1.sh

$curl -s -G ${endPoint}largepersongroups -H "Ocp-Apim-Subscription-Key: $apiKey"
