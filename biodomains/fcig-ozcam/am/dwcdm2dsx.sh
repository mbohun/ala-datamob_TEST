#!/bin/bash

# /***************************************************************************
# Copyright (C) 2011 Atlas of Living Australia
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

# ozcam/darwincore data export
#
# v4.1AM 20121116 mh - use SecDepartment_tab instead of CatDiscipline to search by discipline
# v4: 20110914: bk - output file-names in variables, specify debug output file in awk
# v3: 20110824: bk - branched to mv
# v2: 20110803: bk - modified irn-$1 and ecat-id-$1.csv.gz to include CatRegNumber
# v1: 20110407: bk - austmus discipline export
#
# this script does a full or partial export of a given discipline
# it is generally called up by mvdm2.sh for all disciplines, but
# may also be called on an adhoc basis
#
# $0 - this script [dwcdm2dsx.sh]
# $1 - the discipline string, eg: 'Palaeontology' or 'Invertebrates - Marine & Other'
# $2 - the root directory, eg: '~/work/dwcexport/20110407.223301' (will be created if need be)
# $3 - null/'' for full, 'yyyy/MM/dd hh:mm:ss ...' for only records since this emu local time, eg: '2011/04/07' 
# $3 - (note, format must be a valid arg for: date -d "<DATE/TIME SINCE>" +%s)
#
# setup - create a temp dir in $2 and pushd into it
#
# step 1 for a given discipline, export an irn list (snapshot)
#  $DWCDMROOT/$TMPEXD/$FNAME_IRN$1
#
# step 2 export currently public 'last modified' ozcam-darwincore list
#    if doing a 'partial' delta-export, generate a sublist of interesting IRNs
#    otherwise, if doing a full-export, push all IRNs to the next step
#  reads - $DWCDMROOT/$TMPEXD/$FNAME_IRN$1
#  write - $DWCDMROOT/$TMPEXD/$FNAME_IRNMOD$1
#  write - $DWCDMROOT/$TMPEXD/$1$FNAME_EXID.csv.gz
#
# step 3 for the filtered irn-only list, export data from emu:
#    first, write a full record with header row, matching the first couple of irns
#    next, pipe to $DWCDMROOT/convert-mapped.awk for mapping non-ambiguous ozcam-darwincore records
#    then pipe to gzip for compression before writing to disc
#  reads - $DWCDMROOT/$TMPEXD/$FNAME_IRNMOD$1
#  write - $DWCDMROOT/$TMPEXD/$FNAME_HDR$1
#  write - $DWCDMROOT/$TMPEXD/$1$FNAME_EXDATA.csv.gz
#
# finish - write the discipline to dwcdm_finish
#  write - $DWCDMROOT/$TMPEXD/dwcdm_finish

#clear

pushd /home/emu/amweb
source .profile # this sets various EMu variables and adds to PATH
popd

# the names of the awk scripts that do the ozcam-darwincore mapping
EXAWKID=ozdc_id.awk
EXAWKFULL=ozdc_full.awk

FNAME_IRN=irn-
FNAME_HDR=hdr-
FNAME_IRNMOD=irn-mod-
FNAME_EXID=-dwcid
FNAME_EXDATA=-dwcdata

DWCDMROOT=$2

# set up the export directory
mkdir -vp $DWCDMROOT
pushd $DWCDMROOT > /dev/null

echo "#$0#$(date +%H:%M:%S)# DwC data mobilisation root is:"
echo "#$0#$(date +%H:%M:%S)#   $DWCDMROOT"

# create a temporary directory for us to work in
# directory will be bundled using gz
TMPEXD=$(mktemp -d amexXXXXX);
pushd $TMPEXD > /dev/null

if [ "$(pwd)" != "$DWCDMROOT/$TMPEXD" ] 
then
	echo "#$0#$(date +%H:%M:%S)# working dir is:"
	echo "#$0#$(date +%H:%M:%S)#   $(pwd)"
	echo "#$0#$(date +%H:%M:%S)# should be:"
	echo "#$0#$(date +%H:%M:%S)#   $DWCDMROOT/$TMPEXD"
	echo "directory unexpected: export aborted" > "/dev/stderr"
	echo "$0 $1 $2 $3" > "/dev/stderr"
  exit 1
