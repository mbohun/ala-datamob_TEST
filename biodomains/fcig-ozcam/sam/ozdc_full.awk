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

# SAM ozcam/darwincore specimens mapping
#
# CAUTION : field names are not quite the same as in ozdc_id.awk
# reason is, source of data are two separate commands - beware of copy & paste
#
# v12: 20130131: bk - added 'coordinate precision' and fixed 'event date' leading zero in months
# v11: 20121130: bk - checked for null regnumber
# v10: 20121121: bk - added logic to properly handle '.SUFFIX' in lsid
# v9: 20120426: bk - updated 'occurrence id' to fcig-agreed lsid pattern & populated non-dwc terms 'principal record' & 'parent record' (see: http://code.google.com/p/ala-datamob/wiki/RelatedRecords)
# v8: 20111102: bk - re-joined am fork: better comments & logging, opensource-licence, no-escape flag
# v7: 20110525: bk - branched for sam phase 3 dm prototype (dwc-archive)
# v6: 20110523: bk - branched for sam phase 2 dm implementation
# v5: 20110407: bk - phase 2 dm implementation - ozcam-dwc mapping, sftp push
# v4: 20110311: bk - branched to cater for ausmus export
#
# - this script maps an emu texexport output to a darwincore csv
# - it is designed to run within awk
# - awk calls the BEGIN {} code-block once at the start, {} for each row, and END {} at the end
# - in the first {} iteration, it stores the ordinal position (index) of each field-name in an array: arrsSourceIndex
# - in subsequent iterations, a field-value could be referenced via $arrsSourceIndex["field"]... 
#   ... BUT it is important not to use this structure without testing for the key's existence in the array first
#   ... otherwise, that non-existent key will be added to the array, which could cause problems later - ie, the array is read-only
#
# - so to avoid this problem, use the following helper functions instead:
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
# number of fields encountered (if header row has been mapped)
  cntfields = -1;
# number of records encountered
  cntirec = 0;
# number of error-records encountered (record fields don't match header row - ambiguity)
  cnterr = 0;

#   when the header row is analysed, source indices will be stored in this array
  #arrsSourceIndex[""] = "";
};

