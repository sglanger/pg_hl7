#!/bin/bash

case "$1" in

	build)
		od=$(pwd)
		cd $od/dbase
		sudo ./run_docker.sh build
		cd $od/mirth
		sudo ./run_docker.sh build
		cd $od
		$0 status
		$0 instructions
	;;


	instructions)
		echo "now should have pg and mc running"
		echo "point your docker host's browser to http://dockerhost:8080 "
		echo "to get the Mirth console and install your channels"
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
