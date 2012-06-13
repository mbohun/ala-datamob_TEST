///**************************************************************************
// *  Copyright (C) 2011 Atlas of Living Australia
// *  All Rights Reserved.
// *
// *  The contents of this file are subject to the Mozilla Public
// *  License Version 1.1 (the "License"); you may not use this file
// *  except in compliance with the License. You may obtain a copy of
// *  the License at http://www.mozilla.org/MPL/
// *
// *  Software distributed under the License is distributed on an "AS
// *  IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
// *  implied. See the License for the specific language governing
// *  rights and limitations under the License.
// ***************************************************************************/


// pentaho-javascript to use conversion algorithms for converting from degrees decimal-minutes to decimal-degrees
//
// porting to javascript would require independent implementations of:
//  - num2str
//
// v1: 20120612: bk - using helper functions
//
// todo:
// - no plans to further develop at this stage

var sret = "";
var sretlon = "";

// lat/lon/precision for point
var dprec = null;
var sdlat = null;
var sdlon = null;
var sfootprintwkt = null;

// this variable will guide our logic (re_XXX are booleans 0 or 1, set in regex steps previous)
// converted to a string, boolean will be either "0" or "1"
// joined together, they will produce a switch that we can use 
// to determine which coordinates were successfully parsed
var sswitch = num2str(re_startlat) + num2str(re_finlat) + num2str(re_startlon) + num2str(re_finlon);

switch( sswitch ) {

// start & finish, lat & long's
case "1111" :
  // finish lat/long/precision for linestring (footprint wkt)
  var sflat = null;
  var sflon = null;
  var dfprec = null;

  // debugging notes if required
  sret += sswitch + " start & finish latitudes";
  sretlon += sswitch + " start & finish longitudes";

//writeToLog( "m", "> 1111: " + sdslatdeg + " " + sdslatmin + sslathem + "," + sdslondeg + " " + sdslonmin + sslonhem + ";" );

  // precision for the starting lat/lon (most precise from each decimal minute == precision of coordinates)
  dprec = dPrecisionDDM( sdslatmin, sdslonmin );
  // decimal-coordinates for the point
  sdlat = sConvertDDM( sdslatdeg, sdslatmin, sslathem, dprec );
  sdlon = sConvertDDM( sdslondeg, sdslonmin, sslonhem, dprec );

  // precision for the finishing lat/lon
  dfprec = dPrecisionDDM( sdflatmin, sdflonmin );
  // decimal-coordinates for the finishing point
  sflat = sConvertDDM( sdflatdeg, sdflatmin, sflathem, dfprec );
  sflon = sConvertDDM( sdflondeg, sdflonmin, sflonhem, dfprec );

  // footprint wkt - note: long (x), lat (y)
  sfootprintwkt = "LINESTRING (" + sdlon + " " + sdlat + ", " + sflon + " " + sflat + ")";

break;

// finish coord's only
case "0101" :
  sret += sswitch + " finish latitude";
  sretlon += sswitch + " finish longitude";

//writeToLog( "m", "> 0101: " + sdflatdeg + " " + sdflatmin + sflathem + "," + sdflondeg + " " + sdflonmin + sflonhem + ";" );

  dprec = dPrecisionDDM( sdflatmin, sdflonmin );
  sdlat = sConvertDDM( sdflatdeg, sdflatmin, sflathem, dprec );
  sdlon = sConvertDDM( sdflondeg, sdflonmin, sflonhem, dprec );

break;

// start coord's only
case "1010" :
  sret += sswitch + " start latitude";
  sretlon += sswitch + " start longitude";

//writeToLog( "m", "> 1010: " + sdslatdeg + " " + sdslatmin + sslathem + "," + sdslondeg + " " + sdslonmin + sslonhem + ";" );

  dprec = dPrecisionDDM( sdslatmin, sdslonmin );
  sdlat = sConvertDDM( sdslatdeg, sdslatmin, sslathem, dprec );
  sdlon = sConvertDDM( sdslondeg, sdslonmin, sslonhem, dprec );

break;

// no valid coordinates
default :
  sret += sswitch + " none";
  sretlon += sswitch + " none";

break;

}
