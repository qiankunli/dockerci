FROM 192.168.3.56:5000/ubuntu
MAINTAINER bert.li

#COPY resources/apache-tomcat-7.0.59.tar.gz /tmp/
#COPY resources/jdk-7u79-linux-x64.tar.gz /tmp/

#RUN tar -zxvf /tmp/apache-tomcat-7.0.59.tar.gz -C /usr/local; \
#    tar -zxvf /tmp/jdk-7u79-linux-x64.tar.gz -C /usr/local

#RUN rm /tmp/apache-tomcat-7.0.59.tar.gz; \
#    rm /tmp/jdk-7u79-linux-x64.tar.gz

ADD resources/apache-tomcat-7.0.59.tar.gz /usr/local/
ADD resources/jdk-7u79-linux-x64.tar.gz /usr/local/
   
RUN mv /usr/local/apache-tomcat-7.0.59 /usr/local/tomcat7 ;\
    mv /usr/local/jdk1.7.0_79 /usr/local/jdk7

ENV JAVA_HOME /usr/local/jdk7
ENV TOMCAT_HOME /usr/local/tomcat7
ENV PATH $PATH:$JAVA_HOME/bin

RUN sed '98 aCATALINA_OPTS="-Xdebug  -Xrunjdwp:transport=dt_socket,address=8000,server=y,suspend=n"' -i $TOMCAT_HOME/bin/catalina.sh
ADD start.sh /start.sh
EXPOSE 8080 8000 