/**************************************************************************
 *  Copyright (C) 2011 Atlas of Living Australia
 *  All Rights Reserved.
 *
 *  The contents of this file are subject to the Mozilla Public
 *  License Version 1.1 (the "License"); you may not use this file
 *  except in compliance with the License. You may obtain a copy of
 *  the License at http://www.mozilla.org/MPL/
 *
 *  Software distributed under the License is distributed on an "AS
 *  IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
 *  implied. See the License for the specific language governing
 *  rights and limitations under the License.
 ***************************************************************************/

/*
 DwC data export query

 this file hosts the select statement to extract data from the primary ANWC cms

 v7: 20120830: mc - revised 'preparations' formatting in case of tissue/preserved organ (142)
 v6: 20120528: bk - revised event date
 v5: 20120521: bk - parsed lat/lon & coord precision
 v4: 20120518: mc - data driven record basis
 v3: 20120518: bk - third iteration post anwc review
 v2: 20120515: bk - second iteration for further anwc testing
 v1: 20120514: bk - first iteration for initial anwc testing

 todo:

*/


select

--top 10000

-- static values ----------------------------------------------------------------------------------------------------------------------------------------- static values --
--
'ANWC'                                  as 'institutionCode'
, 'urn:lsid:biocol.org:col:34932'       as 'collectionId'

-- now data driven - see joined direct translations, 'PreservedSpecimen'                   as 'basisOfRecord'
-- now data driven - see joined direct translations, 'physical object'                     as 'dcterms:type'
, 'present'                             as 'occurrenceStatus'

, 'Animalia'                            as 'kingdom'
, 'Chordata'                            as 'phylum'

, 'CSIRO'                               as 'dcterms:rightsHolder'


-- direct translations ----------------------------------------------------------------------------------------------------------------------------- direct translations --
--
, tsr.regno                             as 'catalogNumber'
, tsr.lsid                              as 'occurrenceId'
, tsr.fieldno                           as 'fieldNumber'
, tsr.datelastmodified                  as 'dcterms:modified'
, tsr.pointlocation                     as 'locationRemarks'
, tsr.locality                          as 'verbatimLocality'
, tsr.lat                               as 'verbatimLatitude'
, tsr.long                              as 'verbatimLongitude'
, regcoords_inr.latdd                   as 'decimalLatitude'
, regcoords_inr.londd                   as 'decimalLongitude'
, tsr.originalnameusage                 as 'originalNameUsage'
, tsr.coordinateuncertaintyinmeters     as 'coordinateUncertaintyInMeters'
, tsr.recordeddate                      as 'verbatimEventDate'
, tsr.alt                               as 'verbatimElevation'
, tsr.regno                             as 'dcterms:bibliographicCitation'

-- modifications ---------------------------------------------------------------------------------------------------------------------------------------- modifications --
--
, 'urn:anwc.csiro.au:collections:' + convert(varchar, tsr.collectionid)    as 'datasetId'

-- date format compliant with ala ingest yyyy-mm-dd/yyyy-mm-dd
, case 
  -- when both dates are == && !null
  when( (tsr.earliestdatecollected is not null) and (tsr.earliestdatecollected = tsr.latestdatecollected) ) then 
    left( convert(varchar, tsr.earliestdatecollected, 120), 10 )
  -- when both dates are != && !null
  when( (tsr.earliestdatecollected is not null) and (tsr.latestdatecollected is not null) and (tsr.earliestdatecollected <> tsr.latestdatecollected) ) then 
    left( convert(varchar, tsr.earliestdatecollected, 120), 10 ) + '/' + left( convert(varchar, tsr.latestdatecollected, 120), 10 )
  else NULL 
  end                                                                      as 'eventDate'

