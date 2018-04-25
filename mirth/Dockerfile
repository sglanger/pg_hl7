FROM brandonstevens/mirth-connect


MAINTAINER Steve Langer <sglanger@fastmail.COM>
###############################################################
# POSTGRES
# extensions to postgresql for MIRTH HL7
# inspired by 	https://github.com/brandonstevens/mirth-connect-docker
# and 			https://hub.docker.com/r/brandonstevens/mirth-connect

# External files: "ADD" lines below and
#		run_ddw_db.sh
########################################################


# add standard tools
ENV TERM xterm
RUN apt-get update && apt-get -y install nano
RUN apt-get install -y \
	net-tools \
	nmap

# modify mirth to use remote postgres dbase
RUN mv /opt/mirth-connect/conf/mirth.properties /opt/mirth-connect/conf/mirth.properties.ori
ADD my_mirth.properties /opt/mirth-connect/conf/mirth.properties


