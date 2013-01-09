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
# v6: 20121010: bk - EXAWKID=ozdc_id.awk (not ozdc_full.awk!), file-name suffix
# v5: 20111102: bk - re-joined am fork: better comments & logging, opensource-licence
# v4: 20110914: bk - output file-names in variables, specify debug output file in awk (also codepage conversion)
# v3: 20110824: bk - branched to mv
# v2: 20110803: bk - modified irn-$1 and ecat-id-$1.csv.gz to include CatRegNumber
# v1: 20110407: bk - austmus discipline export
#
# this script does a full or partial export of a given discipline
# it is generally called up by dwc_spc.sh for all disciplines, but
# may also be called on an adhoc basis
#
# $0 - this script
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
#  write - $DWCDMROOT/$TMPEXD/$FNAME_EXID$1$FNAME_EXID_SUFX.gz
#
# step 3 for the filtered irn-only list, export data from emu:
#    first, write a full record with header row, matching the first couple of irns
#    next, pipe to $DWCDMROOT/convert-mapped.awk for mapping non-ambiguous ozcam-darwincore records
#    then pipe to gzip for compression before writing to disc
#  reads - $DWCDMROOT/$TMPEXD/$FNAME_IRNMOD$1
#  write - $DWCDMROOT/$TMPEXD/$FNAME_HDR$1
#  write - $DWCDMROOT/$TMPEXD/$FNAME_EXDATA$1$FNAME_EXDATA_SUFX.gz
#
# finish - write the discipline to dwcdm_finish
#  write - $DWCDMROOT/$TMPEXD/dwcdm_finish

#clear

# the names of the awk scripts that do the ozcam-darwincore mapping
EXAWKID=ozdc_id.awk
EXAWKFULL=ozdc_full.awk

#these all contribute to filenames, so must not have any invalid chars
FNAME_IRN=irn-
FNAME_HDR=hdr-
FNAME_IRNMOD=irn-mod-
FNAME_EXID=
FNAME_EXID_SUFX=-dwcid.csv
FNAME_EXDATA=
FNAME_EXDATA_SUFX=-dwcdata.csv

DWCDMROOT=$2

# set up the export directory
mkdir -vp $DWCDMROOT
pushd "$DWCDMROOT" > /dev/null

echo "#$0#$(date +%H:%M:%S)# DwC data mobilisation root is:"
echo "#$0#$(date +%H:%M:%S)#   $DWCDMROOT"