/* old: not parsed by ingest sandbox yyyymmdd-yyyymmdd
, case 
  when(tsr.earliestdatecollected = tsr.latestdatecollected) then convert(varchar, tsr.earliestdatecollected, 112)
  when(tsr.earliestdatecollected <> tsr.latestdatecollected) then convert(varchar, tsr.earliestdatecollected, 112) + '/' + convert(varchar, tsr.latestdatecollected, 112)
  else NULL 
  end                                                                      as 'eventDate'
*/

, ('tblspecimenrecords.microhabitat: ' + tsr.microhabitat + '; ' + 
   'tblspecimenrecords.macrohabitat: ' + tsr.macrohabitat + ';')           as 'habitat'


-- joined direct translations ----------------------------------------------------------------------------------------------------------------- joined direct translations --
--
, (select collectioncodename from tblcollectioncodes where collectioncodeid=tsr.collectioncodeid)         as 'collectionCode' --tsr.collectioncodeid
, (select basisOfRecord from tblbasisOfRecord where basisOfRecordID=tsr.basisOfRecordID)                  as 'basisOfRecord' --tsr.basisOfRecord
, (select dctermsType from tblbasisOfRecord where basisOfRecordID=tsr.basisOfRecordID)                    as 'dcterms:type' --tsr.dcterms:type

, (select stateprovincename from tblstateprovince where stateprovinceid=tsr.stateprovinceid)              as 'stateProvince' --tsr.stateprovinceid
, (select countryname from tblcountries where countryid=tsr.countryid)                                    as 'country' --tsr.countryid
, (select continentname from tblcontinents where continentid=tsr.continentid)                             as 'continent' --tsr.continentid
, (select countyname from tblcounties where countyid=tsr.countyid)                                        as 'county' --tsr.countyid
, (select islandname from tblislands where islandid=tsr.islandid)                                         as 'island' --tsr.islandid
, (select islandgroupname from tblislandgroups where islandgroupid=tsr.islandgroupid)                     as 'islandGroup' --tsr.islandgroupid
, (select waterbodyname from tblwaterbodies where waterbodyid=tsr.waterbodyid)                            as 'waterBody' --tsr.waterbodyid

, tsl.scientificname                                                                                      as 'scientificName' --tsr.speciesid
, tsl.species                                                                                             as 'specificEpithet' --tsr.speciesid
, tsl.subspecies                                                                                          as 'infraspecificEpithet' --tsr.speciesid
, tsl.commonname                                                                                          as 'vernacularName' --tsr.speciesid

, (select genusname from tblgenus where genusid=tsl.genusid)                                              as 'genus' --tsr.speciesid,tsl.genusid
, (select familyname from tblfamilies where familyid=tsl.familyid)                                        as 'family' --tsr.speciesid,tsl.familyid
, (select taxclassname from tbltaxonomicclass where taxclassid=(
     select taxclassid from tblfamilies where familyid=tsl.familyid))                                     as 'class' --tsr.speciesid,tsl.familyid,tf.taxclassid

, (select typestatus from tbltypestatus where typestatusid=tsr.typestatusid)                              as 'typeStatus'

, case
  when (identqualifierid > 1) then
    (select (
      'tblidentificationqualifier.identqualifiername: ' + identqualifiername + '; ' +
      'tblidentificationqualifier.identqualifiercode: ' + identqualifiercode + ';'
    ) from tblidentificationqualifier where identqualifierid=tsr.identqualifierid)
  else null
  end                                                                                                     as 'identificationQualifier'

, (select locqualifiername from tbllocationqualifier where locqualifierid=tsr.locqualifierid)             as 'verbatimUncertainty'
, (select geodeticdatum from tblgeodeticdatum where geodeticdatumid=tsr.geodeticdatumid)                  as 'verbatimSRS'

, (select sexname from tblsex where sexid=tsr.sexid)                                                      as 'sex'

, (select vdflagname from tblvaliddistributionflag where vdflagid=tsr.vdflagid)                           as 'establishmentMeans'

