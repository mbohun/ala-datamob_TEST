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

# AM ozcam/darwincore mapping
#
# v5.1AM 20121116: mh - added "Coordinate Uncertainty in Metres" field
# v5: 20120419: bk - updated to conform to ozcam lsid pattern
# v4: 20111011: bk - fixed error in logic, special char escaping in sretprint
# v3: 20110914: bk - debug prints to file spec'd on command line
# v2: 20110803: bk - modified header row, inst.Code, basisOfRecord, dcterms:type, coll.Code, verb.EventDate, catalogNumber, otherCat.Numbers, assoc.Media
# v1: 20110510: bk - phase 2 dm release
#
# - this script maps an emu texexport output to a darwincore csv
# - it is designed to run within awk
# - awk calls the BEGIN {} code-block once at the start, {} for each row, and END {} at the end
# - in the first {} iteration, it stores the ordinal position (index) of each field-name in an array: arrsSourceIndex
# - in subsequent iterations, a field-value could be referenced via $arrsSourceIndex["field"]... 
#   ... BUT it is important not to use this structure without testing for the key's existence in the array first
#   ... otherwise, that non-existant key will be added to the array, which could cause problems later - ie, the array is read-only
#
# - use the following functions instead:
#  - sGetValue( sind ) : 
#       where sind is the "field name"
#       returns "field value" or "" if field doesn't exist
#  - sRetPrint( sind, bwrap )
#       where sind is the "field name", and bwrap = 1 or 0/undefined
#       returns "field value" or "" if field doesn't exist
#      "field value" has chars "\; escaped with a leading \ (if not already escaped)
#      if bwrap == 1, then the escaped result will also be wrapped in \" - eg: "\"field value\""

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


	while (getline < image_file)
	{
	split($0,ft,"\t");
	mmirn=ft[1];
	photographer=ft[2];
	rightholder=ft[3];
	photographers[mmirn]=photographer;
	rightholders[mmirn]=rightholder;
	}
	close(image_file);
	
	for (irn in photographers) { printf("%s\t%s\n",irn,photographers[irn]) > (image_file ".check") } ;

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
printf( "\"institutionCode\",\"basisOfRecord\",\"dcterms:type\",\"collectionCode\",\"scientificName\",\"acceptedNameUsage\",\"nameAccordingTo\",\"typeStatus\",\"kingdom\",\"phylum\",\"class\",\"order\",\"family\",\"genus\",\"specificEpithet\",\"vernacularName\",\"verbatimTaxonRank\",\"identifiedBy\",\"dateIdentified\",\"identificationRemarks\",\"waterBody\",\"country\",\"stateProvince\",\"county\",\"verbatimLocality\",\"decimalLatitude\",\"verbatimLatitude\",\"decimalLongitude\",\"verbatimLongitude\",\"coordinatePrecision\",\"verbatimCoordinateSystem\",\"locationRemarks\",\"eventID\",\"eventDate\",\"verbatimEventDate\",\"eventTime\",\"dcterms:modified\",\"samplingProtocol\",\"habitat\",\"occurrenceID\",\"catalogNumber\",\"recordedBy\",\"otherCatalogNumbers\",\"sex\",\"preparations\",\"associatedMedia\",\"photographer\",\"rightsHolder\",\"verbatimUncertainty\",\"coordinateUncertaintyInMeters\"" );
printf( "\n" );

  }

# error record is ambiguous -
# there is a delimeter string included in the textual data somewhere
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


###############
# WHAT ########
###############

# there can be multiple identifications - need to choose the one which is current (IdeCurrentId is "Yes")
# and ignore historical identifications e.g. if IdeCurrentId:6 is "Yes" then set ideindex to "6" and
# use this to retrieve data from the correct identification fields (IdeScientificNameLocal, etc)
# As of May 2013 there are 20 IdeCurrentId fields
ideindex = "1"
for(i=1;i<21;i++) {
  idecurrent = "IdeCurrentId:" i;
  if (sRetPrint(idecurrent) == "Yes") {ideindex=i;dateideindex=i-1;break}
}


