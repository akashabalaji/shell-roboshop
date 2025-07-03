#!/bin/bash
START_TIME=$(date +%s)
USERID=$(id -u)
R="\e[31m"      
G="\e[32m"
Y="\e[33m"
N="\e[0m"

LOGS_FOLDER="/var/logs/roboshop-logs"
SCRIPT_NAME=$(echo $0 | cut -d "." -f1)
LOG_FILE="$LOGS_FOLDER/$SCRIPT_NAME.log"
SCRIPT_DIR=$PWD

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
dnf module disable nodejs -y &>>$LOG_FILE
VALIDATE $? "Disabling node js module"

dnf module enable nodejs:20 -y &>>$LOG_FILE
VALIDATE $? "enabling node js version 20"

dnf install nodejs -y &>>$LOG_FILE
VALIDATE $? "Installing nodejs"

id roboshop &>>$LOG_FILE
if [ $? -ne 0 ]
then
    useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop
else
    echo "roboshop user already exists.. $Y Skipping $N"
fi
mkdir -p /app 
curl -o /tmp/cart.zip https://roboshop-artifacts.s3.amazonaws.com/cart-v3.zip &>>$LOG_FILE
VALIDATE $? "Downloading cart.zip"

rm -rf /app/*
cd /app 
unzip /tmp/cart.zip &>>$LOG_FILE

npm install &>>$LOG_FILE

cp $SCRIPT_DIR/cart.service /etc/systemd/system/cart.service

systemctl daemon-reload &>>$LOG_FILE
systemctl enable cart &>>$LOG_FILE
systemctl start cart

END_TIME=$(date +%s)
TOTAL_TIME=$(( END_TIME - START_TIME ))
echo -e "Script executed successfully, ${Y}time taken: ${TOTAL_TIME} seconds${N}" | tee -a "$LOG_FILE"