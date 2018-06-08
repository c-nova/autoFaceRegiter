#!/bin/bash

#変数定義
endPoint="https://<endpoint>.api.cognitive.microsoft.com/face/v1.0/"
apiKey="<API Key>"
lpgName="<LargePersonGroup Name>"
faceList="facelist.txt"

exclog=./$2/`basename $0 .sh`.log
pxaddrport=

#ログ初期化開始
echo "" >> $exclog
echo "#########################################" >> $exclog
echo "Using Ocp-Apim-Subscription-Key(supressed)." | tee -a $exclog
echo "Using Proxy Server and Port $pxaddrport." | tee -a $exclog

#Proxy判別
curl --connect-timeout 2 -sI https://ms.portal.azure.com

if [ "$?" == "0" ]
then
    curl="curl"
    echo "HEAD Command to Azure Portal was successful." | tee -a $exclog
else
    curl="curl -x $pxaddrport"
    echo "HEAD Command to Azure Portal was fauilure. Use Proxy settings." | tee -a $exclog
fi