printf( ",\"%s\"", 		sRetPrint("IdeScientificNameLocal:" ideindex ) ); 			#scientificName
printf( ",\"%s\"", 		sRetPrint("IdeQualifiedName:"ideindex ) ); 					#acceptedNameUsage
printf( ",\"%s\"", 		sRetPrint("IdeAuthorStringLocal:" ideindex ) ); 				#nameAccordingTo


# instead of using CitTypeStatus1 use concatenated CitTypeStatusCitationsCombine fields
# As of July 2013 there are 40 CitTypeStatusCitationsCombine fields (mostly empty, some with duplicate values)
# e.g.:
# CitTypeStatusCitationsCombine:1=10024300: Syntypes: Epigrus protractus Hedley, 1904 : : : Gastropoda : Mollusca
# want also to remove the leading numeric id and colon (i.e. "10024300: ")

ctsindex = "1"
for(i=1;i<40;i++) {
  ctscurrent = "CitTypeStatusCitationsCombine:" i;
  cts = sRetPrint(ctscurrent);
  if ( cts != "") { 
    sub( /^[0123456789]+: +/,"",cts); #strip leading cruft
    if ( cts !~ /^:/ ) { # want the first colon-delimited field to be a string (like "holotype") so disregard if empty
      ctsarray[cts] = 1;
    }
  }
}
typestatus = "";
for ( cts in ctsarray ) {
  typestatus = (typestatus cts ";") ;
}
delete ctsarray;
sub( /;$/,"",typestatus); #strip trailing semicolon
printf( ",\"%s\"", 		typestatus ); 					#typeStatus




printf( ",\"%s\"", 		sRetPrint("IdeKingdomLocal:" ideindex ) ); 					#kingdom
printf( ",\"%s\"", 		sRetPrint("IdePhylumLocal:" ideindex ) ); 					#phylum
printf( ",\"%s\"", 		sRetPrint("IdeClassLocal:" ideindex ) ); 					#class
printf( ",\"%s\"", 		sRetPrint("IdeOrderLocal:" ideindex ) ); 					#order
printf( ",\"%s\"", 		sRetPrint("IdeFamilyLocal:" ideindex ) ); 					#family
printf( ",\"%s\"", 		sRetPrint("IdeGenusLocal:" ideindex ) ); 					#genus
printf( ",\"%s\"", 		sRetPrint("IdeSpeciesLocal:" ideindex ) ); 					#specificEpithet
#sGetValue("ConKindOfObject:1")
printf( ",\"%s\"", 		sRetPrint("QuiTaxonomyCommonName:1") ); 			#vernacularName
printf( ",\"%s\"", 		sRetPrint("IdeQualifierRank:" ideindex ) ); 					#verbatimTaxonRank

printf( ",\"%s\"", 		sRetPrint("IdeIdentifiedByLocal:" ideindex ) ); 				#identifiedBy

# the date identified field names have the form IdeDateIdentifiedX:[123]
# where 1,2,3 are I think year, month, date
# and X is the index we use for the current identification
# unbelievably though, X here is zero based, so we need to subtract 1 from ideindex to get dateideindex (above)
sdateid = "";
if( sGetValue("IdeDateIdentified" dateideindex ":1") != "" ) {
  sdateid = sRetPrint("IdeDateIdentified" dateideindex ":1");
  if( sGetValue("IdeDateIdentified" dateideindex ":2") != "" ) {
    sdateid = sdateid "-" sRetPrint("IdeDateIdentified" dateideindex ":2");
    if( sGetValue("IdeDateIdentified" ideindex ":3") != "" ) {
      sdateid = sdateid "-" sRetPrint("IdeDateIdentified" dateideindex ":3");
    }
  }
}
printf( ",\"%s\"", 		sdateid ); 											#dateIdentified

sidremarks = "";
if( sGetValue("IdeConfidence:" ideindex ) != "" )
  sidremarks = sidremarks "ecatalogue.IdeConfidence: " sRetPrint("IdeConfidence:" ideindex, 1) "; ";
if( sGetValue("IdeSpecimenQuality:1") != "" )
  sidremarks = sidremarks "ecatalogue.IdeSpecimenQuality: " sRetPrint("IdeSpecimenQuality:1", 1) "; ";
