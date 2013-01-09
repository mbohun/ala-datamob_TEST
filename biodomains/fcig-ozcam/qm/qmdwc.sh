#!/bin/bash

#/**************************************************************************
# *  Copyright (C) 2011 Atlas of Living Australia
# *  All Rights Reserved.
# *
# *  The contents of this file are subject to the Mozilla Public
# *  License Version 1.1 (the "License"); you may not use this file
# *  except in compliance with the License. You may obtain a copy of
# *  the License at http://www.mozilla.org/MPL/
# *
# *  Software distributed under the License is distributed on an "AS
# *  IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
# *  implied. See the License for the specific language governing
# *  rights and limitations under the License.
# ***************************************************************************/


# DwC data export script
#
# this script calls on exports to happen for each discipline in discipline-list
#
# $0 - this script [qmdwc.sh]
# (NOT IMPLEMENTED) $1 - null/'' for full, 'yyyy/MM/dd hh:mm:ss ...' for only records since this emu local time, eg: '2011/04/07'
# (NOT IMPLEMENTED) $1 - (note, format must be a valid arg for: date -d "<DATE/TIME SINCE>" +%s)
#
# v1: 20120605: bk - ported from austmus & samus, modified to work in qm environment with dwc
#
# todo:
# - testing, remove need to log in (mysql & sftp) at command line

clear

# should be the full path to this script (note, no trailing '/')
DWCDM=/qmexport
# this file contains the definition of the view from which data are extracted
VWSCRIPT=qmdwc_view.sql
# this file contains the queries to extract the data
EXSCRIPT=qmdwc_export.sql
# this file contains the output header row (note, set in $EXSCRIPT)
CSVDWCHEADER=/tmp/qmdwc_header.csv
# this file contains the output data, without header (note, set in $EXSCRIPT)
CSVDWCDATA=/tmp/qmdwc_data.csv
# this file will contain combined header & data
CSVDWC=qmdwc.csv
# this is the database name in mysql
MYSQLDB=mysql_database
# this variable will hold the mysql admin user, as entered by the user, when the script runs (see line ~65)
MYSQLUSR=guest
# this variable holds the mysql admin pass, filled by the user when the script runs
MYSQLPWD=password


# the full path to the sftp staging directory (note, no trailing '/')
# if not a full path will be created under DWCDM
SFTPSTAGE=$DWCDM/sftp_staging
# the full path to the sftp history (note, no trailing '/')
# if not a full path will be created under DWCDM
SFTPHISTORY=$DWCDM/sftp_history
# the sftp dns
SFTPIPADDR=upload.ala.org.au
#the sftp user
SFTPUSER=xxxx

# store the mysql admin user & password before we start logging output... (logs are bundled with the export & uploaded!)
echo -n 'enter the mysql username: ' && read MYSQLUSR && echo -n "($MYSQLUSR) enter password: " && read MYSQLPWD && echo "continuing with user: $MYSQLUSR ($MYSQLPWD)"
# don't forget to overwrite these vars before exiting!
#MYSQLUSR=$(date +%Y%m%d.%H%M)
#MYSQLPWD=$(date +%Y%m%d.%H%M)

# set up the export directory
pushd $DWCDM > /dev/null

# make sure we can see this script
if [ $DWCDM/$0 ]
then
  echo "#$0#$(date +%H:%M:%S)# working dir is:"
  echo "#$0#$(date +%H:%M:%S)#   $DWCDM"

else
  echo "#$0#$(date +%H:%M:%S)# working dir is not dir of this script:"
  echo "#$0#$(date +%H:%M:%S)#   $DWCDM"
  echo "directory unexpected: export aborted" > "/dev/stderr"
  echo "\'$0\' \'$1\'" > "/dev/stderr"

  # sanitise the user & pass
  MYSQLUSR=$(date +%Y%m%d.%H%M)
  MYSQLPWD=$(date +%Y%m%d.%H%M)

  #should be a better error code...
  exit 1

fi

# this command instructs bash to copy all stdout & stderr into one log file...
#exec > >(tee -a $DWCDM/logs.qmdwc) 2>&1
# preferable to copy stdout & stderr to separate log files;
# note: this log file will grow with every export
exec > >(tee -a $DWCDM/log.qmdwc)
exec 2> >(tee -a $DWCDM/logerr.qmdwc)
# as the script continues, logs will also made to the tmp export dir
# (this has the effect of the logs being bundled with the export, should the script succeed to that point)

