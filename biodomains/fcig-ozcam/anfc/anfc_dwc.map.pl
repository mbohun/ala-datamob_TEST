#!/usr/bin/perl

#/**************************************************************************
# *  Copyright (C) 2012 Atlas of Living Australia
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


package anfc_dwc;

# file contains map_find_state, map_find_country, map_find_ocean
require './anfc_dwc.map-cntryocn.pl';

# static list of month numbers
my %hMonthShortNum = (
	  'Jan' => '01'
	, 'Feb' => '02'
	, 'Mar' => '03'
	, 'Apr' => '04'
	, 'May' => '05'
	, 'Jun' => '06'
	, 'Jul' => '07'
	, 'Aug' => '08'
	, 'Sep' => '09'
	, 'Oct' => '10'
	, 'Nov' => '11'
	, 'Dec' => '12'
);

# parsing source dates using regex (expanded for clarity):
#    ^ start of the string
#    0+ spaces - [\s]{0,}
#    0/1 only instance of 1/2 digits - ([0-9]{1,2}){0,1}
#    0+ spaces - [\s]{0,}
#    0/1 only instance of 3 chars - ([a-zA-Z]{3}){0,1}
#    0+ spaces - [\s]{0,}
#    0/1 only instance of 4 digits - ([1-2][0-9]{3}){0,1}
#    0+ spaces - [\s]{0,}
#    $ end of the string
my $reSourceDate = '^[\s]{0,}([0-9]{1,2}){0,1}[\s]{0,}([a-zA-Z]{3}){0,1}[\s]{0,}([1-2][0-9]{3}){0,1}[\s]{0,}$';

# parse the start/finish lat/longs (degrees, decimal minutes)
#    start of the string, followed by 0+ spaces ^[\s]{0,}
#    1-3 digits - ([0-9]{1,3}) - followed by 1+ spaces - [\s]{1,}
#    0/1 only instance of 1+ digits - ([0-9.]{1,}){0,1} - followed by 0+ spaces - [\s]{0,}
#    0/1 only char - ([NSns]{0,1}) - followed by 0+ spaces to end of string - [\s]{0,}$
my $reSourceLat = '^[\s]{0,}([0-9]{1,3})[\s]{1,}([0-9.]{1,}){0,1}[\s]{0,}([NSns]{0,1})[\s]{0,}$';
my $reSourceLon = '^[\s]{0,}([0-9]{1,3})[\s]{1,}([0-9.]{1,}){0,1}[\s]{0,}([EWew]{0,1})[\s]{0,}$';

