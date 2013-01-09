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

 it also holds the queries which will write header & data in (almost) csv format

 v1: 20120603: bk - first iteration for initial qm testing

 todo:

*/


----------------------------------------------------------------------------------------------------------------------------------------------------
-- the output queries
--
-- important! do not change any of these options without considering the
-- expected, combined output of the following two queries (see end of file)
--
-- both queries output to files in /tmp
-- both of which the caller must delete once they're finished with,
-- otherwise the next time this command is called, it will fail
--

----------------------------------------------------------------------------------------------------------------------------------------------------
-- header output query
--
-- the header row from the above view, exported to its own file
SELECT group_concat(COLUMN_NAME) as 'col' FROM information_schema.COLUMNS C WHERE table_name = "vw_qmdwc"
-- the output file (which the caller must delete once it's finished with it, otherwise the next time this command is called, it will fail)
into outfile            '/tmp/qmdwc_header.csv'
--note: no field termination as group_concat has already pulled each row (a column-name) into the result string
--fields terminated by ',' optionally enclosed by  '"'
lines terminated by     '\n';

----------------------------------------------------------------------------------------------------------------------------------------------------
-- data output query
--
-- the data from the above view, exported to their own file
select * from vw_qmdwc
-- the output file (which the caller must delete once it's finished with it, otherwise the next time this command is called, it will fail)
into outfile            '/tmp/qmdwc_data.csv'
--note: comma-separated
fields terminated by    ',' 
--note: string-values wrapped with double-quotes "
optionally enclosed by  '"'
-- double-quotes, commas, and new lines will be prepended with a backslash
escaped by              '\\'
-- all records are separated by a blank line
-- note: this is brittle - if there are multiple line-feeds in the textual data, 
-- these will appear as a record separator and confuse any data consumer (which will hopefully fail gracefully)
lines terminated by     '\n\n';

-- commit the transaction
-- process exits, at which point, caller should check for error ...
-- and if none found, combine the two files for distribution



----------------------------------------------------------------------------------------------------------------------------------------------------
-- further notes
--
-- 20120529 - follows is the expected output
-- note the blank link between records, as well as the \ escaping the subsequent (nested) newline in preparation data
-- this is a direct result of the options chosen for the 'select ... into' commands previously issued

-- these results are human readable, but will confuse a parser; subsequent processing should:
--   * remove any sequence of '\0x0d0x0a' (backslash + carriage return + line feed)
--   * remove blank lines between records, eg (linux): 
--      cat -v qmdwc_header.csv qmdwc_data.csv | sed ':a;N;$!ba;s/\\\n/\\n/g' | sed ':a;N;$!ba;s/\n\n/\n/g'
--        - first, cat the contents of header & data
--        - next (using sed) remove (backslash + carriage return + line feed)
--        - finally replace two carriage returns with one
--        - (for a detailed description of the two sed calls, see - http://stackoverflow.com/questions/1251999/sed-how-can-i-replace-a-newline-n)


-- sample input
/*
collectionCode,occurrenceID,catalogNumber,institutionCode,basisOfRecord,modified,scientificName,scientificNameAuthorship,kingdom,phylum,class,order,family,genus,specificEpithet,infraspecificEpithet,vernacularName,typeStatus,originalNameUsage,decimalLatitude,decimalLongitude,coordinateUncertaintyInMeters,geodeticDatum,locality,stateProvince,country,minimumElevationInMeters,maximumElevationInMeters,minimumDepthInMeters,maximumDepthInMeters,samplingProtocol,eventDate,preparations,sex,lifeStage,individualCount,identificationRemarks,identifiedBy
"Fishes/Biodiversity","urn:lsid:ozcam.taxonomy.org.au:QM:Fishes:Specimen:I27994","I27994","QM","Specimen","2011-09-29","Maccullochella peelii mariensis","","Animalia","Chordata","","Perciformes","Serranidae","Maccullochella","peelii mariensis","","","Holotype","","","","","","Tinana Ck, Bungawatta Stn, Mary River","Queensland","Australia","","","3m (9 13/16')","","Line - Handline","1984-02-09","Tank","","","","","Rowland, S"

"Fishes/Biodiversity","urn:lsid:ozcam.taxonomy.org.au:QM:Fishes:Specimen:I1884","I1884","QM","Specimen","2011-09-29","Carcharias taurus","","Animalia","Chordata","","Lamniformes","Odontaspididae","Carcharias","taurus","","","Holotype","Carcharias arenarius","","","","","Moreton Bay","Queensland","Australia","","","","","","","Display mount","","","","",""

"Fishes/Biodiversity","urn:lsid:ozcam.taxonomy.org.au:QM:Fishes:Specimen:I19180","I19180","QM","Specimen","2011-09-29","Atrobucca adusta","","Animalia","Chordata","","Perciformes","Sciaenidae","Atrobucca","adusta","","","Holotype","","","","","","Markham River mouth, near Lae","","Papua New Guinea","","","","","","","Spirit\
Otoliths","","","","","Sasaki, K"

"Fishes/Biodiversity","urn:lsid:ozcam.taxonomy.org.au:QM:Fishes:Specimen:I779","I779","QM","Specimen","2011-09-29","Galaxias occidentalis","","Animalia","Chordata","","Salmoniformes","Galaxiidae","Galaxias","occidentalis","","","Holotype","","","","","","Perth streams","Western Australia","Australia","","","","","","","Spirit","","","","",""

"Birds/Vertebrates/Biodiversity","urn:lsid:ozcam.taxonomy.org.au:QM:Birds:Specimen:O3604","O3604","QM","Specimen","2011-09-29","Trichoglossus haematodus moluccanus","","Animalia","Chordata","Aves","","LORIIDAE","Trichoglossus","haematodus","moluccanus","","Holotype","","","","","","Gladstone","Queensland","Australia","","","","","","1910-10-01","Skin","Male","","","",""

"Insects/Biodiversity","urn:lsid:ozcam.taxonomy.org.au:QM:Insects:Specimen:T11186","T11186","QM","Specimen","2011-09-29","Shelfordina robertsi","Roth","Animalia","Arthropoda","Insecta","Blattodea","Blattellidae","Shelfordina","robertsi","","","Paratype","","","","","","Mt Finnigan Summit via Helenvale, 1100 m.","Queensland","Australia","","","","","","","Pin\
Card\
Slide","","","","",""

"Birds/Vertebrates/Biodiversity","urn:lsid:ozcam.taxonomy.org.au:QM:Birds:Specimen:O19763","O19763","QM","Specimen","2011-09-29","Eulacestoma nigropectus nigropectus","","Animalia","Chordata","Aves","","PACHYCEPHALIDAE","Eulacestoma","nigropectus","nigropectus","","Holotype","","","","","","Mt Maneao","","Papua New Guinea","1722.1m","","","","","1894-04-22","Skin","Male","","","",""

"Insects/Biodiversity","urn:lsid:ozcam.taxonomy.org.au:QM:Insects:Specimen:T11280","T11280","QM","Specimen","2011-09-29","Shelfordina cooki","Roth","Animalia","Arthropoda","Insecta","Blattodea","Blattellidae","Shelfordina","cooki","","","Holotype","","","","","","Upper Boulder Creek, N.N.W. of Tully, N. QLD.","Queensland","Australia","","","","","","","Pin\
Card","","","","",""

"Insects/Biodiversity","urn:lsid:ozcam.taxonomy.org.au:QM:Insects:Specimen:T11281","T11281","QM","Specimen","2011-09-29","Shelfordina cooki","Roth","Animalia","Arthropoda","Insecta","Blattodea","Blattellidae","Shelfordina","cooki","","","Holotype","","","","","","Upper Boulder Creek, N.N.W. of Tully, N. QLD.","Queensland","Australia","","","","","","","Pin\
Card\
Slide","","","","",""

"Insects/Biodiversity","urn:lsid:ozcam.taxonomy.org.au:QM:Insects:Specimen:T11282","T11282","QM","Specimen","2011-09-29","Shelfordina cooki","Roth","Animalia","Arthropoda","Insecta","Blattodea","Blattellidae","Shelfordina","cooki","","","Holotype","","","","","","Mt Bartle-Frere, N. QLD","Queensland","Australia","","","","","","","Pin\
Card","","","","",""
*/


-- sample output
/*
collectionCode,occurrenceID,catalogNumber,institutionCode,basisOfRecord,modified,scientificName,scientificNameAuthorship,kingdom,phylum,class,order,family,genus,specificEpithet,infraspecificEpithet,vernacularName,typeStatus,originalNameUsage,decimalLatitude,decimalLongitude,coordinateUncertaintyInMeters,geodeticDatum,locality,stateProvince,country,minimumElevationInMeters,maximumElevationInMeters,minimumDepthInMeters,maximumDepthInMeters,samplingProtocol,eventDate,preparations,sex,lifeStage,individualCount,identificationRemarks,identifiedBy
"Fishes/Biodiversity","urn:lsid:ozcam.taxonomy.org.au:QM:Fishes:Specimen:I27994","I27994","QM","Specimen","2011-09-29","Maccullochella peelii mariensis","","Animalia","Chordata","","Perciformes","Serranidae","Maccullochella","peelii mariensis","","","Holotype","","","","","","Tinana Ck, Bungawatta Stn, Mary River","Queensland","Australia","","","3m (9 13/16')","","Line - Handline","1984-02-09","Tank","","","","","Rowland, S"
"Fishes/Biodiversity","urn:lsid:ozcam.taxonomy.org.au:QM:Fishes:Specimen:I1884","I1884","QM","Specimen","2011-09-29","Carcharias taurus","","Animalia","Chordata","","Lamniformes","Odontaspididae","Carcharias","taurus","","","Holotype","Carcharias arenarius","","","","","Moreton Bay","Queensland","Australia","","","","","","","Display mount","","","","",""
"Fishes/Biodiversity","urn:lsid:ozcam.taxonomy.org.au:QM:Fishes:Specimen:I19180","I19180","QM","Specimen","2011-09-29","Atrobucca adusta","","Animalia","Chordata","","Perciformes","Sciaenidae","Atrobucca","adusta","","","Holotype","","","","","","Markham River mouth, near Lae","","Papua New Guinea","","","","","","","Spirit\nOtoliths","","","","","Sasaki, K"
"Fishes/Biodiversity","urn:lsid:ozcam.taxonomy.org.au:QM:Fishes:Specimen:I779","I779","QM","Specimen","2011-09-29","Galaxias occidentalis","","Animalia","Chordata","","Salmoniformes","Galaxiidae","Galaxias","occidentalis","","","Holotype","","","","","","Perth streams","Western Australia","Australia","","","","","","","Spirit","","","","",""
"Birds/Vertebrates/Biodiversity","urn:lsid:ozcam.taxonomy.org.au:QM:Birds:Specimen:O3604","O3604","QM","Specimen","2011-09-29","Trichoglossus haematodus moluccanus","","Animalia","Chordata","Aves","","LORIIDAE","Trichoglossus","haematodus","moluccanus","","Holotype","","","","","","Gladstone","Queensland","Australia","","","","","","1910-10-01","Skin","Male","","","",""
"Insects/Biodiversity","urn:lsid:ozcam.taxonomy.org.au:QM:Insects:Specimen:T11186","T11186","QM","Specimen","2011-09-29","Shelfordina robertsi","Roth","Animalia","Arthropoda","Insecta","Blattodea","Blattellidae","Shelfordina","robertsi","","","Paratype","","","","","","Mt Finnigan Summit via Helenvale, 1100 m.","Queensland","Australia","","","","","","","Pin\nCard\nSlide","","","","",""
"Birds/Vertebrates/Biodiversity","urn:lsid:ozcam.taxonomy.org.au:QM:Birds:Specimen:O19763","O19763","QM","Specimen","2011-09-29","Eulacestoma nigropectus nigropectus","","Animalia","Chordata","Aves","","PACHYCEPHALIDAE","Eulacestoma","nigropectus","nigropectus","","Holotype","","","","","","Mt Maneao","","Papua New Guinea","1722.1m","","","","","1894-04-22","Skin","Male","","","",""
"Insects/Biodiversity","urn:lsid:ozcam.taxonomy.org.au:QM:Insects:Specimen:T11280","T11280","QM","Specimen","2011-09-29","Shelfordina cooki","Roth","Animalia","Arthropoda","Insecta","Blattodea","Blattellidae","Shelfordina","cooki","","","Holotype","","","","","","Upper Boulder Creek, N.N.W. of Tully, N. QLD.","Queensland","Australia","","","","","","","Pin\nCard","","","","",""
"Insects/Biodiversity","urn:lsid:ozcam.taxonomy.org.au:QM:Insects:Specimen:T11281","T11281","QM","Specimen","2011-09-29","Shelfordina cooki","Roth","Animalia","Arthropoda","Insecta","Blattodea","Blattellidae","Shelfordina","cooki","","","Holotype","","","","","","Upper Boulder Creek, N.N.W. of Tully, N. QLD.","Queensland","Australia","","","","","","","Pin\nCard\nSlide","","","","",""
"Insects/Biodiversity","urn:lsid:ozcam.taxonomy.org.au:QM:Insects:Specimen:T11282","T11282","QM","Specimen","2011-09-29","Shelfordina cooki","Roth","Animalia","Arthropoda","Insecta","Blattodea","Blattellidae","Shelfordina","cooki","","","Holotype","","","","","","Mt Bartle-Frere, N. QLD","Queensland","Australia","","","","","","","Pin\nCard","","","","",""
*/
