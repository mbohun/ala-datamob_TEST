/**************************************************************************
 *  Copyright (C) 2012 Atlas of Living Australia
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

 this file hosts the view definitions to map qm's snapshot data to dwc csv

 v2: 20120603: bk - moved data export to a separate file (qmdwc_export.sql)
 v1: 20120529: bk - first iteration for initial qm testing

 todo:

*/


----------------------------------------------------------------------------------------------------------------------------------------------------
-- important! do not change any view's name without considering the export file (qmdwc_export.sql)
--


----------------------------------------------------------------------------------------------------------------------------------------------------
-- the images view
create or replace view

vw_qmavlist

as

-- join the imagery using the object_av xref table
-- and mysql's handy 'group_concat' aggregate function
select 
fk_object_id
, group_concat(fk_av_id)   as imgids
, group_concat('http://74.50.62.163/images/display/', filename separator '; ')   as imgurls
from        object_av oav 

left join   av             on (oav.fk_av_id=av.av_id)
--for only 1 img url, replace above left-join with the following: 
--left join   av             on ((oav.display_position=1) and (oav.fk_av_id=av.av_id)) 

group by    fk_object_id 
order by    fk_object_id, display_position;



----------------------------------------------------------------------------------------------------------------------------------------------------
-- the main view
create or replace view 

vw_qmdwc

as

select

-- direct mappings before 20120529
text1            as 'collectionCode'
,text2           as 'occurrenceID'
,text3           as 'catalogNumber'
,text4           as 'institutionCode'
,text5           as 'basisOfRecord'
,text6           as 'modified'
,text7           as 'scientificName'
,text8           as 'scientificNameAuthorship'
,text9           as 'kingdom'
,text10          as 'phylum'
,text11          as 'class'
,text12          as 'order'
,text13          as 'family'
,text14          as 'genus'
,text15          as 'specificEpithet'
,text16          as 'infraspecificEpithet'
,text17          as 'vernacularName'
,text18          as 'typeStatus'
,text19          as 'originalNameUsage'
,text20          as 'decimalLatitude'
,text21          as 'decimalLongitude'
,text22          as 'coordinateUncertaintyInMeters'
,text23          as 'geodeticDatum'
,text24          as 'locality'
,text25          as 'stateProvince'
,text26          as 'country'
,text27          as 'minimumElevationInMeters'
,text28          as 'maximumElevationInMeters'
,text29          as 'minimumDepthInMeters'
,text30          as 'maximumDepthInMeters'
,text31          as 'samplingProtocol'
,text32          as 'eventDate'
,text33          as 'preparations'
,text34          as 'sex'
,text35          as 'lifeStage'
,text36          as 'individualCount'
,text37          as 'identificationRemarks'
,text39          as 'identifiedBy'

-- direct mappings after 20120529
,'object.object_id:' + object_id + ';'      as 'otherCatalogNumbers'

-- joined after 20120529
,coalesce( avlist.imgurls, '' )  as 'associatedMedia'

-- excluded data not to be included at 20120529
--text38	(ALA flag -- DON'T IMPORT)
--text40	recordedBy

-- erroneous (? fields non-existant)
--,date_display1   as 'verbatimEventDate'
--,date_display2   as 'dateIdentified'

from          object ob

left join     vw_qmavlist avlist on avlist.fk_object_id=ob.object_id;

--left join     av on obj.object_id = av.object_id; 
--select fk_object_id, group_concat(fk_av_id), group_concat(filename) from object_av oav left join av on ((oav.display_position=1) and (oav.fk_av_id=av.av_id)) group by fk_object_id order by fk_object_id, display_position;