, case
  -- preparation & 'preserved organs'
  when ((tsr.preservedorgans is not null) and (tsr.preparationid is not null)) then
    (select preparationname from tblpreparations where preparationid=tsr.preparationid) + '; ' +
    'tissues: ' + tsr.preservedorgans
  -- preparation only
  when ((tsr.preparationid is not null)) then
    (select preparationname from tblpreparations where preparationid=tsr.preparationid)
  -- otherwise...
  else NULL
  end                                                                                                     as 'preparations'

-- joined modifications --------------------------------------------------------------------------------------------------------------------------- joined modifications --
--
, case
  -- if either lat or lon precision is null, no coordinate precision
  when (regcoords_inr.latprec is null) or (regcoords_inr.lonprec is null) then
    null
  -- when latitude is more precise (ie, longer string)
  when len(regcoords_inr.latprec) >= len(regcoords_inr.lonprec) then
    regcoords_inr.latprec
  -- when longitude is more precise
  when len(regcoords_inr.lonprec) >= len(regcoords_inr.latprec) then
    regcoords_inr.lonprec
  -- otherwise, null
  else NULL
  end                                                                      as 'coordinatePrecision'

from         tblSpecimenRecords tsr

left join    tblSpeciesList tsl on (tsr.speciesid = tsl.speciesid)

-- this sub-query / join is to determine values for the following:
-- 1. decimal latitude
-- 2. 
-- 3. decimal longitude
-- 4. longitude precision
--
-- it lives down here for code readability
-- 

