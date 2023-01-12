# syncuser_aws_linux

1. bastion host 의 계정 정보를 전체 어카운트의 ec2에 동기화
2.  전체서버로 동기화
3. 특정 어카운트 특정 유저만 동기화

* 대상
  * aws EC2
  * Tag filter "Name=tag:stage,Values=live,stg,dev"
 
* run_syncuser.sh
  * 패스워드 변경을 감시
 
* syncuser_per_account.sh
  * 계정/패스워드 동기화
 
* 사전 환경
  * 관리 대상 어카운트 등록
  * aws configure --profile account

* crontab 등록
>  ```* * * * * /bin/sh /root/mgmt/syncuser/run_syncuser.sh```
 
* 사용 방법
  * admin bastion host
    * 전체 서버로 동기화
      * ex) sh syncuser.sh live

  * developer bastion
    * 특정 어카운트 동기화
      * ex) sh 스크립트.sh 환경, 어카운트, “사용자1|사용자2”
      * ex) sh syncuser.sh stg account_name "user1|user2"
      * ex) sh syncuser.sh dev account_name "user1|user2"

 
* 스크립트 암호화
  * shc -f syncuser.sh
  * rm -f syncuser.sh; rm -f syncuser.sh.x.c
