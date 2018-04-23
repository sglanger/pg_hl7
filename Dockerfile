FROM postgres:latest

MAINTAINER Steve Langer <sglanger@fastmail.COM>
###############################################################
# POSTGRES
# extensions to postgresql for MIRTH HL7
# inspired by 	https://github.com/docker-library/postgres/blob/0aaaf2094034647a552f0b1ec63b1b0ec0f6c2cc/10/Dockerfile
# and 			https://hub.docker.com/_/postgres/
#
# External files: "ADD" lines below and
#		run_ddw_db.sh
########################################################

# add volume for persistent data
# do it on the compose yaml

# modify postgres for  MIRTH use
# mirth makes own schema when it connects to postgres, but user will need to restore from mirth-backup.xml
ADD init-user-db.sh /docker-entrypoint-initdb.d/init-user-db.sh 
ADD rsnadb.sql /docker-entrypoint-initdb.d/rsnadb.sql
RUN chmod -R 777 /docker-entrypoint-initdb.d


# add standard tools
ENV TERM xterm

# add networking config - 
ADD mypostgres.conf /etc/postgresql/postgresql.conf




