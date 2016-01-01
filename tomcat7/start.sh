#!/bin/bash

CATALINA_LOG_FILE=$TOMCAT_HOME/logs/catalina.out

if [ ! -f $CATALINA_LOG_FILE  ] ;
then 
    touch $CATALINA_LOG_FILE
fi

$TOMCAT_HOME/bin/startup.sh

tail -f $CATALINA_LOG_FILE