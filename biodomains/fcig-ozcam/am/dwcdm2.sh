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
# $0 - this script [dwcdm2.sh]
# $1 - null/'' for full, 'yyyy/MM/dd hh:mm:ss ...' for only records since this emu local time, eg: '2011/04/07'
# $1 - (note, format must be a valid arg for: date -d "<DATE/TIME SINCE>" +%s)
#
# v9: 20120817: bk - move to new dir
# v8: 20110913: bk - logging, subscript errors, move to new dir
# v7: 20110824: bk - branched to mv
# v6: 20110801: bk - error tests step 4 [bundle results]
# v5: 20110407: bk - phase 2 dm implementation - ozcam-dwc mapping, sftp push
# v4: 20110311: bk - branched to cater for ausmus export
#
# todo:
# - test sftp for errors prior to moving export to history

clear

pushd /home/emu/amweb
source .profile # this sets various EMu variables and adds to PATH
popd

# should be the full path to directory containing this script (note, no trailing '/')
DWCDM="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# the name of the single discipline export script in DWCDM
EXSCRIPT=dwcdm2dsx.sh
# the name of the python script that parses the image file data
IMAGESCRIPT=parse_texql_output.py
# the name of the python script that parses the datetime info in irn- files
DATESCRIPT=most_recent_date.py
# the names of the awk scripts that do the ozcam-darwincore mapping
# note: you must change these variables in EXSCRIPT as well
EXAWKID=ozdc_id.awk
EXAWKFULL=ozdc_full.awk

# the full path to the sftp staging directory (note, no trailing '/')
# if not a full path will be created under DWCDM
SFTPSTAGE=$DWCDM/sftp_staging
# the full path to the sftp history (note, no trailing '/')
# if not a full path will be created under DWCDM
SFTPHISTORY=$DWCDM/sftp_history
# the sftp ip addy (name resolution is disabled)
SFTPIPADDR=`cat SFTPIPADDR.txt`
#the sftp user
SFTPUSER=`cat SFTPUSER.txt`
#the sftp password
SFTPPASS=`cat SFTPPASS.txt`
EXPORTDATE=`date "+%Y/%m/%d %H:%M:%S"`

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

  #should be a better error code...
  exit 1

fi

# this command instructs bash to copy all stdout & stderr into one log file...
#exec > >(tee -a $DWCDM/$EXDIR/dwcdm2.sh.log) 2>&1
# preferable to copy stdout & stderr to separate log files;
# note: this log file will grow with every export
echo '--------------------------------' $EXPORTDATE '--------------------------------' >> $DWCDM/log.dwcdm2
echo '--------------------------------' $EXPORTDATE '--------------------------------' >> $DWCDM/logerr.dwcdm
exec > >(tee -a $DWCDM/log.dwcdm2)
exec 2> >(tee -a $DWCDM/logerr.dwcdm2)
# as the script continues, logs will also made to the tmp export dir
# this has the effect of the logs being bundled with the export
echo some variables:
set | grep TEX
set | grep EMU

# if required, export a list of disciplines - data exported will be confined to these
#   if disciplines are ever added or you wish to export only a subset
#   modify this file, commenting out lines with a leading '#'
# write "$DWCDM/disciplines-list"

if [ -f $DWCDM/disciplines-list ]
  then echo "#$0#$(date +%H:%M:%S)# $DWCDM/disciplines-list exists - using this list"

else

  echo "#$0#$(date +%H:%M:%S)# Writing disciplines to $DWCDM/disciplines-list"

  echo "# $(date)" > "$DWCDM/disciplines-list"
  echo "# comments and blank lines are ignored" >> "$DWCDM/disciplines-list"

  echo "#$0#$(date +%H:%M:%S)# This is a costly operation; no exports will occur afterwards"
  echo "#$0#$(date +%H:%M:%S)#  - you could build this file manually"
  echo "#$0#$(date +%H:%M:%S)#  - put each discipline on a line by itself"
  echo "#$0#$(date +%H:%M:%S)#  - it must match the EMu discipline precisely"
  echo "#$0#$(date +%H:%M:%S)#  - if interested: Ctrl+C to terminate, then:"
  echo "#$0#$(date +%H:%M:%S)#       vi $DWCDM/disciplines-list"

  echo distinct \(\(select SecDepartment_tab from ecatalogue\)\) | texql -R | sed "s/]//g;s/[()'\[]//g;s/|/\n/g" | sort -u | grep -v -e '`' -e "^$" -e "Evolutionary Biology Unit" -e "Archives" -e "Mineralogy" -e "Anthropology" -e "Admin" -e "Education" -e "Materials Conservation" -e "Palaeontology" -e "Archives" >> "$DWCDM/disciplines-list"

  echo "#$0#$(date +%H:%M:%S)# Check $DWCDM/disciplines-list before running $0 again"

  exit 0

fi


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

  exit 1

fi

# this command instructs bash to copy all stdout & stderr into one log file...
#exec > >(tee -a $DWCDM/$EXDIR/dwcdm2.sh.log) 2>&1
# preferable to copy stdout & stderr to separate log files;
# note, we continue to log to the main directory as well
exec > >(tee -a $DWCDM/$EXDIR/log.dwcdm2 $DWCDM/log.dwcdm2)
exec 2> >(tee -a $DWCDM/$EXDIR/logerr.dwcdm2 $DWCDM/logerr.dwcdm2)

echo "#$0#$(date +%H:%M:%S)# 1 - export directory is:"
echo "#$0#$(date +%H:%M:%S)# 1 -   '$DWCDM/$EXDIR'"