#---------------------------------------------------------------------
# map_record( \@arr_input, \@arr_output, \%hSrcHdrInd, \%hDwcHdrInd, \$serr )
# -	1st argument, a reference to an array containing the valid source data record
# - 2nd argument, a reference to an array that will receive the dwc record
# - 3rd argument, a reference to a hash that contains the source header indices, keyed by column name
# - 4th argument, a reference to a hash that contains the dwc header indices, keyed by dwc term
# - 5th argument, a reference to a string for the error (if any)
#
# returns 0 if unsuccessful, or positive number otherwise
#
#---------------------------------------------------------------------
sub map_record {
#---------------------------------------------------------------------

	my $ra_in = shift;
	my $ra_out = shift;
	my $rh_src = shift;
	my $rh_dwc = shift;
	my $rs_err = shift;

#$arr_values[$hSrcHdrInd{'species'}]

	if( !defined($rh_src) || !defined($rh_dwc) ) {
		$$rs_err = "ERROR: couldn't map record because dwc header and hash undefined.";
		return 0;
	}

	else {
		my ( $stmp, $stmp2, $smapwarning );
		my @atmp;

		# errors ending the mapping (ie. filters)

		# type information
		$stmp = $ra_in->[$rh_src->{'typestatus'}];
		# first off, this is a condition where a record won't be mapped
		if( $stmp eq 'Paratype (MS)' ) {
			$$rs_err = "ERROR: record 'typestatus' of 'Paratype (MS)' won't be mapped or exported";
			return 0;
		}
		# not type specimen
		elsif( ($stmp eq 'none') || ($stmp eq '') ) {
			# we'll leave these as null in the array
			# (which in turn will be empty strings in any csv output)
		}
		# type specimen
		else {
			$ra_out->[$rh_dwc->{'typestatus'}]				= $stmp;
			$ra_out->[$rh_dwc->{'typename'}]					= $ra_in->[$rh_src->{'typename'}];
			$ra_out->[$rh_dwc->{'typeauthor'}]				= $ra_in->[$rh_src->{'author'}];
			$ra_out->[$rh_dwc->{'typeyear'}]					= $ra_in->[$rh_src->{'typeyear'}];
		}
		undef $stmp;


		# constant values
		$ra_out->[$rh_dwc->{'basisOfRecord'}] 				= 'PreservedSpecimen';
		$ra_out->[$rh_dwc->{'dcterms:type'}] 					= 'PhysicalObject';
		$ra_out->[$rh_dwc->{'dcterms:rightsHolder'}]	= 'CSIRO';
		$ra_out->[$rh_dwc->{'institutionCode'}] 			= 'CSIRO';
		$ra_out->[$rh_dwc->{'collectionId'}] 					= 'urn:lsid:biocol.org:col:35151';
		$ra_out->[$rh_dwc->{'occurrenceStatus'}] 			= 'present';

		# 1:1 mappings
		$ra_out->[$rh_dwc->{'family'}]							= $ra_in->[$rh_src->{'Family'}];
		$ra_out->[$rh_dwc->{'genus'}]								= $ra_in->[$rh_src->{'Genus'}];
		$ra_out->[$rh_dwc->{'specificEpithet'}]			= $ra_in->[$rh_src->{'Species'}];
		$ra_out->[$rh_dwc->{'infraspecificName'}] 	= $ra_in->[$rh_src->{'Subspecies'}];
		$ra_out->[$rh_dwc->{'scientificName'}]			= $ra_in->[$rh_src->{'scientificname'}];
		$ra_out->[$rh_dwc->{'minimumdepth'}]				= $ra_in->[$rh_src->{'minimumdepth'}];
		$ra_out->[$rh_dwc->{'maximumdepth'}]				= $ra_in->[$rh_src->{'maximumdepth'}];


		# modifications
		$smapwarning = ''; # append to this; will be tested at end of function & assigned to $$rs_err

		# country, stateprovince, ocean, verbatim locality
		$stmpcountry = $ra_in->[$rh_src->{'country'}];
		$stmpstate = '';
		$stmpocean = '';
		$stmpverblocal = '';
		#
		# $stmpcountry is unexpected value: run around screaming
		if( ($stmpcountry ne 'yes') && ($stmpcountry ne 'no') && ($stmpcountry ne 'unknown') ) {
			$stmpstate = '';
			$stmpocean = '';
			$stmpverblocal = '';
			$smapwarning = ($smapwarning . 'WARNING: source value for \'country\' [' . $stmpcountry . '] unexpected; ');
		}
		#
		# country == 'yes' therefore is aus...
		#  - test state_territory against aus. state lookup: success to dwc.stateprovince, failure to dwc.verbatimlocality;
		#  - (no dwc.waterbody)
		elsif( $stmpcountry eq 'yes' ) {
			$stmpcountry = 'Australia';
			$stmpstate = $ra_in->[$rh_src->{'stateterritory'}];
			$stmp2 = '';
			# if state_territory is not in the valid states lookup...
			if( !defined(map_find_state($stmpstate, \$stmp2)) ) {
#print "\ncountry=yes,inval: \'$stmpstate\' - \'$stmp2\'";
				# move the value into dwc.verbatimlocality, as we can't be sure it is a valid dwc.stateprovince
				if( $stmpstate ne '' ) {
					$stmpverblocal = ($stmpverblocal . "state_territory: " . $stmpstate . "; ");
					$stmpstate = '';
				}
				# append locality detail as well
				$stmp2 = $ra_in->[$rh_src->{'locality'}];
				$stmpverblocal = ($stmpverblocal . "locality: " . $stmp2 . "; ") if( $stmp2 ne '' );
			}
			# otherwise state is valid
			else {
#print "\ncountry=yes: \'$stmpstate\' - \'$stmp2\'";
				# overwrite state with revised value if the lookup gave us one
				$stmpstate 			= $stmp2 if( $stmp2 ne '' );
				$stmp2 					= $ra_in->[$rh_src->{'locality'}];
				$stmpverblocal 	= $stmp2 if( $stmp2 ne '' );
			}
		}
		# country == 'no' therefore is not aus, or might be an ocean
		#  - test state_territory against country lookup: success to dwc.country, failure to dwc.verbatimlocality;
		#  - (no dwc.waterbody or dwc.stateprovince)
		elsif( $stmpcountry eq 'no' ) {
			$stmp = $ra_in->[$rh_src->{'stateterritory'}];
			$stmp2 = '';
			# nothing in stateterritory, therefore store locality
			if( $stmp eq '' ) {
				# append locality detail if it exists...
				$stmp2 = $ra_in->[$rh_src->{'locality'}];
				$stmpverblocal = ($stmpverblocal . "locality: " . $stmp2 . "; ") if( $stmp2 ne '' );
			}
			# if state_territory is in the valid country lookup...
			elsif( defined(map_find_country($stmp, \$stmp2)) ) {
				# set dwc.country with revised value if the lookup gave us one, store the old val.
				if( $stmp2 ne '' ) {
					$stmpcountry 		= $stmp2;
					$stmp2 					= $ra_in->[$rh_src->{'locality'}];
					$stmpverblocal 	= ($stmpverblocal . "state_territory: " . $stmp . "; ");
					$stmpverblocal 	= ($stmpverblocal . "locality: " . $stmp2 . "; ") if( $stmp2 ne '' );
					$stmpstate 			= '';
				}
				# set dwc.country to state_territory value otherwise
				else {
					$stmpcountry 		= $stmp;
					$stmp2 					= $ra_in->[$rh_src->{'locality'}];
					$stmpverblocal 	= $stmp2 if( $stmp2 ne '' );
					$stmpstate 			= '';
				}
			}
			# if state_territory is in the valid ocean lookup...
			elsif( defined(map_find_ocean($stmp, \$stmp2)) ) {
				# set dwc.waterbody with revised value if the lookup gave us one
				if( $stmp2 ne '' ) {
					$stmpocean 			= $stmp2;
					$stmp2 					= $ra_in->[$rh_src->{'locality'}];
					$stmpverblocal 	= ($stmpverblocal . "state_territory: " . $stmp . "; ");
					$stmpverblocal 	= ($stmpverblocal . "locality: " . $stmp2 . "; ") if( $stmp2 ne '' );
					$stmpstate 			= '';
				}
				# set dwc.waterbody to state_territory value otherwise
				else {
					$stmpocean 			= $stmp;
					$stmp2 					= $ra_in->[$rh_src->{'locality'}];
					$stmpverblocal 	= $stmp2 if( $stmp2 ne '' );
					$stmpstate 			= '';
				}
			}
			# otherwise country='no' and state_territory remains unmatched
			else {
				# move the value into dwc.verbatimlocality
				if( $stmp ne '' ) {
					$stmpverblocal = ($stmpverblocal . "state_territory: " . $stmp . "; ");
				}
				# append locality detail as well
				$stmp2 = $ra_in->[$rh_src->{'locality'}];
				$stmpverblocal = ($stmpverblocal . "locality: " . $stmp2 . "; ") if( $stmp2 ne '' );
				# drop a warning to the error log, in case a new mapping needs to be added
				$smapwarning = ($smapwarning . 'WARNING: \'' . $stmp . '\' not validated by map_find_country() or map_find_ocean() [anfc_dwc.map-cntrocn.pl]; ');
				$stmp = '';
			}
		}
		# country is 'unknown' due to state_territory being an ocean...
		#  - test state_territory against ocean lookup: success to ocean, failure to verbatimlocality; dwc.country = unknown;
		#  - (no dwc.stateprovince)
		elsif( $stmpcountry eq 'unknown' ) {
			$stmp = $ra_in->[$rh_src->{'stateterritory'}];
			$stmp2 = '';
			# if state_territory is not in the valid ocean lookup...
			if( !defined(map_find_ocean($stmp, \$stmp2)) ) {
#print "\ncountry=unkn,inval: \'$stmp\' - \'$stmp2\'";
				# move the value into dwc.verbatimlocality, as we can't be sure it is a valid dwc.country
				if( $stmp ne '' ) {
					$stmpverblocal = ($stmpverblocal . "state_territory: " . $stmp . "; ");
					$stmp = '';
				}
				# append locality detail as well
				$stmp2 = $ra_in->[$rh_src->{'locality'}];
				$stmpverblocal = ($stmpverblocal . "locality: " . $stmp2 . "; ") if( $stmp2 ne '' );
			}
			# otherwise ocean is valid
			else {
#print "\ncountry=unkn: \'$stmp\' - \'$stmp2\'";
				# set dwc.ocean with revised value if the lookup gave us one
				if( $stmp2 ne '' ) {
					$stmpocean 			= $stmp2;
				}
				# set dwc.country to state_territory value otherwise
				else {
					$stmpocean 			= $stmp;
				}
				$stmp2 						= $ra_in->[$rh_src->{'locality'}];
				$stmpverblocal 		= $stmp2 if( $stmp2 ne '' );
			}
		}
		# assign output values...
		$ra_out->[$rh_dwc->{'country'}]							= $stmpcountry;
		$ra_out->[$rh_dwc->{'stateProvince'}]				= $stmpstate;
		$ra_out->[$rh_dwc->{'waterBody'}]						= $stmpocean;
		$ra_out->[$rh_dwc->{'verbatimLocality'}]		= $stmpverblocal;
		undef $stmp; undef $stmp2; undef $stmpcountry; undef $stmpstate; undef $stmpocean; undef $stmpverblocal;
		#
		# old handling code
#		$stmp = "";
#		$stmp2 = $ra_in->[$rh_src->{'country'}];
#		$stmp = ($stmp . "country: " . $stmp2 . "; ") if( $stmp2 ne '' );
#		$stmp2 = $ra_in->[$rh_src->{'locality'}];
#		$stmp = ($stmp . "locality: " . $stmp2 . "; ") if( $stmp2 ne '' );
#		$stmp2 = $ra_in->[$rh_src->{'stateterritory'}];
#		$stmp = ($stmp . "state_territory: " . $stmp2 . "; ") if( $stmp2 ne '' );
#		$ra_out->[$rh_dwc->{'verbatimLocality'}]		= $stmp;
#		undef $stmp; undef $stmp2;


		# occurrence id, catalogue (and other cat) numbers
		$stmp = $ra_in->[$rh_src->{'catognumber'}];
		# strip trailing '-' from catognumber
		$stmp2 = $stmp;
		$stmp2 =~ s/-$//;		# strip trailing '-'
		$stmp2 =~ s/ //g;		# strip any ' '
		$ra_out->[$rh_dwc->{'catalogNumber'}]				= $stmp2;
		# store the original value in 'other catalogue numbers' if it differed
		$ra_out->[$rh_dwc->{'otherCatalogNumbers'}]	= $stmp if( $stmp ne $stmp2 );
		# store the occurrence id
		$stmp2 = 'urn:lsid:ozcam.taxonomy.org.au:CSIRO:Ichthyology:' . $stmp2;
		$ra_out->[$rh_dwc->{'occurrenceId'}]				= $stmp2;
		undef $stmp; undef $stmp2;


		# dcterms:modified
		$stmp = $ra_in->[$rh_src->{'dateentered'}];
		@atmp = $stmp =~ /$reSourceDate/g;
		if( defined(@atmp[2]) ) {
			$stmp2 = $atmp[2];
			if( defined(@atmp[1]) ) {
				$stmp2 = ($stmp2 . '-' . $hMonthShortNum{$atmp[1]});
				$stmp2 = ($stmp2 . '-' . $atmp[0]) if( defined(@atmp[0]) );
			}
			$ra_out->[$rh_dwc->{'dcterms:modified'}]	= $stmp2;
		}
		$ra_out->[$rh_dwc->{'verbatimModified'}]		= $stmp;
		$#atmp = -1; undef @atmp;
		undef $stmp; undef $stmp2;

		# event date
		$stmp = $ra_in->[$rh_src->{'datecollected'}];
		@atmp = $stmp =~ /$reSourceDate/g;
		if( defined(@atmp[2]) ) {
			$stmp2 = $atmp[2];
			if( defined(@atmp[1]) ) {
				$stmp2 = ($stmp2 . '-' . $hMonthShortNum{$atmp[1]});
				$stmp2 = ($stmp2 . '-' . $atmp[0]) if( defined(@atmp[0]) );
			}
			$ra_out->[$rh_dwc->{'eventDate'}]	= $stmp2;
		}
		$ra_out->[$rh_dwc->{'verbatimEventDate'}]		= $stmp;
		$#atmp = -1; #undef @atmp;
		undef $stmp; undef $stmp2;

		# coordinates, footprintwkt, precision
		my $sdlat;	# a variable that will receive the latitude
		my $sdlon;	# a variable that will receive the longitude
		my $sfwkt;	# a variable that will receive the footprint-wkt
		my $scprec;	# a variable that will receive the coordinate precision
		my $sverlat;	# a variable that will receive the verbatim latitude
		my $sverlon;	# a variable that will receive the verbatim longitude
		# attempt the mapping...
		$stmp = map_coords(
		  \$sdlat, \$sdlon, \$sfwkt, \$scprec, \$sverlat, \$sverlon
			, $ra_in->[$rh_src->{'s latitude'}]
			, $ra_in->[$rh_src->{'s longitude'}]
			, $ra_in->[$rh_src->{'f latitude'}]
			, $ra_in->[$rh_src->{'f longitude'}]
			, \$stmp2
		);
		# ... store data if we were successful (!= 0)
		if( $stmp ) {
			$ra_out->[$rh_dwc->{'decimalLatitude'}]			= $sdlat;
			$ra_out->[$rh_dwc->{'decimalLongitude'}]		= $sdlon;
			$ra_out->[$rh_dwc->{'footprintWKT'}]				= $sfwkt;
			$ra_out->[$rh_dwc->{'coordinatePrecision'}]	= $scprec;
		}
		# we tried, but failed
		# $stmp2 should've been populated with some words, which we handle separately
		else {
			# at this point, we continue mapping anyway ...
			#return 1;
		}
		# if there were any errors or warnings with map_coords, append them to any other ones
		$smapwarning = ($smapwarning . $stmp2) if( defined($stmp2) );

		# store the verbatim data anyway regardless of success or failure
		# (just incase we're unable to parse something)
		$ra_out->[$rh_dwc->{'verbatimLatitude'}]		= $sverlat;
		$ra_out->[$rh_dwc->{'verbatimLongitude'}]		= $sverlon;
		undef $stmp, $stmp2;

		# if there was a warning issued, store it in the error pointer...
		if( length($smapwarning) > 0 ) {
			if( defined($$rs_err) ) {
				$$rs_err = $$rs_err . '; ' . $smapwarning		if( length($$rs_err) > 0 );
				$$rs_err = $smapwarning											if( length($$rs_err) <= 0 );
			}
			else {
				$$rs_err = $smapwarning;
			}
		}

		return 1;
	}

#---------------------------------------------------------------------
}
#map_record



