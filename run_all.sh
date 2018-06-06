#!/bin/bash

clear
case "$1" in

	build)
		od=$(pwd)
		cd $od/dbase
		sudo $od/dbase/run_docker.sh build
		cd $od/mirth
		sudo $od/mirth/run_docker.sh build
		cd $od
		$0 status
		$0 instructions
	;;


	instructions)
		echo "You should now have "pg" and "mc" running"
		echo "Point your docker host's browser to http://dockerhost:8080 "
		echo "to get to the Mirth console, then install your channels"
	;;

	status)
		sudo docker ps; echo
		sleep 3
		#sudo docker inspect $instance ; echo
	;;

	*)
		echo "invalid option"
		echo "valid options: build/status"
		exit
	;;
esac