if( sGetValue("IdeComments:" ideindex) != "" )
  sidremarks = sidremarks "ecatalogue.IdeComments: " sRetPrint("IdeComments:" ideindex, 1) "; ";
printf( ",\"%s\"",		sidremarks ); 										#identificationRemarks


###############
# WHERE #######
###############
printf( ",\"%s\"",		sRetPrint("BioOceanLocal:1") ); 					#waterBody
printf( ",\"%s\"",		sRetPrint("BioCountryLocal:1") ); 					#country
printf( ",\"%s\"",		sRetPrint("QuiProvinceStateLocal:1") ); 			#stateProvince
printf( ",\"%s\"",		sRetPrint("BioDistrictCountyShireLocal:1") ); 		#county
printf( ",\"%s\"",		sRetPrint("QuiPreciseLocationLocal:1") ); 			#verbatimLocality


slat = ""; sfmtlat = "";
ddlat = 0.0; ddd = 0.0; ddm = 0.0; dds = 0.0;
if( sGetValue("BioPreferredCentroidLatitude:1") != "" ) {
  slat = slat sRetPrint("BioPreferredCentroidLatitude:1") "\B0 ";
  ddd = sGetValue("BioPreferredCentroidLatitude:1");
}
if( sGetValue("BioPreferredCentroidLatitude:2") != "" ) {
  slat = slat sRetPrint("BioPreferredCentroidLatitude:2") "\' ";
  ddm = sGetValue("BioPreferredCentroidLatitude:2");
}
if( sGetValue("BioPreferredCentroidLatitude:3") != "" ) {
  slat = slat sRetPrint("BioPreferredCentroidLatitude:3") "\\\" ";
  dds = sGetValue("BioPreferredCentroidLatitude:3");
}
# truncate...
# ... to 5 decimal places
if( dds > 0 ) {
	ddlat = ( ddd + (int((ddm * 100000) / 60) / 100000) + (int((dds * 100000) / 3600) / 100000) );
	sfmtlat = "%3.5f";
}
# ... to 3 decimal places
else if( ddm > 0 ) {
	ddlat = ( ddd + (int((ddm * 1000) / 60) / 1000) );
	sfmtlat = "%3.3f";
}
# ... to 1 decimal place
else if( ddd > 0 ) {
	ddlat = ( (int((ddd * 10)) / 10) );
	sfmtlat = "%3.1f";
}
# check to see if we're in the southern hemisphere...
if( sGetValue("BioPreferredCentroidLatitude:4") != "" ) {
  slat = slat sRetPrint("BioPreferredCentroidLatitude:4");

  if( sGetValue("BioPreferredCentroidLatitude:4") == "S" )
  	ddlat = -(ddlat);
}
# write dd to sd
if( (ddlat == 0.0) )
	sdlat = "";
else
	sdlat = sprintf( sfmtlat, ddlat );
# write decimal & verbatim values
printf( ",\"%s\",\"%s\"",	sdlat, slat ); 									#decimalLatitude,verbatimLatitude

slon = ""; sfmtlon = "";
ddlon = 0.0; ddd = 0.0; ddm = 0.0; dds = 0.0;
if( sGetValue("BioPreferredCentroidLongitude:1") != "" ) {
  slon = slon sRetPrint("BioPreferredCentroidLongitude:1") "\B0 ";
  ddd = sGetValue("BioPreferredCentroidLongitude:1");
}
if( sGetValue("BioPreferredCentroidLongitude:2") != "" ) {
  slon = slon sRetPrint("BioPreferredCentroidLongitude:2") "\' ";
  ddm = sGetValue("BioPreferredCentroidLongitude:2");
}
if( sGetValue("BioPreferredCentroidLongitude:3") != "" ) {
  slon = slon sRetPrint("BioPreferredCentroidLongitude:3") "\\\" ";
  dds = sGetValue("BioPreferredCentroidLongitude:3");
}
# truncate...
# ... to 5 decimal places
if( dds > 0 ) {
	ddlon = ( ddd + (int((ddm * 100000) / 60) / 100000) + (int((dds * 100000) / 3600) / 100000) );
	sfmtlon = "%3.5f";
}
# ... to 3 decimal places
else if( ddm > 0 ) {
	ddlon = ( ddd + (int((ddm * 1000) / 60) / 1000) );
	sfmtlon = "%3.3f";
}
# ... to 1 decimal place
else if( ddd > 0 ) {
	ddlon = ( (int((ddd * 10)) / 10) );
	sfmtlon = "%3.1f";
}
# check to see if we're in the southern hemisphere...
if( sGetValue("BioPreferredCentroidLongitude:4") != "" ) {
  slon = slon sRetPrint("BioPreferredCentroidLongitude:4");

  if( sGetValue("BioPreferredCentroidLongitude:4") == "W" )
  	ddlon = -(ddlon);
}
# write dd to sd
if( (ddlon == 0.0) )
	sdlon = "";
