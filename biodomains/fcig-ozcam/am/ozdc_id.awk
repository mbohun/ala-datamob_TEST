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

# AM ozcam/darwincore identifier mapping
#
# v6: 20120503: bk - fixed copy & paste bug around new ozcam lsid pattern
# v5: 20120419: bk - updated to conform to ozcam lsid pattern
# v4: 20111011: bk - fixed error in logic, special char escaping in sretprint
# v3: 20110914: bk - debug prints to file spec'd on command line
# v2: 20110803: bk - modified to export identifier input only
# v1: 20110510: bk - phase 2 dm release
#
# see ozdc_full.awk for more detail
#
# at the beginning of the command...
BEGIN {
#	number of fields encountered (if header row has been mapped)
	cntfields = -1;
#	number of records encountered
	cntirec = 0;
#	number of error-records encountered (record fields don't match header row - ambiguity)
	cnterr = 0;

# 	when the header row is analysed, source indices will be stored in this array
	#arrsSourceIndex[""] = "";
};

# for each line:
#     if it the header row, sets the mapping & field count
#     otherwise, if the field count is off, warn of the ambiguity & drop the record
#     otherwise, if the field count matches, do the mapping
#
{

#	header/first row -
# fill the source array & determine field count (template) that will be followed
  if( cntfields == -1 ) {
    cntfields = NF;

if( _dbg_out_file != "" ) {
printf( "\nScanning %d fields (read header row)\n - non-matching records will be disregarded\n", cntfields ) > _dbg_out_file;
}

    i = 1;

#   loop through the records on line 1 (header row)
    for( i=1; i<=cntfields; i++ ) {
#		add the column & index to the source arrays
		arrsSourceIndex[$i] = i;
#if( _dbg_out_file != "" ) {
#printf( "%d - %s - %s\n", i, $i, s ) >> _dbg_out_file;
#}
    }

#break;

if( _dbg_out_file != "" ) {
printf( "\nWriting valid records as mapped" ) >> _dbg_out_file;
}

# print header [search file for '^print.*#([a-zA-Z,]*?)\r'
# irn_1,AdmDateInserted,AdmTimeInserted,AdmDateModified,AdmTimeModified,CatRegNumber,CatDiscipline
printf( "\"institutionCode\",\"basisOfRecord\",\"dcterms:type\",\"collectionCode\",\"dcterms:modified\",\"occurrenceID\",\"catalogNumber\",\"otherCatalogNumbers\"" );

printf( "\n" );

  }

# error record is ambiguous -
# there is a delimiter string included in the textual data somewhere
# this means that awk can't determine the field boundaries with certainty
  else if( NF != cntfields ) {
if( _dbg_out_file != "" ) {
printf(" ! %6d [%4d] - %.55s\n", NR, NF, $LINE) >> _dbg_out_file;
}
    cnterr += 1;
  }

# if we have a valid record (not ambiguous - fields clearly delineated)
  else if(NF == cntfields) {
    cntirec++;

# print out a single record, formatted accordingly
# it would be nice to do this automagically from the mapping array
# however, can't pass an array reference as the variables for printf
# need to use printf (or concatenation of some form) so we can handle
# composite source-values mapping to a single target field

#gsub( /\"/, "\\\"", sGetValue("irn:1") );  # escape double-quotes


printf( "\"AM\"" ); 														#institutionCode
printf( ",\"PreservedSpecimen\"" ); 										#basisOfRecord
printf( ",\"PhysicalObject\"" ); 											#dcterms:type
printf( ",\"%s\"",      department ); 					#collectionCode
printf( ",\"%s\"", sRetPrint("AdmDateModified") ); 							#dcterms:modified
#old, non-compliant: printf( ",\"urn:catalog:AM:%s:%s\"", sRetPrint("CatDiscipline"), sRetPrint("CatRegNumber") );
#agreed lsid-pattern: urn:lsid:ozcam.taxonomy.org.au:[Institution Code]:[Collection code]:[Basis of Record](optional):[Catalog Number]:[Version](optional)
printf( ",\"urn:lsid:ozcam.taxonomy.org.au:AM:%s:%s\"", department, sRetPrint("CatRegNumber") );    #occurrenceID
printf( ",\"%s\"", sRetPrint("CatRegNumber") ); 							#catalogNumber
#old, without non-compliant lsid: printf( ",\"ecatalogue.irn:%s\"", sRetPrint("irn_1") );
printf( ",\"ecatalogue.irn:%s; urn:catalog:AM:%s:%s\"", sRetPrint("irn_1"), department, sRetPrint("CatRegNumber") );  #otherCatalogNumbers

printf( "\n" );

if( _dbg_out_file != "" ) {
if( (cntirec % 500) == 0 )
  printf( " %d,", NR ) >> _dbg_out_file;
}

# it's a shame this doesn't work;
#
#arrx[1] = 1;
#arrx[2] = 2;
#arrx[3] = 3;
#arrx[4] = 4;
#printf( "%d,%d,%d,%d", $$arrx );
#


  }
}