#---------------------------------------------------------------------
# map_dwc_header( \@arrDwcHeader, \%hDwcHdrInd, \$serr )
# -	1st argument, a reference to an array that will receive the dwc header
# - 2nd argument, a reference to a hash that will receive the dwc header indices, keyed by dwc term
# - 3rd argument, a reference to a string for the error (if any)
#
# returns 0 if unsuccessful, or positive number otherwise
#
#---------------------------------------------------------------------
sub map_dwc_header {
#---------------------------------------------------------------------

	my $ra_dwchdr = shift;
	my $rh_dwchdrind = shift;
	my $rs_err = shift;

	@$ra_dwchdr = (
		'basisOfRecord',
		'dcterms:type',
		'dcterms:rightsHolder',
		'institutionCode',
		'collectionId',
		'occurrenceStatus',
		'occurrenceId',
		'catalogNumber',
		'otherCatalogNumbers',
		'verbatimModified',
		'dcterms:modified',
		'family',
		'genus',
		'specificEpithet',
		'infraspecificName',
		'scientificName',
		'verbatimLocality',
		'stateProvince',
		'country',
		'waterBody',
		'minimumdepth',
		'maximumdepth',
		'verbatimEventDate',
		'eventDate',
		'decimalLatitude',
		'decimalLongitude',
		'coordinatePrecision',
		'footprintWKT',
		'verbatimLatitude',
		'verbatimLongitude',
		'typename',
		'typestatus',
		'typeauthor',
		'typeyear'
	);

	# store the index of each column against the column name in a hash
	# this allows us to reference a value by column name without knowing its index
	# eg. $arr_values[$hSrcHdrInd{'species'}]
	for( my $i = 0; $i < scalar(@$ra_dwchdr); $i++ ) {
#print "key [$i] \'$$ra_dwchdr[$i]\' => $i\n";
		# there are multiple columns with the same name... (ambiguous case)
		if( !exists( $rh_dwchdrind->{$$ra_dwchdr[$i]} ) ) {
			# key 'column name' = i_array_index
			$rh_dwchdrind->{$$ra_dwchdr[$i]} = $i;
		}
		# we use the earlier column (contrary to source data) and ignore latter duplicate columns
		#else {
		#}
	}

	return 1;
#---------------------------------------------------------------------
}
#map_dwc_header