# copy all the interesting stuff to the work dir
cp $DWCDM/$0 $DWCDM/$EXDIR/
cp $DWCDM/$EXSCRIPT $DWCDM/$EXDIR/
cp $DWCDM/$IMAGESCRIPT $DWCDM/$EXDIR/
cp $DWCDM/$DATESCRIPT $DWCDM/$EXDIR/
cp $DWCDM/$EXAWKID $DWCDM/$EXDIR/
cp $DWCDM/$EXAWKFULL $DWCDM/$EXDIR/
cp $DWCDM/disciplines-list $DWCDM/$EXDIR/



##### 2 #####
# export list of tables, counts, schemata & a full list of keys (IRNs) from ecatalogue
#   this will be bundled with the export in case of problems
# write "$DWCDM/$EXDIR/tab-count-list"
# write "$DWCDM/$EXDIR/tab-list"
# write "$DWCDM/$EXDIR/tab-describe"
# write "$DWCDM/$EXDIR/ecat-kfdump"

echo "#$0#$(date +%H:%M:%S)# 2 - writing $DWCDM/$EXDIR/tab-count-list"

# dump the list of tables with counts to a file
texlist -l > "$DWCDM/$EXDIR/tab-count-list"

echo "#$0#$(date +%H:%M:%S)# 2 - writing $DWCDM/$EXDIR/tab-list"

# dump the list of tables to a file
texlist -l | cut -f1 -d' ' > "$DWCDM/$EXDIR/tab-list"

echo "#$0#$(date +%H:%M:%S)# 2 - writing $DWCDM/$EXDIR/tab-describe"

# describe all tables to a file...
# write the date to the file first
date > "$DWCDM/$EXDIR/tab-describe"
# with each line in tab-list, describe that table fully
while read -r LINE ; do echo describe $LINE | texql -R; done < "$DWCDM/$EXDIR/tab-list" >> "$DWCDM/$EXDIR/tab-describe"

# dump keys from ecatalogue
texkfdump -d$'\n' ecatalogue > "$DWCDM/$EXDIR/ecat-kfdump"


##### 3 #####
# for each discipline, export a list of: irn, created timestamp, modified t/s
#   each discipline list represents the currently active, public records
#   it also includes modification data in case a delta-export is being done

echo "#$0#$(date +%H:%M:%S)# 3 - calling $EXSCRIPT for each discipline"

# parse disciplines-list and print lines that have no leading comment (awk ...)
# pipe that to a while loop - read in each (while read -r DLLINE)
# with DLLINE call up EXSCRIPT (do ... done)
# append the results to EXSCRIPT-log ( >> "DWCDM/EXDIR/EXSCRIPT-log" )

awk '{ sfirst = substr($1,1,1); if( (sfirst != "#") && (sfirst != "") ) { print $0; } }' "$DWCDM/disciplines-list" |
while read -r DLLINE ;
do
echo "#$0#$(date +%H:%M:%S)# 3 - $EXSCRIPT '$DLLINE' '$DWCDM/$EXDIR' '$1'";

bash -c "$EXSCRIPT '$DLLINE' '$DWCDM/$EXDIR' '$1'"

# need to test here for success or failure...

# had to resort to sh - couldn't get the following to work properly...
#
#awk seens to get stuck on the first entry in disciplines-list
# - awk -v scmd="$EXSCRIPT $DLLINE $DWCDM/$EXDIR >> \'$DWCDM/$EXDIR/$EXSCRIPT-log\'" '{ system(scmd); }';
#
#exec runs the first line in the file succcessfully then breaks the loop
# - exec $EXSCRIPT $DLLINE $DWCDM/$EXDIR

done

# move back to the main directory
popd

##### 4 #####
# bundle up the export
# delete the working directory

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

  #set up the sftp dirs if they don't already exist
  mkdir -vp "$SFTPSTAGE"
  mkdir -vp "$SFTPHISTORY"

tarret=$(tar -zcvf $SFTPSTAGE/$EXDIR.tar.gz $EXDIR -C $DWCDM > /dev/null)$?

if [ $tarret -ne 0 ]
then
  echo "#$0#$(date +%H:%M:%S)# 4 - tar.gz failure: $?"

  exit $tarret

fi
# tell bash to continue logging only to the main log files
exec > >(tee -a $DWCDM/log.dwcdm2)
exec 2> >(tee -a $DWCDM/logerr.dwcdm2)

# delete the source directory
echo deleting "$DWCDM/$EXDIR"
rm -r $DWCDM/$EXDIR

##### 5 #####
# send all exports

#sometimes for testing don't want to do this step so make it conditional on environment variable SKIPSFTP being empty:
if test "x" == "x$SKIPSFTP"
then
  echo "#$0#$(date +%H:%M:%S)# 5 - sending all files in $SFTPSTAGE"
  lftp sftp://$SFTPUSER:$SFTPPASS@$SFTPIPADDR  -e "put $SFTPSTAGE/$EXDIR.tar.gz; bye"
fi

if [ `cat $DWCDM/$EXDIR/logerr.dwcdm2 | wc -l` -eq 0 ] # script ran without error (need better way to test for overall success) esp.need to test for success/failure on sftp before moving data to history
then
  # save date and time of the most recently inserted record for use with next incremental export
  touch amexport.last
  mv amexport.last amexport.last.bak
  ( cat $DWCDM/$EXDIR/*/irn-[^m]* | cut -f2,3 -d, ; cat $DWCDM/$EXDIR/*/irn-[^m]* | cut -f4,5 -d, ) | grep -v Adm| $DWCDM/$DATESCRIPT > amexport.last

  ##### 6 #####
  # move all exports to the history

  echo "#$0#$(date +%H:%M:%S)# 6 - moving all files in $SFTPHISTORY"

  mv $SFTPSTAGE/* $SFTPHISTORY/
fi

  echo "#$0#$(date +%H:%M:%S)# finished"