# after looking at each line...
END {
if( _dbg_out_file != "" ) {
printf( "\n%d records checked : %d ambiguities found : %d records written\n", (NR-1), cnterr, cntirec ) >> _dbg_out_file;
}
}



# escapes any column wrappers (double-quotes) found within 'sind'
# if requested (bwrap = 1) then will also wrap the result in escaped dq's
function sRetPrint( sind, bwrap ) {

#if( _dbg_out_file != "" ) {
#printf( "%s - %d\n", sind, (sind in arrsSourceIndex) ) >> _dbg_out_file;
#}

	# check to see if the field-name has been mapped to an index
	if( sind in arrsSourceIndex ) {

		#old way - direct reference to index
		#old: s = $arrsSourceIndex[sind];
		# now we use sGetValue to ensure consistency...
		s = sGetValue( sind );

		# if there is a value, replace characters to avoid csv ambiguities
		if( s != "" ) {

#if( _dbg_out_file != "" ) {
#printf( "%s - %d\n", s, (sind in arrsSourceIndex) ) >> _dbg_out_file;
#}

			# snag here - trying to ignore \" and replace all "
			# " at start of field's value was not being escaped, causing problematic output in csv
			#old: do igsubdq = sub(/[^\\][\"]/, "\\\"", s);
			#old: while( igsubdq > 0 );
			# - or -
	    #old: igsubdq = gsub( /[^\\]\"/, "\\\"", s );
	    #old: igsubdq = gsub( /;/, "\\;", s );
	
			# answer is to convert all \" to " first, then escape all " again
			# (this will catch all of the unescaped as well as the escaped)
			igsubdq = gsub( /[\\][\"]/, "\"", s );
			igsubdq = gsub( /[\"]/, "\\\"", s );
			
			# outstanding question: should we unescape in a loop to handle the following cases?
			#  \\" \\\\\"
			# or will gsub iterate? my gut feeling is "no it won't", but, is it right to unescape
			# data further than required, or are we getting into the realm of changing the source data?

			# because we are following json rules, semi-colon [;] is special
			# therefore, we should escape any of these as well
			# comment next line to disabled this behaviour...
			igsubdq = gsub( /;/, "\\;", s );

			# most csv parsers already ignore nested commas [,]
			# uncomment next line to escape these as well...
			#igsubdq = gsub( /,/, "\\,", s );

#if( _dbg_out_file != "" ) {
#printf( "%s - 2\n", s ) >> _dbg_out_file;
#}
		}
	
		# if we've been instructed to, wrap the result in double-quotes ["]
		if( bwrap == 1 ) {
			s = "\\\"" s "\\\"";
		}
	}

	# if the field is not found in the source mapping, return an empty string
	else {
		s = "";
	}

  # outstanding question: should we wrap an empty result if we've been instructed to?
  # if yes, would need to move the above bwrap==1 test to here

	return s;
}

# returns the record's value of field sind, if it exists
function sGetValue( sind ) {
#	this record's field is empty...
	s = "";

# 	unless the field-name has been mapped to an index in the header
	if( sind in arrsSourceIndex ) {
		s = $arrsSourceIndex[sind];
	}

	return s;
}