#---------------------------------------------------------------------
#	map_coords -
#		receives start and finish coordinates in the form of degrees, decimal minutes
#		validates input and populates output with:
#			decimal degrees representations,
#			precision,
#			footprint-wkt and
#			verbatim input
#---------------------------------------------------------------------
sub map_coords {
#---------------------------------------------------------------------
	# references to storage for outputs
	my $rs_sdlat = shift;		# a variable that will receive the latitude
	my $rs_sdlon = shift;		# a variable that will receive the longitude
	my $rs_sfwkt = shift;		# a variable that will receive the footprint-wkt
	my $rs_sprec = shift;		# a variable that will receive the coordinate precision
	my $rs_sverlat = shift;	# a variable that will receive verbatim latitude
	my $rs_sverlon = shift;	# a variable that will receive verbatim longitude

	# input data
	my $sstartlat = shift;
	my $sstartlon = shift;
	my $sfinlat = shift;
	my $sfinlon = shift;

	# ref buffer for output error(s)
	my $rs_err = shift;

	# return value (0 = failure, otherwise success)
	my $iret = 0;
	# error buffer
	my $serr;

	# lat/lon/precision for point (output stored locally, will be copied to references passed in)
	my $dprec;
	my $sdlat;
	my $sdlon;
	my $sfootprintwkt;
	my $sverlat;
	my $sverlon;

	# tuples from the coordinates
	my ( $sdslatdeg, $sdslatmin, $sslathem );	# start lat
	my ( $sdflatdeg, $sdflatmin, $sflathem );	# finish lat
	my ( $sdslondeg, $sdslonmin, $sslonhem );	# start lon
	my ( $sdflondeg, $sdflonmin, $sflonhem );	# finish lon

	# each char is a (0 or 1) placeholder for the input data:
	# 	'<startlat valid?><finlat valid?><startlon valid?><finlon valid?>'
	# this 4-char string will produce a switch that we can use to determine
	# which coordinates were successfully parsed by the regex $reSourceLat/Lon
	# default to 'no coordinates' (which is a successful condition that results in doing nothing)
	my $sswitch = '0000';

	# parse start/fin lat/lon's, build sverlat/lon, sswitch, etcet.
	{
		# buffer for parsing the tuples
		my @acoord;

		# populate verbatim as well
		$sverlat = '';
		$sverlon = '';

		# trim trailing spaces then chunk start lat
		if( defined($sstartlat) ) {
			$sstartlat =~ s/\s+$//;
			if( length($sstartlat) > 0 ) {
				$sverlat = $sverlat . 'start_lat: ' . $sstartlat . '; ';
				@acoord = $sstartlat =~ /$reSourceLat/g;
				if( defined(@acoord[2]) ) {
					( $sdslatdeg, $sdslatmin, $sslathem ) = @acoord;
					substr($sswitch, 0, 1) = '1';
				}
				$#acoord = -1; undef @acoord;
			}
		}

		# trim trailing spaces then chunk finish lat
		if( defined($sfinlat) ) {
			$sfinlat =~ s/\s+$//;
			if( length($sfinlat) > 0 ) {
				$sverlat = $sverlat . 'finish_lat: ' . $sfinlat . '; ';
				@acoord = $sfinlat =~ /$reSourceLat/g;
				if( defined(@acoord[2]) ) {
					( $sdflatdeg, $sdflatmin, $sflathem ) = @acoord;
					substr($sswitch, 1, 1) = '1';
				}
				$#acoord = -1; undef @acoord;
			}
		}

		# trim trailing spaces then chunk start lon
		if( defined($sstartlon) ) {
			$sstartlon =~ s/\s+$//;
			if( length($sstartlon ) > 0 ) {
				$sverlon = $sverlon . 'start_lon: ' . $sstartlon . '; ';
				@acoord = $sstartlon =~ /$reSourceLon/g;
				if( defined(@acoord[2]) ) {
					( $sdslondeg, $sdslonmin, $sslonhem ) = @acoord;
					substr($sswitch, 2, 1) = '1';
				}
				$#acoord = -1; undef @acoord;
			}
		}

		# trim trailing spaces then chunk finish lon
		if( defined($sfinlon) ) {
			$sfinlon =~ s/\s+$//;
			if( length($sfinlon) > 0 ) {
				$sverlon = $sverlon . 'finish_lon: ' . $sfinlon . '; ';
				@acoord = $sfinlon =~ /$reSourceLon/g;
				if( defined(@acoord[2]) ) {
					( $sdflondeg, $sdflonmin, $sflonhem ) = @acoord;
					substr($sswitch, 3, 1) = '1';
				}
				$#acoord = -1; undef @acoord;
			}
		}
	} # end parse start/fin lat/lon's, build sverlat/lon, sswitch, etcet.

#print "\$sstartlat = $sstartlat; ";
#print "\$sfinlat = $sfinlat; ";
#print "\$sstartlon = $sstartlon; ";
#print "\$sfinlon = $sfinlon; ";

	# warning conditions
	if( $sswitch eq '1011' ) { 	# startlat, finlat, startlon, finlon
		$serr = 'WARNING: mapped valid start lat+long only, because of invalid finish lat (despite valid finish lon)';
		$sswitch = '1010';
	}
	elsif( $sswitch eq '1101' ) { 	# startlat, finlat, startlon, finlon
		$serr = 'WARNING: mapped valid finish lat+long only, because of invalid start lon (despite valid start lat)';
		$sswitch = '0101';
	}

#print "\$sswitch = $sswitch; ";

	if( $sswitch eq '1111' ) { 	# startlat, finlat, startlon, finlon
	  # finish lat/long/precision for linestring (footprint wkt)
	  my $sflat; #= null;
	  my $sflon; #= null;
	  my $dfprec; #= null;

	  # precision for the starting lat/lon (most precise from each decimal minute == precision of coordinates)
	  $dprec = dPrecisionDDM( $sdslatmin, $sdslonmin );
	  # precision for the finishing lat/lon
	  $dfprec = dPrecisionDDM( $sdflatmin, $sdflonmin );
	  # the most precise from each decimal minute becomes the precision of coordinates
	  $dprec = $dfprec	if( $dfprec < $dprec );

	  # decimal-coordinates for the starting point
	  $sdlat = sConvertDDM( $sdslatdeg, $sdslatmin, $sslathem, $dprec );
	  $sdlon = sConvertDDM( $sdslondeg, $sdslonmin, $sslonhem, $dprec );
	  # decimal-coordinates for the finishing point
	  $sflat = sConvertDDM( $sdflatdeg, $sdflatmin, $sflathem, $dprec );
	  $sflon = sConvertDDM( $sdflondeg, $sdflonmin, $sflonhem, $dprec );

	  # footprint wkt - note: long (x), lat (y)
	  $sfootprintwkt = "LINESTRING (" . $sdlon . " " . $sdlat . ", " . $sflon . " " . $sflat . ")";

	  $iret = 1;
	}

	# finish coord's only
	elsif( $sswitch eq '0101' ) { 	# startlat, finlat, startlon, finlon
	  $dprec = dPrecisionDDM( $sdflatmin, $sdflonmin );
	  $sdlat = sConvertDDM( $sdflatdeg, $sdflatmin, $sflathem, $dprec );
	  $sdlon = sConvertDDM( $sdflondeg, $sdflonmin, $sflonhem, $dprec );

	  $iret = 1;
	}

	# start coord's only
	elsif( $sswitch eq '1010' ) { 	# startlat, finlat, startlon, finlon
	  $dprec = dPrecisionDDM( $sdslatmin, $sdslonmin );
	  $sdlat = sConvertDDM( $sdslatdeg, $sdslatmin, $sslathem, $dprec );
	  $sdlon = sConvertDDM( $sdslondeg, $sdslonmin, $sslonhem, $dprec );

	  $iret = 1;
	}

	# no coordinates (valid condition)
	elsif( $sswitch eq '0000' ) { 	# startlat, finlat, startlon, finlon
	  $iret = 1;
	}

	# no valid coordinates (other error conditions)
	else {
		$serr = "WARNING: unable to map coords; switch($sswitch) latitudes('$sstartlat', '$sfinlat') longitudes('$sstartlon', '$sfinlon')";
	}

#print "\$dprec = $dprec; ";
#print "\$sdlat = $sdlat; ";
#print "\$sdlon = $sdlon; ";
#print "\$sfootprintwkt = $sfootprintwkt; ";
#print "\$sret = $sret; ";
#print "\$sretlon = $sretlon; ";

	$$rs_sdlat = $sdlat;
	$$rs_sdlon = $sdlon;
	$$rs_sfwkt = $sfootprintwkt;
	$$rs_sprec = $dprec; #sprintf( "%u", $dprec );
	$$rs_sverlat = $sverlat;
	$$rs_sverlon = $sverlon;
	$$rs_err = $serr;

	return $iret;
#---------------------------------------------------------------------
}