left join    (
 select
 regno

 -- decimal latitude ------------------------------------------------------------------------------------ latdd --
 , case
  
  -- when there is no textual lat, latitude has likely come from a gps so we must include it
  when ((lat is null) and (latitude is not null)) then
  latitude
  
  -- otherwise, the following cases apply when there is a valid textual lat that can be parsed;
  -- each case follows the algorithm:
  --   sign( based on trailing 'N'/'S' ) * ( conversion of valid text to decimal degrees )
  --
  -- [lhs] sign( based on trailing 'N'/'S' )
  -- 
  -- determines the sign for decimal degrees as a multiplier (-1, 1)
  -- (note: ascii 'S' == 83; ascii 'N' == 78)
  --
  -- code details: 
  --  sign( -ascii(reverse(lat)) + ascii('S') - 1 )
  --    1. reverse lat to read the last char       [reverse(lat)]
  --    2. convert last char to ascii code number  [ascii(reverse...)]
  --    3. take the negative value instead         [-ascii...]
  --    4. add to this the ascii value of 'S', then subtract 1
  --       possible results of this operation are:
  --        (S & S) -83 + 83 - 1 == -1
  --        (N & S) -78 + 83 - 1 == 4
  --    5. determine the 'sign' of the result      [sign(-ascii...)]
  --       (-1, 0 or 1 ... see: http://msdn.microsoft.com/en-us/library/ms188420.aspx)
  --
  -- [rhs] conversion of valid text to decimal degrees :
  --    (note: using 'like' patterns to exclude invalid lat's)
  --
  --    patterns 1 & 2 (degrees, minutes, seconds) :
  --      [0-9][0-9][0-9][0-9][0-9][1-9][NS]
  --      [0-9][0-9][0-9][0-9][1-9][0-9][NS]
  --
  --      1. convert 1st two chars to a decimal                         [convert( real, left(lat, 2) )]
  --      2. +plus+ convert centre two chars to a decimal               [convert( real, substring(lat, 3, 2) )]
  --      3. divide the result by 60; round this to 5 decimal places    [round( (convert...  / 60), 5, 1 )]
  --      4. +plus+ convert last two chars to a decimal                 [convert( real, substring(lat, 5, 2) )]
  --      5. divide the result by 3600; round this to 5 decimal places  [round( (convert...  / 3600), 5, 1 )]
  --      
  --    patterns 3 & 4 (degrees, minutes) :
  --      [0-9][0-9][0-9][1-9]__[NS]
  --      [0-9][0-9][1-9][0-9]__[NS]
  --      
  --      algorithm as for deg+min+sec, however:
  --       - steps 4 & 5 omitted
  --       - rounding to 3 decimal places only
  --
  --    patterns 5 & 6 (degrees only) :
  --      [0-9][1-9]____[NS]
  --      [1-9][0-9]____[NS]
  --
  --    comments on [rhs]:
  --
  --    1. with the above patterns, deg+min or deg only *must* have trailing characters to pad the textual lat out to 6 chars
  --       - this is the valid pattern in anwc's db, with '0' being the padding
  --         therefore, 123400N is treated as (deg+min) only, even though it might be (deg+min+sec)
  --       - upshot is, 'coordinate precision' will be coarser than it otherwise might be
  --         however, the result of the decimal degrees conversion should be the same or close (depending on floating point arithmetic)
  --       - it may make some sense in the future to allow for reliably parsing more patterns
  --
  --    2. rounding occurs prior to each addition to avoid a creeping error in precision 
  --      to change this behaviour, move the 'round' instructions to the overall result, eg:
  --      round(
  --        convert( real, left(lat, 2) ) +
  --        (convert( real, substring(lat, 3, 2) ) / 60) +
  --        (convert( real, substring(lat, 5, 2) ) / 3600)
  --      , 5, 1)
  --

  -- lat valid seconds patterns 1 & 2
  when (lat like '[0-9][0-9][0-9][0-9][0-9][1-9][NS]') 
    or (lat like '[0-9][0-9][0-9][0-9][1-9][0-9][NS]') 
  then
    (sign( -ascii(reverse(lat)) + ascii('S') - 1 )) *
      ( (convert( real, left(lat, 2) )) +
         round( (convert( real, substring(lat, 3, 2) ) / 60), 5, 1) +
         round( (convert( real, substring(lat, 5, 2) ) / 3600), 5, 1)
      )

  -- lat valid minutes patterns 3 & 4
  when (lat like '[0-9][0-9][0-9][1-9]__[NS]') 
    or (lat like '[0-9][0-9][1-9][0-9]__[NS]') 
  then
    (sign( -ascii(reverse(lat)) + ascii('S') - 1 )) *
      ( (convert( real, left(lat, 2) )) +
         round( (convert( real, substring(lat, 3, 2) ) / 60), 3, 1)
      )

  -- lat valid degrees patterns 5 & 6
  when (lat like '[0-9][1-9]____[NS]') 
    or (lat like '[1-9][0-9]____[NS]') 
  then
    (sign( -ascii(reverse(lat)) + ascii('S') - 1 )) *
    (convert( real, left(lat, 2) ))

  -- if we get to here lat can't be parsed, however, we may still have a valid latitude
  when (latitude is not null) then
  latitude

  -- finally ...
  else null
  end                                                                                                     as 'latdd'

 -- precision of decimal latitude ----------------------------------------------------------------------- latprec --

 , case
  
  -- 'coordinate precision' is a number between 0 and 1, used to give
  -- an indication of the number of decimal places applicable to the decimal degrees
  -- we only do this when we parse latdd ourselves; otherwise, we don't have an opinion
  -- (see latdd for more info)

  -- lat valid seconds, 5 decimal places (patterns 1 & 2)
  when (lat like '[0-9][0-9][0-9][0-9][0-9][1-9][NS]')
    or (lat like '[0-9][0-9][0-9][0-9][1-9][0-9][NS]') 
  then str( 0.00001, 7, 5)

  -- lat valid minutes, 3 decimal places (patterns 3 & 4)
  when (lat like '[0-9][0-9][0-9][1-9]__[NS]')
    or (lat like '[0-9][0-9][1-9][0-9]__[NS]') 
  then str( 0.001, 5, 3)

  -- lat valid degrees, 1 decimal place (patterns 5 & 6)
  when (lat like '[0-9][1-9]____[NS]')
    or (lat like '[1-9][0-9]____[NS]') 
  then str( 0.1, 3, 1 )

  end                                                                                                     as 'latprec'


 -- decimal longitude --------------------------------------------------------------------------------------- londd --
 , case
  
  -- when there is no textual long, longitude has likely come from a gps so we must include it
  when ((long is null) and (longitude is not null)) then
  longitude
  
  -- otherwise, londd is as for latdd, except ...
  -- 1. degrees longitude are 3 digits (0-179), therefore:
  --    - all string functions parse text from different positions (left, substring)
  --    - all 'like' patterns allow for an addition digit of degrees
  -- 2. ascii 'E' == 69; ascii 'W' == 87, therefore, possible maths to determine sign is:
  --    - (E & W) -69 + 87 - 1 == 17
  --    - (W & W) -87 + 87 - 1 == -1

  -- long valid seconds (patterns 1 & 2)
  when (long like '[0-9][0-9][0-9][0-9][0-9][0-9][1-9][EW]')
    or (long like '[0-9][0-9][0-9][0-9][0-9][1-9][0-9][EW]')
  then
    (sign( -ascii(reverse(long)) + ascii('W') - 1 )) *
      ( (convert( real, left(long, 3) )) +
         round( (convert( real, substring(long, 4, 2) ) / 60), 5, 1) +
         round( (convert( real, substring(long, 6, 2) ) / 3600), 5, 1)
      )

  -- long valid minutes (patterns 3 & 4)
  when (long like '[0-9][0-9][0-9][0-9][1-9]__[EW]')
    or (long like '[0-9][0-9][0-9][1-9][0-9]__[EW]')
  then
    (sign( -ascii(reverse(long)) + ascii('W') - 1 )) *
      ( (convert( real, left(long, 3) )) +
         round( (convert( real, substring(long, 4, 2) ) / 60), 3, 1)
      )

  -- long valid degrees (patterns 5, 6 & 7)
  when (long like '[0-9][0-9][1-9]____[EW]')
    or (long like '[0-9][1-9][0-9]____[EW]')
    or (long like '[1-9][0-9][0-9]____[EW]')
  then
    (sign( -ascii(reverse(long)) + ascii('W') - 1 )) *
    (convert( real, left(long, 3) ))

  -- if we get to here long can't be parsed, however, we may still have a valid longitude
  when (longitude is not null) then
  longitude

  -- finally ...
  else null
  end                                                                                                     as 'londd'


-- precision of decimal longitude ----------------------------------------------------------------------- lonprec --

, case
  
  -- 'coordinate precision' is a number between 0 and 1, used to give
  -- an indication of the number of decimal places applicable to the decimal degrees
  -- we only do this when we parse londd ourselves; otherwise, we don't have an opinion
  -- (see londd for more info)

  -- long valid seconds, 5 decimal places (patterns 1 & 2)
  when (long like '[0-9][0-9][0-9][0-9][0-9][0-9][1-9][EW]')
    or (long like '[0-9][0-9][0-9][0-9][0-9][1-9][0-9][EW]') 
  then str( 0.00001, 7, 5)

  -- long valid minutes, 3 decimal places (patterns 3 & 4)
  when (long like '[0-9][0-9][0-9][0-9][1-9]__[EW]')
    or (long like '[0-9][0-9][0-9][1-9][0-9]__[EW]') 
  then str( 0.001, 5, 3)

  -- long valid degrees, 1 decimal place (patterns 5, 6 & 7)
  when (long like '[0-9][0-9][1-9]____[EW]')
    or (long like '[0-9][1-9][0-9]____[EW]') 
    or (long like '[1-9][0-9][0-9]____[EW]') 
  then str( 0.1, 3, 1 )

  end                                                                                                     as 'lonprec'

  from tblspecimenrecords
) as regcoords_inr 

on (tsr.regno = regcoords_inr.regno)

where

-- filter: should this record be included in the export?
(tsr.PublishID = 1)