# for each line:
#     if it the header row, sets the mapping & field count
#     otherwise, if the field count is off, warn of the ambiguity & drop the record
#     otherwise, if the field count matches, do the mapping
#
{

# header/first row -
# fill the source array & determine field count (template) that will be followed
  if( cntfields == -1 ) {
    cntfields = NF;

if( _dbg_out_file != "" ) {
printf( "\nScanning %d fields (read header row)\n - non-matching records will be disregarded\n", cntfields ) > _dbg_out_file;
}

    i = 1;

#   loop through the records on line 1 (header row)
    for( i=1; i<=cntfields; i++ ) {
#   add the column & index to the source arrays
#        - when the source column needs to be referenced, it will happen by name
#        - the numerical index will then be returned at relevant points
#        - see function sRetPrint at bottom of file
      arrsSourceIndex[$i] = i;

#if( _dbg_out_file != "" ) {
#printf( "%d - %s - %s\n", i, $i, s ) >> _dbg_out_file;
#}
    }

#break;

if( _dbg_out_file != "" ) {
printf( "\nWriting valid records as mapped... " ) >> _dbg_out_file;
}

# print header [search file for '^print.*#([a-zA-Z,]*?)\r'

printf( "\"institutionCode\",\"basisOfRecord\",\"dcterms:type\",\"collectionCode\",\"scientificName\",\"acceptedNameUsage\",\"nameAccordingTo\",\"typeStatus\",\"phylum\",\"class\",\"order\",\"family\",\"genus\",\"specificEpithet\",\"infraspecificEpithet\",\"vernacularName\",\"verbatimTaxonRank\",\"identifiedBy\",\"dateIdentified\",\"identificationRemarks\",\"waterBody\",\"country\",\"stateProvince\",\"county\",\"verbatimLocality\",\"decimalLatitude\",\"verbatimLatitude\",\"decimalLongitude\",\"verbatimLongitude\",\"coordinatePrecision\",\"verbatimCoordinateSystem\",\"locationRemarks\",\"eventID\",\"eventDate\",\"verbatimEventDate\",\"eventTime\",\"dcterms:modified\",\"samplingProtocol\",\"habitat\",\"occurrenceID\",\"catalogNumber\",\"occurrenceRemarks\",\"recordedBy\",\"individualCount\",\"otherCatalogNumbers\",\"sex\",\"lifeStage\",\"preparations\",\"associatedSequences\",\"principalRecord\"" );

printf( "\n" );

  }
# end first row


# error record is ambiguous -
# there is a delimeter string included in the textual data somewhere
# this means that awk can't determine the field boundaries with certainty
# so this record will be dropped and the error reported
  else if( NF != cntfields ) {
if( _dbg_out_file != "" ) {
printf(" ! %6d [%4d] - %.55s\n", NR, NF, $LINE) >> _dbg_out_file;
}
    cnterr += 1;
  }
  
# error record has null regnum -
# we need a regnum to build an lsid/occurrence id -
# there is a circumstance, where a record exists that has not been accessioned yet
# these data are new records in holding, until the specimens they represent are formally received into the collection
  else if( ("" == sGetValue("CatRegNumber:1")) || ("NULL" == sGetValue("CatRegNumber:1")) ) {
if( _dbg_out_file != "" ) {
printf(" NULL RegNum %10d - %.55s\n", sGetValue("irn:1"), $LINE) >> _dbg_out_file;
}
    cnterr += 1;
  }

# end error record


# if we have a valid record (not ambiguous - fields clearly delineated)
  else if(NF == cntfields) {
    cntirec++;

# print out a single record, formatted accordingly
# it would be nice to do this automagically from the mapping array
# however, can't pass an array reference as the variables for printf
# need to use printf (or concatenation of some form) so we can handle
# composite source-values mapping to a single target field

#gsub( /\"/, "\\\"", sGetValue("irn:1") );  # escape double-quotes


printf( "\"SAMA\"" );                                                       #institutionCode
printf( ",\"PreservedSpecimen\"" ); 										                    #basisOfRecord
#old basisOfRecord:- this doesn't seem right to me (more like a prep); eg: 'Skeleton', 'Skeleton,Feather(s)', '(FS)C(|W)' ... #printf( ",\"%s\"",      sRetPrint("CatObjectType:1") );                    #basisOfRecord
printf( ",\"PhysicalObject\"" );                                            #dcterms:type
printf( ",\"%s\"",      sRetPrint("CatCollectionName:1") );                 #collectionCode

###############
# WHAT ########
###############

# try to find a decent scientific name...
ssciname = "";
# ... 
if( sGetValue("IdeCurrentScientificNameLocal:1") != "" )
  ssciname = sRetPrint("IdeCurrentScientificNameLocal:1");
# ... 
else if( sGetValue("IdeScientificNameLocal:1") != "" )
  ssciname = sRetPrint("IdeScientificNameLocal:1");
# ... this one is clearly a concatenation of the taxonomy
else if( sGetValue("IdeAcceptedSummaryDataLocal:1") != "" )
  ssciname = sRetPrint("IdeAcceptedSummaryDataLocal:1");
# ... as is this one
else if( sGetValue("IdeTaxonLocal:1") != "" )
  ssciname = sRetPrint("IdeTaxonLocal:1");
# ... fall back position
else
  ssciname = "";

printf( ",\"%s\"",      ssciname );                                         #scientificName
printf( ",\"%s\"",      sRetPrint("") );                                    #acceptedNameUsage
printf( ",\"%s\"",      sRetPrint("") );                                    #nameAccordingTo
printf( ",\"%s\"",      sRetPrint("CitTypeStatus:1") );                     #typeStatus

printf( ",\"%s\"",      sRetPrint("IdeCurrentPhylumLocal:1") );             #phylum
printf( ",\"%s\"",      sRetPrint("IdeCurrentClassLocal:1") );              #class
printf( ",\"%s\"",      sRetPrint("IdeCurrentOrderLocal:1") );              #order
printf( ",\"%s\"",      sRetPrint("IdeCurrentFamilyLocal:1") );             #family
printf( ",\"%s\"",      sRetPrint("IdeCurrentGenusLocal:1") );              #genus
printf( ",\"%s\"",      sRetPrint("IdeCurrentSpeciesLocal:1") );            #specificEpithet
printf( ",\"%s\"",      sRetPrint("IdeCurrentSubspeciesLocal:1") );         #infraspecificEpithet

printf( ",\"%s\"",      sRetPrint("") );                                    #vernacularName
printf( ",\"%s\"",      sRetPrint("") );                                    #verbatimTaxonRank

printf( ",\"%s\"",      sRetPrint("IdeIdentifiedByRefLocal:1") );           #identifiedBy

sdateid = "";
if( sGetValue("IdeDateIdentified0:1") != "" ) {
  sdateid = sRetPrint("IdeDateIdentified0:1");
  if( sGetValue("IdeDateIdentified0:2") != "" ) {
    sdateid = sdateid "-" sRetPrint("IdeDateIdentified0:2");
    if( sGetValue("IdeDateIdentified0:3") != "" ) {
      sdateid = sdateid "-" sRetPrint("IdeDateIdentified0:3");
    }
  }
}
printf( ",\"%s\"",    sdateid );                                            #dateIdentified

sidremarks = "";
if( sGetValue("IdeConfidence:1") != "" )
  sidremarks = sidremarks "ecatalogue.IdeConfidence: " sRetPrint("IdeConfidence:1", 1) "; ";
if( sGetValue("IdeSpecimenQuality:1") != "" )
  sidremarks = sidremarks "ecatalogue.IdeSpecimenQuality: " sRetPrint("IdeSpecimenQuality:1", 1) "; ";
if( sGetValue("IdeComments:1") != "" )
  sidremarks = sidremarks "ecatalogue.IdeComments: " sRetPrint("IdeComments:1", 1) "; ";
printf( ",\"%s\"",    sidremarks );                                         #identificationRemarks


###############
# WHERE #######
###############
printf( ",\"%s\"",    sRetPrint("BioOceanLocal:1") );                        #waterBody
printf( ",\"%s\"",    sRetPrint("BioCountryLocal:1") );                      #country
printf( ",\"%s\"",      sRetPrint("") );                                     #stateProvince
printf( ",\"%s\"",      sRetPrint("") );                                     #county
printf( ",\"%s\"",      sRetPrint("BioPreciseLocationLocal:1") );            #verbatimLocality


sprec = ""; slat = ""; sfmt = "";
#default coordinate precision (ddprec) to one degree, which is quite coarse
ddprec = 1; ddlat = 0.0; ddd = 0.0; ddm = 0.0; dds = 0.0;
if( sGetValue("BioCentroidLatitudeLocal0:1") != "" ) {
  slat = slat sRetPrint("BioCentroidLatitudeLocal0:1") "° ";
  ddd = sGetValue("BioCentroidLatitudeLocal0:1");
}
if( sGetValue("BioCentroidLatitudeLocal0:2") != "" ) {
  slat = slat sRetPrint("BioCentroidLatitudeLocal0:2") "' ";
  ddm = sGetValue("BioCentroidLatitudeLocal0:2");
}
if( sGetValue("BioCentroidLatitudeLocal0:3") != "" ) {
  slat = slat sRetPrint("BioCentroidLatitudeLocal0:3") "\\\" ";
  dds = sGetValue("BioCentroidLatitudeLocal0:3");
}
# truncate...
# ... to 5 decimal places
if( dds > 0 ) {
  ddlat = ( ddd + (int((ddm * 100000) / 60) / 100000) + (int((dds * 100000) / 3600) / 100000) );
  sfmt = "%3.5f";
  ddprec = 0.00001;
}
# ... to 3 decimal places
else if( ddm > 0 ) {
  ddlat = ( ddd + (int((ddm * 1000) / 60) / 1000) );
  sfmt = "%3.3f";
  ddprec = 0.001;
}
# ... to 1 decimal place
else if( ddd > 0 ) {
  ddlat = ( (int((ddd * 10)) / 10) );
  sfmt = "%3.1f";
  ddprec = 0.1;
}
# check to see if we're in the southern hemisphere...
if( sGetValue("BioCentroidLatitudeLocal0:4") != "" ) {
  slat = slat sRetPrint("BioCentroidLatitudeLocal0:4");

  if( sGetValue("BioCentroidLatitudeLocal0:4") == "S" )
    ddlat = -(ddlat);
}
# write dd to sd
if( (ddlat == 0.0) )
  sdlat = "";
else
  sdlat = sprintf( sfmt, ddlat );
# write decimal & verbatim values
printf( ",\"%s\",\"%s\"", sdlat, slat );                  #decimalLatitude,verbatimLatitude

# we keep ddprec that was determined from the latitude,
# because we want the coarser precision of the coord's
slon = ""; sfmt = "";
ddlon = 0.0; ddd = 0.0; ddm = 0.0; dds = 0.0;
if( sGetValue("BioCentroidLongitudeLocal0:1") != "" ) {
  slon = slon sRetPrint("BioCentroidLongitudeLocal0:1") "° ";
  ddd = sGetValue("BioCentroidLongitudeLocal0:1");
}
if( sGetValue("BioCentroidLongitudeLocal0:2") != "" ) {
  slon = slon sRetPrint("BioCentroidLongitudeLocal0:2") "' ";
  ddm = sGetValue("BioCentroidLongitudeLocal0:2");
}
if( sGetValue("BioCentroidLongitudeLocal0:3") != "" ) {
  slon = slon sRetPrint("BioCentroidLongitudeLocal0:3") "\\\" ";
  dds = sGetValue("BioCentroidLongitudeLocal0:3");
}
# truncate...
# ... to 5 decimal places
if( dds > 0 ) {
  ddlon = ( ddd + (int((ddm * 100000) / 60) / 100000) + (int((dds * 100000) / 3600) / 100000) );
  sfmt = "%3.5f";
}
# ... to 3 decimal places
else if( ddm > 0 ) {
  ddlon = ( ddd + (int((ddm * 1000) / 60) / 1000) );
  sfmt = "%3.3f";

  # if ddprec was previously finer, we must reduce the precision
  if( ddprec <= 0.001 )
    ddprec = 0.001;
}
# ... to 1 decimal place
else if( ddd > 0 ) {
  ddlon = ( (int((ddd * 10)) / 10) );
  sfmt = "%3.1f";

  # and again: if ddprec was previously finer, we must also reduce the precision
  if( ddprec <= 0.1 )
    ddprec = 0.1;
}
# check to see if we're in the southern hemisphere...
if( sGetValue("BioCentroidLongitudeLocal0:4") != "" ) {
  slon = slon sRetPrint("BioCentroidLongitudeLocal0:4");

  if( sGetValue("BioCentroidLongitudeLocal0:4") == "W" )
    ddlon = -(ddlon);
}
# write dd to sd
if( (ddlon == 0.0) )
  sdlon = "";
else
  sdlon = sprintf( sfmt, ddlon );
# write ddprec to sprec
if( ddprec < 1 ) {
  if( ddprec == 0.00001 )
    sprec = sprintf( "%1.5f", ddprec );
  else if( ddprec == 0.001 )
    sprec = sprintf( "%1.3f", ddprec );
  else if( ddprec == 0.1 )
    sprec = sprintf( "%1.1f", ddprec );
  else 
    sprec = "";
}
# write decimal & verbatim values
printf( ",\"%s\",\"%s\",\"%s\"", sdlon, slon, sprec );                  #decimalLongitude,verbatimLongitude,coordinatePrecision


##########
# old code - the old way allows for creeping errors from floating point arithmetic
#:::::::::
#slon = "";
#ddlon = 0.0;
#if( sGetValue("BioPreferredCentroidLongitude:1") != "" ) {
#  slon = slon sRetPrint("BioPreferredCentroidLongitude:1") "° ";
#  ddlon = sGetValue("BioPreferredCentroidLongitude:1");
#}
#if( sGetValue("BioPreferredCentroidLongitude:2") != "" ) {
#  slon = slon sRetPrint("BioPreferredCentroidLongitude:2") "\' ";
#  ddlon += sGetValue("BioPreferredCentroidLongitude:2") / 60;
#}
#if( sGetValue("BioPreferredCentroidLongitude:3") != "" ) {
#  slon = slon sRetPrint("BioPreferredCentroidLongitude:3") "\\\" ";
#  ddlon += sGetValue("BioPreferredCentroidLongitude:3") / 3600;
#}
## truncate to 3 decimal places
#else if( ddlon != 0.0 ) {
#}
#if( sGetValue("BioPreferredCentroidLongitude:4") != "" ) {
#  slon = slon sRetPrint("BioPreferredCentroidLongitude:4");
#
#  if( sGetValue("BioPreferredCentroidLatitude:4") == "W" )
#   ddlon -= (ddlon * 2);
#}
#if( (ddlon == 0.0) )
# sdlon = "";
#else
# sdlon = sprintf( "%f", ddlon );
#
#printf( ",\"%s\",\"%s\"",  sdlon, slon ); $decimalLongitude,verbatimLongitude


printf( ",\"%s\"",          sRetPrint("") );       #verbatimCoordinateSystem

slocremarks = "";
#if( sGetValue("LocCollectionEventLocal:1") != "" )
#  slocremarks = slocremarks "ecatalogue.LocCollectionEventLocal: " sRetPrint("LocCollectionEventLocal:1", 1) "; "; #sGetValue("LocCollectionEventLocal:1")
#if( sGetValue("BioTopographyLocal:1") != "" )
#  slocremarks = slocremarks "ecatalogue.BioTopographyLocal: " sRetPrint("BioTopographyLocal:1", 1) "; ";
#if( sGetValue("SqsSiteName:1") != "" )
#  slocremarks = slocremarks "ecatalogue.SqsSiteName: " sRetPrint("SqsSiteName:1", 1) "; ";
#if( sGetValue("SqsCityTown:1") != "" )
#  slocremarks = slocremarks "ecatalogue.SqsCityTown: " sRetPrint("SqsCityTown:1", 1) "; ";
printf( ",\"%s\"",      slocremarks );                  #locationRemarks



###############
# WHEN  #######
###############
seventid = "";
if( sGetValue("ColCollectionEventsRef:1") != "" )
  seventid = "urn:emu.samuseum.sa.gov.au:Event:" sRetPrint("ColCollectionEventsRef:1");
printf( ",\"%s\"",                        seventid ); #eventID

sevtdate = "";
sverbevtdate = "";

if( sGetValue("PreDateCollected:1") != "" ) {
  sevtdate = sRetPrint("PreDateCollected:1");
  sdtpart = sGetValue("PreDateCollected:2");

  if( (sdtpart != "") ) {
  	# we need to pad this number with leading zeros...
  	sdigit = "";
  	if( (sdtpart > 0) ) {
  		sdigit = sprintf( "%02d", sdtpart );
  	}
  	if( sdigit != "" ) {
      sevtdate = sevtdate "-" sdigit;
      sdtpart = sGetValue("PreDateCollected:3");

      if( (sdtpart != "") ) {
        # we also need to pad this number with leading zeros...
        sdigit = "";
        if( (sdtpart != "") && (sdtpart > 0) ) {
  	      sdigit = sprintf( "%02d", sdtpart );
        }
        if( sdigit != "" ) {
          sevtdate = sevtdate "-" sdigit;

#redundant - sam doesn't capture the from/to concept in ecatalogue; it is little-used in ecollectionevents
#      bdelim = 0;
#        if( (sGetValue("LocDateCollectedTo:1") != "") && (sGetValue("LocDateCollectedTo:1") != sGetValue("LocDateCollectedFrom:1")) ) {
#            sevtdate = sevtdate "/" sRetPrint("LocDateCollectedTo:1");
#            bdelim = 1;
#        }
#        if( (sGetValue("LocDateCollectedTo:2") != "") && (sGetValue("LocDateCollectedTo:2") != sGetValue("LocDateCollectedFrom:2")) ) {
#            if( bdelim == 0 ) {
#                bdelim = 1;
#                sevtdate = sevtdate "/" sRetPrint("LocDateCollectedTo:2");
#            }
#            else {
#                sevtdate = sevtdate "-" sRetPrint("LocDateCollectedTo:2");
#            }
#        }
#        if( (sGetValue("LocDateCollectedTo:3") != "") && (sGetValue("LocDateCollectedTo:3") != sGetValue("LocDateCollectedFrom:3")) ) {
#            if( bdelim == 0 ) {
#                bdelim = 1;
#                sevtdate = sevtdate "/" sRetPrint("LocDateCollectedTo:3");
#            }
#            else {
#                sevtdate = sevtdate "-" sRetPrint("LocDateCollectedTo:3");
#            }
#        }

        }
      }
    }
  }
}

# originally, verbatimEventDate was only populated if eventDate was empty
# then, it was interesting info so included it for all records
# now: CatDateCatalogued is no longer included in exports; [agreed fcig may 2011]
#
#if( sevtdate == "" ) {
#  bdelim = 0;
#  if( (sGetValue("CatDateCatalogued:1") != "") ) {
#   sverbevtdate = sverbevtdate sRetPrint("CatDateCatalogued:1");
#   bdelim = 1;
# }
# if( (sGetValue("CatDateCatalogued:2") != "") ) {
#   if( bdelim == 0 ) {
#     bdelim = 1;
#     sverbevtdate = sverbevtdate "/" sRetPrint("CatDateCatalogued:2");
#   }
#   else {
#     sverbevtdate = sverbevtdate "-" sRetPrint("CatDateCatalogued:2");
#    }
#  }
# if( (sGetValue("CatDateCatalogued:3") != "") ) {
#   if( bdelim == 0 ) {
#     bdelim = 1;
#     sverbevtdate = sverbevtdate "/" sRetPrint("CatDateCatalogued:3");
#   }
#   else {
#     sverbevtdate = sverbevtdate "-" sRetPrint("CatDateCatalogued:3");
#    }
#  }
#  if( sverbevtdate != "" ) {
#   sverbevtdate = "ecatalogue.CatDateCatalogued: " sverbevtdate ";";
#  }
#}
#
sverbevtdate = "";
printf( ",\"%s\",\"%s\"",       sevtdate, sverbevtdate );       #eventDate,verbatimEventDate

sevttime = "";
#redundant? does sam capture event time?
#if( sGetValue("ColTimeVisitedFrom:1") != "" ) {
#  sevttime = sRetPrint("ColTimeVisitedFrom:1");
#  if( sGetValue("ColTimeVisitedFrom:2") != "" ) {
#    sevttime = sevttime ":" sRetPrint("ColTimeVisitedFrom:2");
#    if( sGetValue("ColTimeVisitedFrom:3") != "" ) {
#      sevttime = sevttime ":" sRetPrint("ColTimeVisitedFrom:3");
#
#      bdelim = 0;
#            if( (sGetValue("ColTimeVisitedTo:1") != "") && (sGetValue("LocTimeCollectedTo:1") != sGetValue("ColTimeVisitedFrom:1")) ) {
#              sevttime = sevttime ":" sRetPrint("ColTimeVisitedTo:1");
#              bdelim = 1;
#            }
#            if( (sGetValue("ColTimeVisitedTo:2") != "") && (sGetValue("ColTimeVisitedTo:2") != sGetValue("ColTimeVisitedFrom:2")) ) {
#              if( bdelim == 0 ) {
#                bdelim = 1;
#                sevttime = sevttime ":" sRetPrint("ColTimeVisitedTo:2");
#              }
#              else {
#                sevttime = sevttime ":" sRetPrint("ColTimeVisitedTo:2");
#            }
#          }
#            if( (sGetValue("ColTimeVisitedTo:3") != "") && (sGetValue("ColTimeVisitedTo:3") != sGetValue("ColTimeVisitedFrom:3")) ) {
#              if( bdelim == 0 ) {
#                bdelim = 1;
#                sevttime = sevttime ":" sRetPrint("ColTimeVisitedTo:3");
#              }
#              else {
#                sevttime = sevttime ":" sRetPrint("ColTimeVisitedTo:3");
#            }
#          }
#    }
#  }
#}
printf( ",\"%s\"",            sevttime );             #eventTime


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
printf( ",\"%s\"",            sdtmod );               #dcterms:modified


###############
# INFO  #######
###############
printf( ",\"%s\"", sRetPrint("LocSamplingMethod:1") );                      #samplingProtocol
printf( ",\"%s\"", sRetPrint("BioMicrohabitatDescription:1") );             #habitat

# old:
#printf( ",\"urn:lsid:ozcam.taxonomy.org.au:SAMA:%s:%s%s%s\"", sRetPrint("CatCollectionName:1"), sRetPrint("CatPrefix:1"), sRetPrint("CatRegNumber:1"), sRetPrint("CatSuffix:1") );    #occurrenceID
#printf( ",%s%s%s", sRetPrint("CatPrefix:1"), sRetPrint("CatRegNumber:1"), sRetPrint("CatSuffix:1") );                     #catalogNumber

# we must now check the value of the suffix to ensure it is not empty or 'NULL', before we print a '.SUFFIX' on the end of the lsid
#  agreed lsid-pattern: urn:lsid:ozcam.taxonomy.org.au:[Institution Code]:[Collection code]:[Basis of Record](optional):[Catalog Number]:[Version](optional)

if( ("" != sGetValue("CatSuffix:1")) && ("NULL" != sGetValue("CatSuffix:1")) ) {
  printf( ",\"urn:lsid:ozcam.taxonomy.org.au:SAMA:%s:%s%s.%s\"", sRetPrint("CatCollectionName:1"), sRetPrint("CatPrefix:1"), sRetPrint("CatRegNumber:1"), sRetPrint("CatSuffix:1") );    #occurrenceID
  printf( ",\"%s%s.%s\"", sRetPrint("CatPrefix:1"), sRetPrint("CatRegNumber:1"), sRetPrint("CatSuffix:1") );                     #catalogNumber
}
# default lsid has no suffix
else {
  printf( ",\"urn:lsid:ozcam.taxonomy.org.au:SAMA:%s:%s%s\"", sRetPrint("CatCollectionName:1"), sRetPrint("CatPrefix:1"), sRetPrint("CatRegNumber:1") );    #occurrenceID
  printf( ",\"%s%s\"", sRetPrint("CatPrefix:1"), sRetPrint("CatRegNumber:1") );                     #catalogNumber
}


printf( ",\"%s\"", sRetPrint("NotNotes:1") );                               #occurrenceRemarks
printf( ",\"%s\"", sRetPrint("LocCollectorsLocal:1") );                     #recordedBy
printf( ",\"%s\"", sRetPrint("CatSpecimenCount:1") );                       #individualCount
# note: next two printf's are the one dwc-term, 'other catalogue numbers'; first, the irn ...
printf( ",\"ecatalogue.irn:%s", sRetPrint("irn:1") );                       #otherCatalogNumbers
# and second, the old lsid pattern sam was using for 'occurrence id' (now using the fcig-agreed pattern)
printf( "; urn:catalog:sama:%s:%s:%s:%s\"", sRetPrint("CatCollectionName:1"), sRetPrint("CatPrefix:1"), sRetPrint("CatRegNumber:1"), sRetPrint("CatSuffix:1") ); #otherCatalogNumbers
printf( ",\"%s\"", sRetPrint("ZooSex:1") );                                 #sex
printf( ",\"%s\"", sRetPrint("ZooStage:1") );                               #lifeStage

sprep = "";
if( sGetValue("ZooPreparation:1") != "" ) {
  sprep = "ecatalogue.ZooPreparation:" sRetPrint("ZooPreparation:1", 1);
}
if( sGetValue("ZooFixative:1") != "" ) {
  if( sprep != "" )
    sprep = sprep "; ecatalogue.ZooFixative:" sRetPrint("ZooFixative:1", 1);
  else
    sprep = "ecatalogue.ZooFixative:" sRetPrint("ZooFixative:1", 1);
}
if( sGetValue("CatObjectType:1") != "" ) {
  if( sprep != "" )
    sprep = sprep "; ecatalogue.CatObjectType:" sRetPrint("CatObjectType:1", 1);
  else
    sprep = "ecatalogue.CatObjectType:" sRetPrint("CatObjectType:1", 1);
}
printf( ",\"%s\"",                                              sprep );    #preparations

sprep = "";
# i want to include these data, but this is not the appropriate dwc term... (now seeking a better one 20111102)
#if( sGetValue("BioTissueNumber:1") != "" ) {
#  sprep = sRetPrint("BioTissueNumber:1", 1);
#}
#if( sGetValue("BioTissueType:1") != "" ) {
#  if( sprep != "" )
#    sprep = sprep "; " sRetPrint("BioTissueType:1", 1);
#  else
#    sprep = sRetPrint("BioTissueType:1", 1);
#}
#if( sGetValue("BioOtherTissueNumber:1") != "" ) {
#  if( sprep != "" )
#    sprep = sprep "; " sRetPrint("BioOtherTissueNumber:1", 1);
#  else
#    sprep = sRetPrint("BioOtherTissueNumber:1", 1);
#}
printf( ",\"%s\"",                                              sprep );    #associatedSequences

### principal record pointer
# determine if this record is a subordinate/child record by checking CatSuffix
# if it is not empty, attempt to craft a lsid to the parent
### cases:
#
### notes:
# this *should* involve a check for the existence of the parent (or other children)
# something to think about for the future: maybe parent & child relationship records could be exported to separate files
if( sGetValue("CatSuffix:1") != "" ) {
#agreed lsid-pattern: urn:lsid:ozcam.taxonomy.org.au:[Institution Code]:[Collection code]:[Basis of Record](optional):[Catalog Number]:[Version](optional)
printf( ",\"urn:lsid:ozcam.taxonomy.org.au:SAMA:%s:%s%s\"", sRetPrint("CatCollectionName:1"), sRetPrint("CatPrefix:1"), sRetPrint("CatRegNumber:1") );    #principalRecord
}
else {
printf( ",\"\"" );                                                          #principalRecord
}


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
# this record's field is empty...
  s = "";

#   unless the field-name has been mapped to an index in the header
  if( sind in arrsSourceIndex ) {
    s = $arrsSourceIndex[sind];
  }

  return s;
}