############################


#bk

#---------------------------------------------------------------------
sub sConvertDDM {
#---------------------------------------------------------------------

	my $sdeg = shift;
	my $smin = shift;
	my $shem = shift;
	my $dprec = shift;

  my $ihemmult = 1;
  my $dret = 0;

  # check to see if the result should be negative
  $ihemmult = -1	if( (lc($shem) eq 'w') || (lc($shem) eq 's') );

  # default to 0 decimal places, unless otherwise specified...
  if( !defined($smin) || !defined($dprec) || ($dprec < 0)  ) {
    # assign dret the value of (degrees * hemisphere multiplier)
    $dret = ($sdeg * $ihemmult);

    # return the string representation of the number, with no decimal places
    return $dret;
  }

  # work out the minutes, truncated to n decimal places according to the precision
  # for bitwise shift forcing scalar to whole number, see:
  #    http://perldoc.perl.org/perlnumber.html#Flavors-of-Perl-numeric-operations
  # eg: 34.2341, 0.001
  #     34.2341 * (1 / 0.001) [1000]
  #   = 34234.1 << 0
  #   = (34234 / 60) << 0
  #   = 570 / 1000
  #   = 0.057
  else {
    my $dmins;
    my $iprec;
    my $imins;
    my $iminmult;

    # get the inverse of the precision...
    $iprec = (1 / $dprec)	if( $dprec > 0 );
    $iprec = 1						if( $dprec <= 0 );

    # build the integer for division by 60
    # (left shift truncates numbers after the decimal point)
    $iminmult = ($smin * $iprec) << 0;

    # divide minutes by 60 (ie. step towards converting to points of a degree)
    # truncate the result (ie. discard any false precision)
    $imins = ($iminmult / 60) << 0;

    # now return the minutes to the right-hand side of the decimal point (decimal degrees)
    $dmins = ( $imins / $iprec );

    # assign dret the value of (degrees + (mins / inverse of precision)) * hemisphere multiplier
    $dret = (($sdeg) + $dmins) * $ihemmult;

#writeToLog( "m", "> sConvert: " + num2str(sminmult) + "," + num2str(str2num(sminmult)/60) + "," + imins + "," + num2str(dmins) + "," + sformatprec + "," + ihemmult + "," + num2str(dret, sformatprec) + ";" );

#print "\$iprec $iprec | ";
#print "\$iminmult $iminmult | ";
#print "\$imins $imins | ";
#print "\$dmins $dmins | ";
#print "\$ihemmult $ihemmult | ";
#print "\$shem $shem | ";
#print "\$dret $dret | ";
    # return the string representation of the number
    return $dret;
  }
}

