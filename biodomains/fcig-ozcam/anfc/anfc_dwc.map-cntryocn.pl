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

# static list of state maps
#
# 1. first look up your state string in here (see: map_find_state)
# 2. if you find a matching key, the state is valid
# 3. if you find a value != empty string ('') then you should consider that state has a new value for your mapping target
# 4. you may wish to keep the old value for clarification
#
my %hStateMap = (

	  'NSW' => 'New South Wales'
	, 'Qld' => 'Queensland'
	, 'QLD' => 'Queensland'
	, 'SA' => 'South Australia'
	, 'Tas' => 'Tasmania'
	, 'Vic' => 'Victoria'
	, 'WA' => 'Western Australia'
	, 'NT' => 'Northern Territory'

);

# static list of ocean maps
#
# 1. first look up your ocean string in here (see: map_find_ocean)
# 2. if you find a matching key, the ocean is valid
# 3. if you find a value != empty string ('') then you should consider that ocean has a new value for your mapping target
# 4. you may wish to keep the old value for clarification
#
my %hOceanMap = (

	  'Arafura Sea' => ''
	, 'Atlantic Ocean' => ''
	, 'Bismarck Sea' => ''
	, 'Coral Sea' => ''
	, 'Indian Ocean' => ''
	, 'North Atlantic Ocean' => ''
	, 'North Pacific Ocean' => ''
	, 'Pacific Ocean' => ''
	, 'South Atlantic Ocean' => ''
	, 'South Pacific Ocean' => ''
	, 'Southern Ocean' => ''
	, 'Tasman Sea' => ''

);

# static list of country maps
#
# 1. first look up your country string in here (see: map_find_country)
# 2. if you find a matching key, the country is valid
# 3. if you find a value != empty string ('') then you should consider that country has a new value for your mapping target
# 4. you may wish to keep the old value for clarification
#
my %hCountryMap = (
  # this is a list of potential country values, populated from an anfc listing june 2013

	# not mapped, nor considered valid due to their being commented-out (ie, absent from lookup)
	#, 'Antarctica' => ''
	#, 'Asia' => ''

	# mapped to Australia
	  'Australia' => ''
	, 'Heard Island' => 			'Australia'
	, 'Lord Howe Island' => 	'Australia'
	, 'Macquarie Island' => 	'Australia'
	, 'Norfolk Island' => 		'Australia'

  # mapped to PNG
	, 'PNG' => ''
	, 'Admiralty Islands' => 	'PNG'
	, 'Duke of York Group' =>	'PNG'
	, 'New Britain' =>  			'PNG'
	, 'New Hanover' =>  			'PNG'
	, 'New Ireland' =>  			'PNG'
	, 'Trobriand Islands' => 	'PNG'

	# mapped to Indonesia
	, 'Indonesia' => ''
	, 'Dutch New Guinea' =>		'Indonesia'
	, 'Irian Jaya' =>					'Indonesia'
	, 'Java' =>								'Indonesia'

	# other possible values, made valid by their presence in the hash
	, 'Argentina' => ''
	, 'Bahrain' => ''
	, 'Brazil' => ''
	, 'Cambodia' => ''
	, 'Canada' => ''
	, 'Chile' => ''
	, 'China' => ''
	, 'Cook Islands' => ''
	, 'Denmark' => ''
	, 'England' => ''
	, 'France' => ''
	, 'French Polynesia' => ''
	, 'Greenland' => ''
	, 'Hong Kong' => ''
	, 'India' => ''
	, 'Israel' => ''
	, 'Japan' => ''
	, 'Kiribati' => ''
	, 'Kuwait' => ''
	, 'Malaysia' => ''
	, 'Mexico' => ''
	, 'Monaco' => ''
	, 'Myanmar' => ''
	, 'New Caledonia' => ''
	, 'New Zealand' => ''
	, 'Oman' => ''
	, 'Peru' => ''
	, 'Philippines' => ''
	, 'Portugal' => ''
	, 'Qatar' => ''
	, 'Singapore' => ''
	, 'Solomon Islands' => ''
	, 'South Africa' => ''
	, 'Sri Lanka' => ''
	, 'Taiwan' => ''
	, 'Thailand' => ''
	, 'United Arab Emirates' => ''
	, 'USA' => ''
	, 'Vietnam' => ''
	, 'Yemen' => ''

);


#---------------------------------------------------------------------
# map_find_state( \$serr )
# -	1st argument, 
# - 2nd argument, 
#
# returns undef if unsuccessful, or otherwise
#
#---------------------------------------------------------------------
sub map_find_state {
#---------------------------------------------------------------------

	my $stest = shift;
	my $rs_return = shift;

	if( exists($hStateMap{$stest}) ) {
		$$rs_return = $hStateMap{$stest};
		return 1;
	}
	else {
		return undef;
	}

#---------------------------------------------------------------------
} 
#map_find_state

#---------------------------------------------------------------------
# map_find_country( \$serr )
# -	1st argument, 
# - 2nd argument, 
#
# returns undef if unsuccessful, or otherwise
#
#---------------------------------------------------------------------
sub map_find_country {
#---------------------------------------------------------------------

	my $stest = shift;
	my $rs_return = shift;

	if( exists($hCountryMap{$stest}) ) {
		$$rs_return = $hCountryMap{$stest};
		return 1;
	}
	else {
		return undef;
	}

	return undef;

#---------------------------------------------------------------------
} 
#map_find_country

#---------------------------------------------------------------------
# map_find_ocean( \$serr )
# -	1st argument, 
# - 2nd argument, 
#
# returns undef if unsuccessful, or otherwise
#
#---------------------------------------------------------------------
sub map_find_ocean {
#---------------------------------------------------------------------

	my $stest = shift;
	my $rs_return = shift;

	if( exists($hOceanMap{$stest}) ) {
		$$rs_return = $hOceanMap{$stest};
		return 1;
	}
	else {
		return undef;
	}

#---------------------------------------------------------------------
} 
#map_find_ocean


#---------------------------------------------------------------------
1; # need to end with a true value, otherwise 'require' call will fail
#---------------------------------------------------------------------