else
	echo "#$0#$(date +%H:%M:%S)# working dir is:"
	echo "#$0#$(date +%H:%M:%S)#   $DWCDMROOT/$TMPEXD"
fi

echo "#$0#$(date +%H:%M:%S)# discipline is '$1'"

###
#just incase this gets run accidentally
###
# echo "#$0#$(date +%H:%M:%S)# script needs to be checked to ensure emu compatibility"
# echo "#$0#$(date +%H:%M:%S)# see - $0: line 99, 'echo select irn_1 ... textql -R"
# exit 1

##### 1 #####
# for a given discipline, export an irn list (snapshot);
# having one list ensures consistent output for:
#  - the currently public 'last modified' darwincore list
#  - the full/darwincore exports

echo "#$0#$(date +%H:%M:%S)# 1 - writing '$DWCDMROOT/$TMPEXD/$FNAME_IRN$1'"

# note: if you want to change fields in this output,
# - you must do so to the header row AND the data row(s)
# - you must also modify step 2 to ensure it reads AdmDate/AdmTimeModified values
#   (see step 2 comments for more details)
#
# write the header row...
echo irn_1,AdmDateInserted,AdmTimeInserted,AdmDateModified,AdmTimeModified,CatRegNumber,CatDiscipline > "$FNAME_IRN$1"
# write the data rows... (note 'append':  >> irn-$1)
#careful of the yucky ampersand:
export DISC=`echo $1| sed 's/&/\\\&/g'`
echo select irn_1,AdmDateInserted,AdmTimeInserted,AdmDateModified,AdmTimeModified,CatRegNumber from ecatalogue where exists \( SecDepartment_tab where SecDepartment = \'$DISC\' \) | texql -R | tr -d \'\(\) | sed "s/$/,$1/" >> "$FNAME_IRN$1"


##### 2 #####
# write the irn-list with last modified > $3 (texexport filter)
# also convert currently public 'last modified' list to ozcam-darwincore

echo "#$0#$(date +%H:%M:%S)# 2 - writing '$DWCDMROOT/$TMPEXD/$FNAME_IRNMOD$1'"

# (code is brittle and should do a lookup for values on field names)
# this step requires AdmDateModified to be at $4, and AdmTimeModified to be at $5
# if these data change positions, you need to modify the next line to reflect that:
# - $4 reference: ... cnt++; idmparts = split($4,arrdm,"/") ...
# - $5 reference: ... arrdm[1] " " $5 "\" +%s ...
# - full line at time of comment: cat "irn-$1" | awk -F"," 'BEGIN{cnt=-1}; { if(-1 == cnt) cnt=0; else { cnt++; idmparts = split($4,arrdm,"/"); if(3 == idmparts) { scmd = "date -d \"" arrdm[3] "/" arrdm[2] "/" arrdm[1] " " $5 "\" +%s 2>/dev/null"; printf($1 " "); (ssecs = system(scmd)); } } };' |  awk -v ssince="$3" -v dtsince=$(date -d "$3" +%s 2>/dev/null) -F' ' 'BEGIN{if(!dtsince || ("" == ssince))dtsince=0;};{if($2>dtsince) print $1; };' > "irn-mod-$1"
#
cat "$FNAME_IRN$1" | awk -F"," 'BEGIN{cnt=-1}; { if(-1 == cnt) cnt=0; else { cnt++; idmparts = split($4,arrdm,"/"); if(3 == idmparts) { scmd = "date -d \"" arrdm[3] "/" arrdm[2] "/" arrdm[1] " " $5 "\" +%s 2>/dev/null"; printf($1 " "); (ssecs = system(scmd)); } } };' |  awk -v ssince="$3" -v dtsince=$(date -d "$3" +%s 2>/dev/null) -F' ' 'BEGIN{if(!dtsince || ("" == ssince))dtsince=0;};{if($2>dtsince) print $1; };' > "$FNAME_IRNMOD$1"

echo "#$0#$(date +%H:%M:%S)# 2 - writing '$DWCDMROOT/$TMPEXD/$1$FNAME_EXID.csv.gz'"

cat "$FNAME_IRN$1" | awk -F"," -v department="$1" -v _dbg_out_file="$DWCDMROOT/$TMPEXD/$EXAWKID.log" -f "$DWCDMROOT/$EXAWKID" | gzip -8 >> "$1$FNAME_EXID.csv.gz"


##### 3 #####
# for the filtered irn-only list, export data from emu

# make a file with emultimedia irn, rightholder and publisher fields
echo "#$0#$(date +%H:%M:%S)# 3 - writing '$DWCDMROOT/$TMPEXD/$1$FNAME_EXDATA.images.tsv'"

echo select irn, DocMimeFormat_tab, Multimedia, MulCreator_tab, DetPublisher, DocIdentifier_tab, DocFileSize_tab from emultimedia where true and \( exists \( SecDepartment_tab where \( SecDepartment contains \'$DISC\' \) \) \) and \( not \( MulCreator_tab = \[\] \) \) and \( not \( DetPublisher is NULL \) \) and \( AdmPublishWebNoPassword contains \'Yes\' \) and \( ChaFileSize \<= 500000 \) and \( DetPublisher = \'Australian Museum\' \)| texql | sed "s/^(//;s/')$//;s/,\['/\t/;s/'\],'/\t/;s/','/\t/" > $DWCDMROOT/$TMPEXD/$1$FNAME_EXDATA.images.tsv

echo "#$0#$(date +%H:%M:%S)# 3 - writing '$DWCDMROOT/$TMPEXD/$1$FNAME_EXDATA.csv'"

head -n 10 "$FNAME_IRNMOD$1" | texexport -k- -fdelimited -ms"+|" -md"" -mc ecatalogue > "$FNAME_HDR$1"

cat "$FNAME_IRNMOD$1" | texexport -k- -fdelimited -ms"+|" -md"" -mc ecatalogue | awk -F"[+][|]" -v department="$1" -v _dbg_out_file="$DWCDMROOT/$TMPEXD/$EXAWKFULL.log" -v image_file="$DWCDMROOT/$TMPEXD/$1$FNAME_EXDATA.images.tsv" -f "$DWCDMROOT/$EXAWKFULL" | iconv -t UTF-8 -f ISO-8859-1 > "$1$FNAME_EXDATA.csv"

#check all fields have got some data:
#this is slow so make it optional
if  test "x" != "x"$DO_EXDATA_CHECK
then
	echo "#$0#$(date +%H:%M:%S)# 3 - checking '$DWCDMROOT/$TMPEXD/$1$FNAME_EXDATA.csv'"
	export NCOL=`head -1 "$1$FNAME_EXDATA.csv" | awk -F'","' '{print NF}'`
	export HDRS=('dummy' `head -1 "$1$FNAME_EXDATA.csv" | sed 's/^"//;s/","/ /g;s/"$//'`)
	echo i,field,nonempty,distinct
	for i in $(seq 1 $NCOL)
	do
	  NONEMPTY=`sed 1d "$1$FNAME_EXDATA.csv" | awk -F'","' '{print $'$i'}' | grep -v "^$" | wc -l`
	  DISTINCT=`sed 1d "$1$FNAME_EXDATA.csv" | awk -F'","' '{print $'$i'}' | grep -v "^$" | sort -u | wc -l`
	  echo ${i},${HDRS[$i]},${NONEMPTY},${DISTINCT}
	done
fi

echo "#$0#$(date +%H:%M:%S)# 3 - compressing to '$DWCDMROOT/$TMPEXD/$1$FNAME_EXDATA.gz'"
gzip -8 "$1$FNAME_EXDATA.csv"

echo "#$0#$(date +%H:%M:%S)# 3 - finished"

echo $1 > $DWCDMROOT/$TMPEXD/dwcdm_finish

