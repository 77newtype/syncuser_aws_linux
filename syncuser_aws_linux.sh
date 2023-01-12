#!/bin/bash
#
# amazon-linux-extras install epel -y
# yum install -y shc 
# yum install -y sshpass
# yum install -y gcc
# shc -f syncuser.sh

#전체 어카운트의 live 서버에 전체 계정을 대상으로 실행
#ex) sh syncuser.sh live

#특정 어카운트의 dev,stg 서버에 특정 계정만 대상으로 실행
#ex) sh syncuser.sh stg account_name "user1|user2"
#ex) sh syncuser.sh dev account_name "user1|user2"




bastionip=`hostname -I`
aws_profile=`cat /root/.aws/config | grep profile | sed -e 's/profile//g' | sed -e 's/\[//g' | sed -e 's/\]//g' | grep -E "$2"`

pass='X'

cd /root/mgmt/syncuser
rm -f ./data/*

echo 'target account:' $aws_profile
echo ''


#대상 iplist 취합 / bastion ip 제외
if [ $1 = "live" ]
then

for profiles in $aws_profile
do
        aws ec2 describe-instances --filter "Name=tag:stage,Values=live" "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].[PrivateIpAddress]" --profile $profiles  | grep -v "\[" | grep -v "\]" | grep -v $bastionip | sed -e 's/^ *//g' | sed -e "s/\"//g" >> ./data/ip.list
done

elif [ $1 = "stg" ]
then
for profiles in $aws_profile
do
        aws ec2 describe-instances --filter "Name=tag:stage,Values=stg" "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].[PrivateIpAddress]" --profile $profiles  | grep -v "\[" | grep -v "\]" | grep -v $bastionip | sed -e 's/^ *//g' | sed -e "s/\"//g" >> ./data/ip.list
done

elif [ $1 = "dev" ]
then
for profiles in $aws_profile
do
        aws ec2 describe-instances --filter "Name=tag:stage,Values=dev" "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].[PrivateIpAddress]" --profile $profiles  | grep -v "\[" | grep -v "\]" | grep -v $bastionip | sed -e 's/^ *//g' | sed -e "s/\"//g" >> ./data/ip.list
done

# elif [ $1 = "dev" ] || [ $1 = "stg" ]
# then
# for profiles in $aws_profile
# do
#        aws ec2 describe-instances --filter "Name=tag:stage,Values=stg,dev" "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].[PrivateIpAddress]" --profile $profiles  | grep -v "\[" | grep -v "\]" | grep -v $bastionip | sed -e 's/^ *//g' | sed -e "s/\"//g" >> ./data/ip.list
# done

else
echo 'only live,dev,stg available' ; exit

fi


#유저 리스트 획득
cat /etc/passwd | grep -A 100 ec2-user | grep -v 'ec2-user' | cut -d ":" -f1 | grep -E "$3" > ./data/user.list


#대상자 shadow 정보 취합
rm -f ./data/shadow.tmp
while read users
do
	cat /etc/shadow | grep $users >> ./data/shadow.tmp
done < ./data/user.list


#변경 시작
while read ipaddress
do
	#유저 생성
	sshpass -p$pass scp -P10022 -o StrictHostKeyChecking=no ./data/user.list techadmin@$ipaddress:/tmp/
	sshpass -p$pass ssh -no StrictHostKeyChecking=no techadmin@$ipaddress -p10022 "while read users; do sudo /usr/sbin/adduser \$users -g dev; done < /tmp/user.list"

	#대상자 shadow 정보 scp
	sshpass -p$pass scp -P10022 -o StrictHostKeyChecking=no ./data/shadow.tmp  techadmin@$ipaddress:/tmp/
	
	#shadow 수정을 위한 cp 
	sshpass -p$pass ssh -no StrictHostKeyChecking=no techadmin@$ipaddress -p10022 "sudo cp /etc/shadow /tmp/shadow; sudo chmod 002 /tmp/shadow ;"
	
	#기존 유저 패스워드 정보 삭제
	sshpass -p$pass ssh -no StrictHostKeyChecking=no techadmin@$ipaddress -p10022 "while read users; do sudo sed -i "/'$users'/d" /tmp/shadow; done < /tmp/user.list"	

	#shadow 정보 업데이트, 원복
	sshpass -p$pass ssh -no StrictHostKeyChecking=no techadmin@$ipaddress -p10022 "sudo cat /tmp/shadow.tmp >> /tmp/shadow ; sudo chmod 000 /etc/shadow ; sudo cp /tmp/shadow /etc/shadow ; sudo rm -f /tmp/shadow "



	echo `date`
	echo $ipaddress

done < ./data/ip.list


echo done