##############################################################################################
# (NOT IMPLEMENTED) - no discrimination on the records at this stage (all records at once)
##############################################################################################
## if required, export a list of disciplines - data exported will be confined to these
##   if disciplines are ever added or you wish to export only a subset
##   modify this file, commenting out lines with a leading '#'
## write "$DWCDM/disciplines-list"
#
#if [ $DWCDM/disciplines-list ]
#  then echo "#$0#$(date +%H:%M:%S)# $DWCDM/disciplines-list exists - using this list"
#
#else
#
#  echo "#$0#$(date +%H:%M:%S)# Writing disciplines to $DWCDM/disciplines-list"
#
#  echo "# $(date)" > "$DWCDM/disciplines-list"
#  echo "# comments and blank lines are ignored" >> "$DWCDM/disciplines-list"
#
#  echo "#$0#$(date +%H:%M:%S)# This is a costly operation; no exports will occur afterwards"
#  echo "#$0#$(date +%H:%M:%S)#  - you could build this file manually"
#  echo "#$0#$(date +%H:%M:%S)#  - put each discipline on a line by itself"
#  echo "#$0#$(date +%H:%M:%S)#  - it must match the EMu discipline precisely"
#  echo "#$0#$(date +%H:%M:%S)#  - if interested: Ctrl+C to terminate, then:"
#  echo "#$0#$(date +%H:%M:%S)#       vi $DWCDM/disciplines-list"
#
#  echo distinct \(\(select CatDiscipline from ecatalogue\)\) | texql -R | tr -d \'\(\) >> "$DWCDM/disciplines-list"
#
#  echo "#$0#$(date +%H:%M:%S)# Check $DWCDM/disciplines-list before running $0 again"
#
#  exit 0
#
#fi
##############################################################################################


##### 1 #####
# determine the current export directory

EXDIR=$(date +%Y%m%d.%H%M);
if [ -d $EXDIR ]
then
  EXTMP=$(mktemp -d "$EXDIR.XXX");
  EXDIR=$EXTMP
fi

mkdir -vp "$EXDIR"
pushd "$EXDIR" > /dev/null

if [ "$(pwd)" != "$DWCDM/$EXDIR" ] 
then
	echo "#$0#$(date +%H:%M:%S)# working dir is:"
	echo "#$0#$(date +%H:%M:%S)#   $(pwd)"
	echo "#$0#$(date +%H:%M:%S)# expected:"
	echo "#$0#$(date +%H:%M:%S)#   $DWCDM/$EXDIR"

	echo "$0 $1" > "/dev/stderr"
	echo "directory unexpected: export aborted" > "/dev/stderr"

  # sanitise the user & pass
  MYSQLUSR=$(date +%Y%m%d.%H%M)
  MYSQLPWD=$(date +%Y%m%d.%H%M)

  exit 1

fi

# this command instructs bash to copy all stdout & stderr into one log file...
#exec > >(tee -a $DWCDM/$EXDIR/logs.qmdwc $DWCDM/logs.qmdwc) 2>&1
# preferable to copy stdout & stderr to separate log files;
# note, we continue to log to the main directory as well
exec > >(tee -a $DWCDM/$EXDIR/log.qmdwc $DWCDM/log.qmdwc)
exec 2> >(tee -a $DWCDM/$EXDIR/logerr.qmdwc $DWCDM/logerr.qmdwc)

echo "#$0#$(date +%H:%M:%S)# 1 - export directory is:"
echo "#$0#$(date +%H:%M:%S)# 1 -   '$DWCDM/$EXDIR'"

# copy all the interesting stuff to the work dir
cp $DWCDM/$0 $DWCDM/$EXDIR/
cp $DWCDM/$EXSCRIPT $DWCDM/$EXDIR/
cp $DWCDM/$VWSCRIPT $DWCDM/$EXDIR/


##### 2 #####
# export schemata from catalogue
#   this will be bundled with the export in case of problems
# write "$DWCDM/$EXDIR/mysqldump.opac_2_0_vernon.sql"

echo "#$0#$(date +%H:%M:%S)# 2 - writing $DWCDM/$EXDIR/mysqldump.opac_2_0_vernon.sql"

# dump the list of tables with counts to a file
mysqldump --no-data --user="$MYSQLUSR" --password="$MYSQLPWD" "$MYSQLDB" > "$DWCDM/$EXDIR/mysqldump.opac_2_0_vernon.sql"


##### 3 #####
# full export only at this stage, partial not implemented
# (for each discipline, export a list of: irn, created timestamp, modified t/s)
# (  each discipline list represents the currently active, public records)
# (  it also includes modification data in case a delta-export is being done)

# remove the existing output, if any
rm -f $CSVDWCHEADER
rm -f $CSVDWCDATA

echo "#$0#$(date +%H:%M:%S)# 3 - executing $EXSCRIPT, storing temporary output in files:"
echo "#$0#$(date +%H:%M:%S)# 3 -   $CSVDWCHEADER"
echo "#$0#$(date +%H:%M:%S)# 3 -   $CSVDWCDATA"