else
	sdlon = sprintf( sfmtlon, ddlon );
# write decimal & verbatim values
printf( ",\"%s\",\"%s\"", sdlon, slon ); 									#decimalLongitude,verbatimLongitude

if ( (sfmtlat == "%3.5f") || (sfmtlon == "%3.5f") )  { coordpr = "0.00001" } 
else if ( (sfmtlon == "%3.3f") || (sfmtlat == "%3.3f") ) { coordpr = "0.001" }
else if ( (sfmtlat == "%3.1f") || (sfmtlon == "%3.1f") ) { coordpr = "0.1" }
else coordpr = "";


printf( ",\"%s\"", coordpr); 		#coordinatePrecision

printf( ",\"%s\"", sRetPrint("QuiLatLongDetermination:1") ); 		#verbatimCoordinateSystem

slocremarks = "";
if( sGetValue("LocCollectionEventLocal:1") != "" )
  slocremarks = slocremarks "ecatalogue.LocCollectionEventLocal: " sRetPrint("LocCollectionEventLocal:1", 1) "; "; #sGetValue("LocCollectionEventLocal:1")
if( sGetValue("BioTopographyLocal:1") != "" )
  slocremarks = slocremarks "ecatalogue.BioTopographyLocal: " sRetPrint("BioTopographyLocal:1", 1) "; ";
if( sGetValue("SqsSiteName:1") != "" )
  slocremarks = slocremarks "ecatalogue.SqsSiteName: " sRetPrint("SqsSiteName:1", 1) "; ";
if( sGetValue("SqsCityTown:1") != "" )
  slocremarks = slocremarks "ecatalogue.SqsCityTown: " sRetPrint("SqsCityTown:1", 1) "; ";
printf( ",\"%s\"", 			slocremarks ); 									#locationRemarks



###############
# WHEN  #######
###############
seventid = "";
if( sGetValue("ColCollectionEventsRef:1") != "" )
  seventid = "urn:australianmuseum.net.au:Events:" sRetPrint("ColCollectionEventsRef:1");
printf( ",\"%s\"",												seventid );	#eventID

sevtdate = "";
sverbevtdate = "";
if( sGetValue("LocDateCollectedFrom:1") != "" ) {
  sevtdate = sRetPrint("LocDateCollectedFrom:1");
  if( sGetValue("LocDateCollectedFrom:2") != "" ) {
    sevtdate = sevtdate "-" sprintf("%02d", sRetPrint("LocDateCollectedFrom:2"));
    if( sGetValue("LocDateCollectedFrom:3") != "" ) {
      sevtdate = sevtdate "-" sprintf("%02d", sRetPrint("LocDateCollectedFrom:3"));

      bdelim = 0;
		if( (sGetValue("LocDateCollectedTo:1") != "") && (sGetValue("LocDateCollectedTo:1") != sGetValue("LocDateCollectedFrom:1")) ) {
			sevtdate = sevtdate "/" sRetPrint("LocDateCollectedTo:1");
			bdelim = 1;
		}
		if( (sGetValue("LocDateCollectedTo:2") != "") && (sGetValue("LocDateCollectedTo:2") != sGetValue("LocDateCollectedFrom:2")) ) {
			if( bdelim == 0 ) {
				bdelim = 1;
				sevtdate = sevtdate "/" sprintf("%02d", sRetPrint("LocDateCollectedTo:2"));
			}
			else {
				sevtdate = sevtdate "-" sprintf("%02d", sRetPrint("LocDateCollectedTo:2"));
			}
		}
		if( (sGetValue("LocDateCollectedTo:3") != "") && (sGetValue("LocDateCollectedTo:3") != sGetValue("LocDateCollectedFrom:3")) ) {
			if( bdelim == 0 ) {
				bdelim = 1;
				sevtdate = sevtdate "/" sprintf("%02d", sRetPrint("LocDateCollectedTo:3"));
			}
			else {
				sevtdate = sevtdate "-" sprintf("%02d", sRetPrint("LocDateCollectedTo:3"));
			}
		}
    }
  }
}

