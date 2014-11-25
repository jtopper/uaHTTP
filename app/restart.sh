#!/bin/bash

runIt() {
  echo -e "\n\n" ; ps ux 

  echo "runIt calling killer script..." 
  ./killer
  sleep 5
  
  echo "runIt clearing up BRAAAAINS"
  killall killer uaHTTP launcher
  sleep 5
  
  echo -e "\n\n" ; ps ux

  echo "runIt starting launcher..."
  \rm nohup.out
  nohup ./launcher &
}

if [ "`whoami`" != "uahttp" ] ; then
  echo "You need to run me as uahttp"
  exit 1
fi

if [ "$1" == "-runIt" ] ; then
  runIt
elif [ $# -eq 0 ] ; then
  $0 -runIt
fi

exit 0

