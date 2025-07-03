#!/bin/bash
START_TIME=$(date +%s)
USERID=$(id-u)
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

LOGS_FOLDER="/var/logs/roboshop-logs"
SCRIPT_NAME=$(echo $0 | cut -d "." -f1)
LOG_FILE="$LOGS_FOLDER/$SCRIPT_NAME.log"

mkdir -p $LOGS_FOLDER
echo "script started executing at: $(date)" | tee -a $LOG_FILE

#check the user has root previleges or not
if [ $USERID -ne 0 ]
then
    echo -e "$R ERROR:: Please run this script with root access $N" | tee -a $LOG_FILE # Exit if not root
    exit 1 # Exit with error code 1
    else
    echo "You are running with root access" | tee -a $LOG_FILE
fi
# validate functions takes input as exit status, what command they tried to install
VALIDATE(){
    if [ $1 -eq 0 ]
    then
        echo -e "$2 is ... $G SUCCESS $N" | tee -a $LOG_FILE
    else
        echo -e "$2 is ... $R FAILURE $N" | tee -a $LOG_FILE
        exit 1
    fi
}
dnf module disable redis -y &>>$LOG_FILE
VALIDATE $? "Disabling redis module"

dnf module enable redis:7 -y &>>$LOG_FILE
VALIDATE $? "Enabling Redis:7"

dnf install redis
VALIDATE $? "Installing Redis"

sed -i -e 's/127.0.0.1/0.0.0.0/g' -e '/protected-mode/ c protected-mode no' /etc/redis/redis.conf
VALIDATE $? "Edited redis conf to accenpt reremote connection" 

systemctl enable redis &>>$LOG_FILE
VALIDATE $? "Enabling redis service"

systemctl start redis &>>$LOG_FILE
VALIDATE $? "Starting redis service"


END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))
echo "Script executed successfully, $Y time taken: $TOTAL_TIME seconds $N" | tee -a $LOG_FILE