# originally, verbatimEventDate was only populated if eventDate was empty
# then, it was interesting info so included it for all records
# now: CatDateCatalogued is no longer included in exports;
#
#if( sevtdate == "" ) {
#  bdelim = 0;
#  if( (sGetValue("CatDateCatalogued:1") != "") ) {
#	  sverbevtdate = sverbevtdate sRetPrint("CatDateCatalogued:1");
#	  bdelim = 1;
#	}
#	if( (sGetValue("CatDateCatalogued:2") != "") ) {
#	  if( bdelim == 0 ) {
#	  	bdelim = 1;
#	    sverbevtdate = sverbevtdate "/" sRetPrint("CatDateCatalogued:2");
#	  }
#	  else {
#	    sverbevtdate = sverbevtdate "-" sRetPrint("CatDateCatalogued:2");
#    }
#  }
#	if( (sGetValue("CatDateCatalogued:3") != "") ) {
#	  if( bdelim == 0 ) {
#	  	bdelim = 1;
#	    sverbevtdate = sverbevtdate "/" sRetPrint("CatDateCatalogued:3");
#	  }
#	  else {
#	    sverbevtdate = sverbevtdate "-" sRetPrint("CatDateCatalogued:3");
#    }
#  }
#  if( sverbevtdate != "" ) {
#  	sverbevtdate = "ecatalogue.CatDateCatalogued: " sverbevtdate ";";
#  }
#}
#
sverbevtdate = "";
printf( ",\"%s\",\"%s\"",				sevtdate, sverbevtdate ); 			#eventDate,verbatimEventDate

sevttime = "";
if( sGetValue("LocTimeCollectedFrom:1") != "" ) {
  sevttime = sRetPrint("LocTimeCollectedFrom:1");
  if( sGetValue("LocTimeCollectedFrom:2") != "" ) {
    sevttime = sevttime ":" sRetPrint("LocTimeCollectedFrom:2");
    if( sGetValue("LocTimeCollectedFrom:3") != "" ) {
      sevttime = sevttime ":" sRetPrint("LocTimeCollectedFrom:3");

      bdelim = 0;
			if( (sGetValue("LocTimeCollectedTo:1") != "") && (sGetValue("LocTimeCollectedTo:1") != sGetValue("LocTimeCollectedFrom:1")) ) {
			  sevttime = sevttime ":" sRetPrint("LocTimeCollectedTo:1");
			  bdelim = 1;
			}
			if( (sGetValue("LocTimeCollectedTo:2") != "") && (sGetValue("LocTimeCollectedTo:2") != sGetValue("LocTimeCollectedFrom:2")) ) {
			  if( bdelim == 0 ) {
			  	bdelim = 1;
			    sevttime = sevttime ":" sRetPrint("LocTimeCollectedTo:2");
			  }
			  else {
			    sevttime = sevttime ":" sRetPrint("LocTimeCollectedTo:2");
		    }
		  }
			if( (sGetValue("LocTimeCollectedTo:3") != "") && (sGetValue("LocTimeCollectedTo:3") != sGetValue("LocTimeCollectedFrom:3")) ) {
			  if( bdelim == 0 ) {
			  	bdelim = 1;
			    sevttime = sevttime ":" sRetPrint("LocTimeCollectedTo:3");
			  }
			  else {
			    sevttime = sevttime ":" sRetPrint("LocTimeCollectedTo:3");
		    }
		  }
    }
  }
}
printf( ",\"%s\"",						sevttime ); 						#eventTime


