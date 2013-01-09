#!/bin/bash

if [ "$1" != "--yes" ]
then
  echo '=============================================='
  echo 'this command will connect to upload.ala.org.au' 
  echo 'and download the contents of ./exporter/'
  echo 'it will overwrite any local copies of files'
  echo ''
  echo 'to prove you are serious, the command must be:'
  echo "  $0 --yes"
  echo '=============================================='
  echo 'listing contents of remote sftp "/_exporter/":'
  echo "ls -l _exporter/" | sftp qldmus@upload.ala.org.au
  echo '=============================================='
  echo ''
else
  echo 'updating exporter scripts ...'
  echo "get /_exporter/*" | sftp qldmus@upload.ala.org.au

	# this variable will hold the mysql admin user, as entered by the user, when the script runs (see line ~70)
	MYSQLUSR=guest
	# this variable holds the mysql admin pass, filled by the user when the script runs
	MYSQLPWD=password

	# store the mysql admin user & password before we start logging output... (logs are bundled with the export & uploaded!)
	echo 'enter the mysql username:' && read MYSQLUSR && echo "($MYSQLUSR) enter password:" && read MYSQLPWD && echo "continuing with user: $MYSQLUSR ($MYSQLPWD)"
	# don't forget to overwrite these vars before exiting!
	#MYSQLUSR=$(date +%Y%m%d.%H%M)
	#MYSQLPWD=$(date +%Y%m%d.%H%M)

  echo 'connecting to mysql to replace views ...'
  mysql --user=$MYSQLUSR --password=$MYSQLPWD --database=opac_2_0_vernon --execute='source qmdwc_view.sql'
  
  echo 'end of update; connecting to mysql to describe vw_qmdwc...'
  mysql --user=$MYSQLUSR --password=$MYSQLPWD --database=opac_2_0_vernon --execute='describe vw_qmdwc'

  # sanitise the user & pass
  MYSQLUSR=$(date +%Y%m%d.%H%M)
  MYSQLPWD=$(date +%Y%m%d.%H%M)

fi
