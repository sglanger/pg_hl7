#!/bin/bash

###############################################
# Author: SG Langer April 2018
# Purpose: put all the Docker commands to build/run 
#	this Docker in one easy place
#
##########################################


############## main ###############
# Purpose: Based on command line arg either
#		a) build all Docker from scratch or
#		b) kill running docker or
#		c) start Docker or
#		d) restart
# Caller: user
###############################
clear
host="127.0.0.1"
repo="postgres"
image="dbase"
instance="pg"

case "$1" in
	build)
		# first clean up if any running instance
		# Comment out the rmi line if you really don't want to rebuild the docker
		sudo docker stop $instance
		sudo docker rmi -f $image
		sudo docker rm $instance

		# now build from clean. The DOcker run line uses --net="host" term to expose the docker
		# on the Host's NIC. For better security, remove it
		sudo docker build --rm=true -t $image .
		sudo docker run  --net="host" --name $instance -e POSTGRES_PASSWORD=postgres  -d $image  postgres -c 'config_file=/etc/postgresql/postgresql.conf'
		$0 status

		# after it starts need to load dbase schema and then make volume shares
		sudo docker exec -u root -it $instance /load_sql.sh
		$0 backup
	;;

	backup)
		sudo rm /tmp/pg_* 
		# listed in ordeer they were created in DOckefile
		conf=$(sudo docker inspect --format '{{ (index .Mounts 0).Source  }}' $instance ) 
		data=$(sudo docker inspect --format '{{ (index .Mounts 1).Source  }}' $instance ) 
		log=$(sudo docker inspect --format '{{ (index .Mounts 2).Source  }}' $instance  )

		# creating symlinks to ROOT owned volumes is problematic - as we will see in START
		sudo ln -s  $conf/ /tmp/pg_conf
		sudo ln -s  $log/ /tmp/pg_log
		sudo ln -s  $data/ /tmp/pg_data

		#	Method A: this methods backs up volumes - so multiple DOckers can use them
		# https://github.com/discordianfish/docker-backup
		# https://docs.docker.com/storage/volumes/#backup-a-container
		# https://stackoverflow.com/questions/21597463/how-to-port-data-only-volumes-from-one-host-to-another/23778599#23778599
		#sudo docker run --rm --volumes-from $instance -v /tmp:/pg busybox tar cvf /pg/$instance-conf.tar /etc/postgresql 
		#sudo docker run --rm --volumes-from $instance -v /tmp:/pg busybox tar cvf /pg/$instance-log.tar /var/log/postgresql/ 
		#sudo docker run --rm --volumes-from $instance -v /tmp:/pg busybox tar cvf /pg/$instance-data.tar /var/lib/postgresql/data
		
		# Method B: https://linoxide.com/linux-how-to/backup-restore-migrate-containers-docker/
		# this method backs up the WHOLE docker - but does not preserve volumes
		#sudo docker commit -p 17299c3b4bc6 $instance-backup
		#sudo docker save -o /tmp/$instance.tar $instance-backup
	;;

	conn)
		# connect to a  runnung docker
		sudo docker exec -it $instance /bin/bash 
	;;


	conn_r)
		# connect as root to a  runnung docker
		sudo docker exec -u root -it $instance /bin/bash
	;;

	clean)
		# remove all docker images
		clear
		original=$IFS
		IFS="\n"
		for line in $(sudo docker images) ; do
			#echo $line
			array=($line)
			echo ${array[0]}
		done
		IFS=$original
	;;

	getip)
		echo docker IP is; sudo docker inspect --format '{{ .NetworkSettings.IPAddress }}' $instance
	;;

	restart)
		$0 stop
		$0 start
	;;

	status)
		sudo docker ps; echo
		sleep 3
		sudo docker inspect $instance ; echo
	;;

	stop)
		# then stop and remove docker instance, but don't remove image from DOcker engine
		sudo docker container stop $instance
		sudo docker container rm $instance
		$0 status
	;;

	start)
		# mounting ROOT owned volumes is a pain - next 2 Refs deal with it
		# https://stackoverflow.com/questions/23439126/how-to-mount-host-directory-in-docker-container
		# https://denibertovic.com/posts/handling-permissions-with-docker-volumes/
		# -v /tmp/pg_conf:/etc/postgresql -v /tmp/pg_log:/var/log/postgresql/ -v /tmp/pg_data:/var/lib/postgresql/data \
		sudo docker run  -u '0' --net="host" --name $instance -e POSTGRES_PASSWORD=postgres  -d $image \
			--mount src=/tmp/pg_conf,target=/etc/postgresql,type=bind  --mount src=/tmp/pg_log,target=/var/log/postgresql,type=bind \
			--mount src=/tmp/pg_data,target=/var/lib/postgresql/data,type=bind \
			postgres -c 'config_file=/etc/postgresql/postgresql.conf'

		# Method A-2: restore from the backup volumes
		#sudo docker run -v /etc/postgresql -v /var/log/postgresql/ -v /var/lib/postgresql/data --net="host" \
		#	 --name $instance -e POSTGRES_PASSWORD=postgres  -d $image  postgres -c 'config_file=/etc/postgresql/postgresql.conf'
		#sudo docker run --rm --volumes-from $instance -v /tmp:/pg ubuntu bash -c "cd / && tar xvf /pg/$instance-data.tar --strip 1"

		# Method B-2: https://linoxide.com/linux-how-to/backup-restore-migrate-containers-docker/
		#sudo docker load -i /tmp/$instance-backup.tar 
		#sudo docker run  --net="host" --name $instance -e POSTGRES_PASSWORD=postgres  -d $image  postgres -c 'config_file=/etc/postgresql/postgresql.conf'
		sleep 3
		$0 status
	;;

	*)
		echo "invalid option"
		echo "valid options: build/start/stop/restart/status/conn/getip"
		exit
	;;
esac
