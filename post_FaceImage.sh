#!/bin/bash

if [ $# -lt 1 ]; then
  echo "$# argument entered." 1>&2
  echo 'Please specify argument image files directory by "Full Path" and Saved to Directory(option).' 1>&2
  exit 1
fi

#変数定義
. ./set_env_v1.sh

# 画像リストの作成と顔リストの削除
ls -1 $1 > imglist.txt
rm facelist.txt

# ログの記録開始
echo "" >> $exclog
echo "Starting Face registration shell script loging..." >> $exclog
echo `date '+%Y/%m/%d %T'` >> $exclog

# faceId, faceRectangleの取得
while IFS=, read C1
do

    # 画像のアップロードとfaceIDの検出
    echo "Upload a image file ${C1} and detect face"
    $curl -s -X POST ${endPoint}detect?returnFaceId=true -H "Content-Type: application/octet-stream" -H "Ocp-Apim-Subscription-Key: $apiKey" --data-binary "@$1/${C1}" | ./jq -r '(.[] | [.faceId, .faceRectangle.top, .faceRectangle.left, .faceRectangle.width, .faceRectangle.height]) | @csv' | sed -e 's/"//g' > $faceList
    
    # faceIdの判別（TODO: 真偽いずれもログ。偽の場合はループ抜け）
    if [ "`wc -l $faceList`" = "0 $faceList" ]; then
        echo "Least one face required in a image. Skipped..."
        echo ""
        echo ${C1},False >> $exclog
        continue
    fi
    
    while IFS=, read D1 D2 D3 D4 D5
    do
        echo "Face ID is ${D1}"
        echo Face Rectangle is Top:${D2} Left:${D3} Width:${D4} Height:${D5} at $1 / ${C1}
        echo " "
        
        # JSON作成
jsondata=$(< <(cat <<EOS
{
   "largePersonGroupId": "$lpgName",
    "faceIds": [
        "${D1}"
    ],
    "maxNumOfCandidatesReturned": 1,
    "confidenceThreshold": 0.5
}
EOS
))
        
        # faceIdを使ってIdentify
        personId=`$curl -s -X POST ${endPoint}identify -H "Content-Type: application/json" -H "Ocp-Apim-Subscription-Key: $apiKey" -d "$jsondata" | ./jq -r .[].candidates[0].personId`
        
        # personIdの判別（TODO: 真偽いずれもログ。真の場合はpersonIdに登録、偽の場合は新規Person登録）
        if [ "$personId" = "null" ]; then
            echo "Detected face ID is not matched any regitered person. Make a new person for LargePersonGroup"
            # 新規Person登録
            # JSON作成
jsondata=$(< <(cat <<EOS
{
    "name": "${C1}",
    "userData": ""
}
EOS
))
            personId=`$curl -s -X POST ${endPoint}largepersongroups/$lpgName/persons -H "Content-Type: application/json" -H "Ocp-Apim-Subscription-Key: $apiKey" -d "$jsondata" | ./jq -r .personId`
            
            echo "Created new Person ID is $personId"
        else
            echo "Face ID: ${D1} is matched Person ID: $personId"
        fi
    
        # faceId と personId を使って Add Face 実施
        # TODO: userData の追加方法検討
        perFaceId=`$curl -s -X POST ${endPoint}largepersongroups/$lpgName/persons/$personId/persistedfaces?targetFace=${D3},${D2},${D4},${D5} --data-binary "@$1/${C1}" -H "Content-Type: application/octet-stream" -H "Ocp-Apim-Subscription-Key: $apiKey" | ./jq -r .persistedFaceId | tee -a nullpg.txt`
                # TODO: 登録実施の判別（真偽いずれもログ。真の場合はTraining開始、偽の場合はループ抜け）
        echo "Detected face is registered. Persisted Face ID is $perFaceId" 
        
        # LPG で Training 実施
        $curl -s -X POST ${endPoint}largepersongroups/$lpgName/train -H "Ocp-Apim-Subscription-Key: $apiKey" -H "Content-Length: 0"
        
        # Training 状況確認ループ
        status=""
        while [ "$status" != "succeeded" ]
        do
            # LPG で Training 状況確認
            echo "Checking the leraning status ..."
            sleep 3
            status=`$curl -s -G ${endPoint}largepersongroups/$lpgName/training -H "Ocp-Apim-Subscription-Key: $apiKey" | ./jq -r .status`
        done
        
        # 登録結果のログ出力
        echo ${C1},True,${lpgName},${personId},${perFaceId},${D2},${D3},${D4},${D5} >> $exclog
        
    done < $faceList
done < imglist.txt
