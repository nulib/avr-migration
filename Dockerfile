FROM docker.io/fcrepo/fcrepo:7-tomcat10
COPY ./config/fcrepo.properties /usr/local/tomcat/fcrepo-home/config/fcrepo.properties