### query the database, storing results in $CSVDWCHEADER & $CSVDWCDATA
mysql --user="$MYSQLUSR" --password="$MYSQLPWD" --database="$MYSQLDB" --execute="source $EXSCRIPT" --batch

# test to see if header & data files were output
# (for more details see - http://stackoverflow.com/questions/572206/bash-how-do-i-check-if-certain-files-exist)
if [[ ( -f $CSVDWCHEADER && -f $CSVDWCDATA ) ]]; then
	echo "#$0#$(date +%H:%M:%S)# 3 - combining output into: $CSVDWC"

	### join results
	# cat header and data files, and use sed to remove (non-compliant) character combinations '\0x0d0x0a' (backslash + carriage return + line feed)
	# for a detailed description of the two sed calls, see - http://stackoverflow.com/questions/1251999/sed-how-can-i-replace-a-newline-n
	cat -v $CSVDWCHEADER $CSVDWCDATA | sed ':a;N;$!ba;s/\\\n/\\n/g' | sed ':a;N;$!ba;s/\n\n/\n/g' > $CSVDWC

else
	echo "#$0#$(date +%H:%M:%S)# 3 - temporary output file(s) not found"
	echo "#$0#$(date +%H:%M:%S)# 3 - no output will be generated in: $CSVDWC"

	echo "failed to find temporary output files '$CSVDWCHEADER' and '$CSVDWCDATA' ... file '$CSVDWC' won't be generated" > "/dev/stderr"

fi

# move back to the main directory
popd

##### 4 #####
# bundle up the export
# delete the working directory

#set up the sftp dirs if they don't already exist
mkdir -vp "$SFTPSTAGE"
mkdir -vp "$SFTPHISTORY"

echo "#$0#$(date +%H:%M:%S)# 4 - bundling $DWCDM/$EXDIR with tar.gz"

#http://linux.about.com/od/commands/l/blcmdl1_tar.htm
#http://www.computerhope.com/unix/utar.htm

#z - gzip
#c - Create. Writing begins at the beginning of the tarfile, instead of at the end.
#v - Verbose. Output the name of each file preceded by the function letter. With the t function, v provides additional information about the tarfile entries.
#f - File. Use the tarfile argument as the name of the tarfile.

#notes on --remove-files option:
# some ver's of tar have problems with links: https://bugzilla.redhat.com/show_bug.cgi?id=698212
# unlikely to encounter this scenario, but you never know...
# in any case, not using this one, as cannot find confirmation of behaviour -
#  - would --remove-files only delete after a successful, complete tar.gz creation?
#  - or would it delete each file as it went, leaving itself open for a possible failure?

# run tar and check for success
# do not redirect errors - we want to capture all output at some point
# must redirect /dev/null otherwise the output of the command will be in $tarret
# (see 'http://ubuntuforums.org/archive/index.php/t-373657.html' for comments on status-test)

tarret=$(tar -zcvf $SFTPSTAGE/$EXDIR.tar.gz $DWCDM/$EXDIR > /dev/null)$?

if [ $tarret -ne 0 ]
then
  echo "#$0#$(date +%H:%M:%S)# 4 - tar.gz failure: $?"

  # don't forget to sanitise the admin user & password
  MYSQLUSR=$(date +%Y%m%d.%H%M)
  MYSQLPWD=$(date +%Y%m%d.%H%M)

  exit $tarret

else
	# tell bash to continue logging only to the main log files
  exec > >(tee -a $DWCDM/log.qmdwc)
  exec 2> >(tee -a $DWCDM/logerr.qmdwc)

  # delete the source directory
  rm -r $DWCDM/$EXDIR

  ##### 5 #####
  # send all exports

  echo "#$0#$(date +%H:%M:%S)# 5 - sending all files in $SFTPSTAGE"

  # note here: this is extremely brittle - should test for success/failure on sftp before moving data to history
  # however, sftp options for achieving this is parsing a directory listing, not ideal
  # really, we need to migrate to rsync, but this is not availble on the upload server at this stage (20120606)
  echo "put $SFTPSTAGE/*" | sftp $SFTPUSER@$SFTPIPADDR


  ##### 6 #####
  # move all exports to the history

  echo "#$0#$(date +%H:%M:%S)# 6 - moving all files in $SFTPHISTORY"

  mv $SFTPSTAGE/* $SFTPHISTORY/

  echo "#$0#$(date +%H:%M:%S)# finished"

fi

# don't forget to sanitise the admin user & password
MYSQLUSR=$(date +%Y%m%d.%H%M)
MYSQLPWD=$(date +%Y%m%d.%H%M)
