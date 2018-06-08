#!/bin/bash

if [ $# -lt 1 ]; then
  echo "$# argument entered." 1>&2
  echo 'Please specify argument image files directory by "Full Path" and Saved to Directory(option).' 1>&2
  exit 1
fi

#�ϐ���`
. ./set_env_v1.sh

# �摜���X�g�̍쐬�Ɗ烊�X�g�̍폜
ls -1 $1 > imglist.txt
rm facelist.txt

# ���O�̋L�^�J�n
echo "" >> $exclog
echo "Starting Face registration shell script loging..." >> $exclog
echo `date '+%Y/%m/%d %T'` >> $exclog

# faceId, faceRectangle�̎擾
while IFS=, read C1
do

    # �摜�̃A�b�v���[�h��faceID�̌��o
    echo "Upload a image file ${C1} and detect face"
    $curl -s -X POST ${endPoint}detect?returnFaceId=true -H "Content-Type: application/octet-stream" -H "Ocp-Apim-Subscription-Key: $apiKey" --data-binary "@$1/${C1}" | ./jq -r '(.[] | [.faceId, .faceRectangle.top, .faceRectangle.left, .faceRectangle.width, .faceRectangle.height]) | @csv' | sed -e 's/"//g' > $faceList
    
    # faceId�̔��ʁiTODO: �^�U����������O�B�U�̏ꍇ�̓��[�v�����j
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
        
        # JSON�쐬
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
        
        # faceId���g����Identify
        personId=`$curl -s -X POST ${endPoint}identify -H "Content-Type: application/json" -H "Ocp-Apim-Subscription-Key: $apiKey" -d "$jsondata" | ./jq -r .[].candidates[0].personId`
        
        # personId�̔��ʁiTODO: �^�U����������O�B�^�̏ꍇ��personId�ɓo�^�A�U�̏ꍇ�͐V�KPerson�o�^�j
        if [ "$personId" = "null" ]; then
            echo "Detected face ID is not matched any regitered person. Make a new person for LargePersonGroup"
            # �V�KPerson�o�^
            # JSON�쐬
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
    
        # faceId �� personId ���g���� Add Face ���{
        # TODO: userData �̒ǉ����@����
        perFaceId=`$curl -s -X POST ${endPoint}largepersongroups/$lpgName/persons/$personId/persistedfaces?targetFace=${D3},${D2},${D4},${D5} --data-binary "@$1/${C1}" -H "Content-Type: application/octet-stream" -H "Ocp-Apim-Subscription-Key: $apiKey" | ./jq -r .persistedFaceId | tee -a nullpg.txt`
                # TODO: �o�^���{�̔��ʁi�^�U����������O�B�^�̏ꍇ��Training�J�n�A�U�̏ꍇ�̓��[�v�����j
        echo "Detected face is registered. Persisted Face ID is $perFaceId" 
        
        # LPG �� Training ���{
        $curl -s -X POST ${endPoint}largepersongroups/$lpgName/train -H "Ocp-Apim-Subscription-Key: $apiKey" -H "Content-Length: 0"
        
        # Training �󋵊m�F���[�v
        status=""
        while [ "$status" != "succeeded" ]
        do
            # LPG �� Training �󋵊m�F
            echo "Checking the leraning status ..."
            sleep 3
            status=`$curl -s -G ${endPoint}largepersongroups/$lpgName/training -H "Ocp-Apim-Subscription-Key: $apiKey" | ./jq -r .status`
        done
        
        # �o�^���ʂ̃��O�o��
        echo ${C1},True,${lpgName},${personId},${perFaceId},${D2},${D3},${D4},${D5} >> $exclog
        
    done < $faceList
done < imglist.txt