# start with no precision, adjust the output to the
# most precise of both the start & finish minute strings
# return the result as a decimal between 0 and 1
#
# with the both minutes components:
#   no decimal places (ie. one sixtieth of a degree) = 0.001
#   one decimal place (ie. one tenth of a minute)    = 0.0001
#   two or more decimal places (ie. < one hundredth) = 0.00001
#   otherwise, 0
#
#---------------------------------------------------------------------
sub dPrecisionDDM {
#---------------------------------------------------------------------
	my $sstartmin = shift;
	my $sfinmin = shift;

  my $dprec = 0;

  my @achars;

#writeToLog("m", "> dPrecision: for minute-components [" + sstartmin + "," + sfinmin + "]");

  # minutes at starting point
  @achars = split( //, $sstartmin );

#print Dumper \@achars;

  if( ($#achars > 0) && isNum($sstartmin) ) {
    my $is;
    my $imc = 1000;

    # walk backwards through the string
    for( $is = $#achars; $is >= 0; $is-- ) {
      # if this is the decimal point, we've reached our goal!
      if( ($achars[$is] == '.') ) {
        # set the precision to the inverse of the number of units
        if( ($dprec == 0) || ((1 / $imc) < $dprec) ) {
          $dprec = (1 / $imc);
        }
        # no more passes for the start minutes
        last;
      }
      # otherwise, for each valid numerical unit, increment the multiplier by 10
      elsif( isNum($achars[$is]) ) {
        $imc *= 10;
      }

      # we may get to here if there are no decimal places
      # that's fine, in this case we don't touch dprec (leaving it at 0)
      if( $is == 1 ) {
        $dprec = 0.001;
      }
    }

#writeToLog("m", "> dPrecision:  [" + sstartmin + "]  " + is + ", " + imc + ", " + dprec + ";");
  }
  $#achars = -1; undef @achars;

  # minutes at finishing point
  @achars = split( //, $sfinmin );

#print Dumper \@achars;

  if( ($#achars > 0) && isNum($sfinmin) ) {
    my $is;
    my $imc = 1000;

    # walk backwards through the string
    for( $is = $#achars; $is >= 0; $is-- ) {
      # if this is the decimal point, we've reached our goal!
      if( ($achars[$is] == '.') ) {
        # set the precision to the inverse of the number of units
        if( ($dprec == 0) || ((1 / $imc) < $dprec) ) {
          $dprec = (1 / $imc);
        }
        # no more passes for the start minutes
        last;
      }
      # otherwise, for each valid numerical unit, increment the multiplier by 10
      elsif( isNum($achars[$is]) ) {
        $imc *= 10;
      }

      # we may get to here if there are no decimal places
      # that's fine, in this case we don't touch dprec (leaving it at 0)
      if( $is == 1 ) {
        $dprec = 0.001;
      }
    }

#writeToLog("m", "> dPrecision:  [" + sstartmin + "]  " + is + ", " + imc + ", " + dprec + ";");
  }

  return $dprec;
#---------------------------------------------------------------------
}


#---------------------------------------------------------------------
sub isNum {
#---------------------------------------------------------------------
	my $stest = shift;
	my $iret = 0;

	if( length($stest) > 0 ) {
		$iret = ($stest * 1)	if( ($stest * 1) == $stest );
	}

	return $iret;
#---------------------------------------------------------------------
}


#---------------------------------------------------------------------
1; # need to end with a true value, otherwise 'require' call will fail
#---------------------------------------------------------------------