# create a temporary directory for us to work in
# directory will be bundled using gz
TMPEXD=$(mktemp -d "dm.$1.XXX");
pushd "$TMPEXD" > /dev/null

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
echo irn_1,AdmDateInserted,AdmTimeInserted,AdmDateModified,AdmTimeModified,CatPrefix,CatRegNumber,CatSuffix,CatCollectionName > "$FNAME_IRN$1"
# write the data rows... (note 'append':  >> irn-$1)
echo select irn_1,AdmDateInserted,AdmTimeInserted,AdmDateModified,AdmTimeModified,CatPrefix,CatRegNumber,CatSuffix,CatCollectionName_tab[CatCollectionName] from ecatalogue where exists \( CatCollectionName_tab where CatCollectionName = \'$1\' \) | texql -R | tr -d \'\(\)\[\] >> "$FNAME_IRN$1"

##### 2 #####
# write the irn-list with last modified > $3 (texexport filter)
# also convert currently public 'last modified' list to ozcam-darwincore

echo "#$0#$(date +%H:%M:%S)# 2 - writing '$DWCDMROOT/$TMPEXD/$FNAME_IRNMOD$1'"

# only if we've been instructed to do a delta...
if [ "$3" != '' ]
then
	# ***WARNING*** (this instruction is brittle; it *should* do a lookup for values on field names, but it doesn't...)
	# this step requires irn_1 to be at $1 -
	#  if irn_1 changes position, you will need to modify any 'print $1' instructions
	# this step also requires AdmDateModified to be at $4, and AdmTimeModified to be at $5
	#  if these data change positions, you need to modify the next line to reflect that:
	#  - $4 reference: ... cnt++; idmparts = split($4,arrdm,"/") ...
	#  - $5 reference: ... arrdm[1] " " $5 "\" +%s ...
	#  - full line at time of comment: cat "irn-$1" | awk -F"," 'BEGIN{cnt=-1}; { if(-1 == cnt) cnt=0; else { cnt++; idmparts = split($4,arrdm,"/"); if(3 == idmparts) { scmd = "date -d \"" arrdm[3] "/" arrdm[2] "/" arrdm[1] " " $5 "\" +%s 2>/dev/null"; printf($1 " "); (ssecs = system(scmd)); } } };' |  awk -v ssince="$3" -v dtsince=$(date -d "$3" +%s 2>/dev/null) -F' ' 'BEGIN{if(!dtsince || ("" == ssince))dtsince=0;};{if($2>dtsince) print $1; };' > "irn-mod-$1"
	#
	cat "$FNAME_IRN$1" | awk -F"," 'BEGIN{cnt=-1}; { if(-1 == cnt) cnt=0; else { cnt++; idmparts = split($4,arrdm,"/"); if(3 == idmparts) { scmd = "date -d \"" arrdm[3] "/" arrdm[2] "/" arrdm[1] " " $5 "\" +%s 2>/dev/null"; printf($1 " "); (ssecs = system(scmd)); } } };' |  awk -v ssince="$3" -v dtsince=$(date -d "$3" +%s 2>/dev/null) -F' ' 'BEGIN{if(!dtsince || ("" == ssince))dtsince=0;};{if($2>dtsince) print $1; };' > "$FNAME_IRNMOD$1"

# otherwise, this is a bit quicker...
else
	# ***WARNING*** (this instruction is brittle; it *should* do a lookup for values on field names, but it doesn't...)
	# this step requires irn_1 to be at $1 -
	#  if irn_1 changes position, you will need to modify any 'print $1' instructions
	cat "$FNAME_IRN$1" | awk -F"," 'BEGIN{cnt=-1}; {if(-1==cnt) cnt=0; else print $1;}' > "$FNAME_IRNMOD$1"
fi

echo "#$0#$(date +%H:%M:%S)# 2 - writing '$DWCDMROOT/$TMPEXD/$FNAME_EXID$1$FNAME_EXID_SUFX.gz'"

cat "$FNAME_IRN$1" | awk -F"," -v _dbg_out_file="$DWCDMROOT/$TMPEXD/$EXAWKID.log" -f "$DWCDMROOT/$EXAWKID" | iconv -f iso-8859-1 -t UTF8 | gzip -8 >> "$FNAME_EXID$1$FNAME_EXID_SUFX.gz"
#cat "$FNAME_IRN$1" | awk -F"," -v _dbg_out_file="$DWCDMROOT/$TMPEXD/$EXAWKID.log" -f "$DWCDMROOT/$EXAWKID" | iconv -f iso-8859-1 -t UTF8 | gzip -8 >> "$FNAME_EXID$1.csv.gz"
#cat "$FNAME_IRN$1" | awk -F"," -v _dbg_out_file="$DWCDMROOT/$TMPEXD/$EXAWKID.log" -f "$DWCDMROOT/$EXAWKID" | gzip -8 >> "$FNAME_EXID$1.csv.gz"


##### 3 #####
# for the filtered irn-only list, export data from emu

echo "#$0#$(date +%H:%M:%S)# 3 - writing '$DWCDMROOT/$TMPEXD/$FNAME_EXDATA$1$FNAME_EXDATA_SUFX.gz'"

head -n 10 "$FNAME_IRNMOD$1" | texexport -k- -fdelimited -ms"+|" -md"" -mc ecatalogue > "$FNAME_HDR$1"

cat "$FNAME_IRNMOD$1" | texexport -k- -fdelimited -ms"+|" -md"" -mc ecatalogue | awk -F"[+][|]" -v _dbg_out_file="$DWCDMROOT/$TMPEXD/$EXAWKFULL.log" -f "$DWCDMROOT/$EXAWKFULL" | iconv -f iso-8859-1 -t UTF8 | gzip -8 >> "$FNAME_EXDATA$1$FNAME_EXDATA_SUFX.gz"
#cat "$FNAME_IRNMOD$1" | texexport -k- -fdelimited -ms"+|" -md"" -mc ecatalogue | awk -F"[+][|]" -v _dbg_out_file="$DWCDMROOT/$TMPEXD/$EXAWKFULL.log" -f "$DWCDMROOT/$EXAWKFULL" | iconv -f iso-8859-1 -t UTF8 | gzip -8 >> "$FNAME_EXDATA$1.csv.gz"
#cat "$FNAME_IRNMOD$1" | texexport -k- -fdelimited -ms"+|" -md"" -mc ecatalogue | awk -F"[+][|]" -v _dbg_out_file="$DWCDMROOT/$TMPEXD/$EXAWKFULL.log" -f "$DWCDMROOT/$EXAWKFULL" | gzip -8 >> "$FNAME_EXDATA$1.csv.gz"

echo "#$0#$(date +%H:%M:%S)# 3 - finished"

echo $1 > "$DWCDMROOT/$TMPEXD/dwcdm_finish"

