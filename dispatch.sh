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

dnf install golang -y &>>$LOG_FILE
VALIDATE $? "Installing golang"

id roboshop &>>$LOG_FILE    

if [ $? -ne 0 ]
then  
    useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop &>>$LOG_FILE
else
    echo "roboshop user already exists.. $Y Skipping $N "
fi

mkdir /app &>>$LOG_FILE
VALIDATE $? "Creating /app directory"

curl -o /tmp/dispatch.zip https://roboshop-artifacts.s3.amazonaws.com/dispatch-v3.zip &>>$LOG_FILE
VALIDATE $? "Downloading dispatch.zip"

cd /app
rm -rf /app/* 
unzip /tmp/dispatch.zip &>>$LOG_FILE
VALIDATE $? "Unzipping dispatch.zip"

go mod init dispatch &>>$LOG_FILE
VALIDATE $? "Initializing go module"

go get &>>$LOG_FILE
VALIDATE $? "Installing go dependencies"

go build &>>$LOG_FILE
VALIDATE $? "Building go application"

cp $SCRIPT_DIR/dispatch.service /etc/systemd/system/dispatch.service