sdtmod = "";
if( (sGetValue("AdmDateModified:1") != "") ) {
	sdtmod = sdtmod sRetPrint("AdmDateModified:1");

	if( (sGetValue("AdmDateModified:2") != "") ) {
		sdtmod = sdtmod "/" sRetPrint("AdmDateModified:2");

		if( (sGetValue("AdmDateModified:3") != "") ) {
			sdtmod = sdtmod "/" sRetPrint("AdmDateModified:3");
		}
	}
}
printf( ",\"%s\"", 						sdtmod ); 							#dcterms:modified


###############
# INFO  #######
###############
printf( ",\"%s\"", sRetPrint("LocCollectionMethod:1") ); 					#samplingProtocol
printf( ",\"%s\"", sRetPrint("BioMicrohabitatDescription:1") ); 			#habitat
#old, non-compliant: printf( ",\"urn:catalog:AM:%s:%s\"", sRetPrint("CatDiscipline:1"), sRetPrint("CatRegNumber:1") );
#agreed lsid-pattern: urn:lsid:ozcam.taxonomy.org.au:[Institution Code]:[Collection code]:[Basis of Record](optional):[Catalog Number]:[Version](optional)
printf( ",\"urn:lsid:ozcam.taxonomy.org.au:AM:%s:%s\"", department, sRetPrint("CatRegNumber:1") ); #occurrenceID
printf( ",\"%s\"", sRetPrint("CatRegNumber:1") ); 							#catalogNumber
printf( ",\"%s\"", sRetPrint("BioParticipantLocal:1") ); 					#recordedBy
printf( ",\"ecatalogue.irn:%s; urn:catalog:AM:%s:%s\"", sRetPrint("irn:1"), department, sRetPrint("CatRegNumber:1") );  #otherCatalogNumbers
printf( ",\"%s\"", sRetPrint("ZooSex:1") ); 								#sex

sprep = "";
if( sGetValue("PrePrepDescription:1") != "" )
  sprep = sprep "ecatalogue.PrePrepDescription: " sRetPrint("PrePrepDescription:1", 1) "; ";
if( sGetValue("PreStorageMedium:1") != "" )
  sprep = sprep "ecatalogue.PreStorageMedium: " sRetPrint("PreStorageMedium:1", 1) "; ";
printf( ",\"%s\"", 												sprep ); 	#preparations

#only print associated media if photographer and rightholder is available
mmirn=sGetValue("MulMultiMediaRef:1");
photographer=photographers[mmirn];
rightholder=rightholders[irn];
if((photographer == "") || (rightholder=="")) {mmirn="";photographer="";rightholder=""} else {mmirn=("http://collections.australianmuseum.net.au/amweb/objects/am/webmedia.php?irn=" mmirn)}; 

printf( ",\"%s\"", mmirn );						#associatedMedia
printf( ",\"%s\"", photographer );						#photographer
printf( ",\"%s\"", rightholder );						#rightholder

#add Coordinate Uncetrtainly in Metres
#Matthew 16 Nov 2012
qrv1 = sGetValue("QuiRadiusVerbatim:1"); # this should be e.g. "10km-100km" or "0m-10m" or "unknown". We just want to keep the higher value (assume its the last number given)
printf( ",\"%s\"", qrv1 )	# verbatim uncertainty
gsub( /[kK][mM]/,"000",qrv1); #kilometers to meters
#gsub( /m/,"",qrv1); # retain digits only
sub( /[^0123456789]+$/,"",qrv1); #strip trailing nondigit characters
sub( /^.*[^0123456789]+/,"",qrv1); #strip leading nondigit characters

printf( ",\"%s\"", qrv1 )	# coordinate uncertainty in meters
#printf( ",\"%s\"", gsub( /10/,"FOO",sRetPrint("QuiRadiusVerbatim:1") ) );


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

