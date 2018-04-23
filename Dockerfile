FROM postgres:9.2

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

# add needed MIRTH files
# mirth creates its own schema when it connects to postgres, but user will need to restore from mirth-backup.xml
ADD rsnadb.sql /docker-entrypoint-initdb.d/
ADD init-user-db.sh /docker-entrypoint-initdb.d/
#RUN chmod -R 777 /docker-entrypoint-initdb.d

# add standard tools
ENV TERM xterm


#  Set the default command to run when starting the container
#CMD ["/usr/lib/postgresql/9.2/bin/postgres", "-D", "/var/lib/postgresql/9.2/main", "-c", "config_file=/etc/postgresql/9.2/main/postgresql.conf"]


