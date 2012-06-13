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


// pentaho-javascript to safely convert to decimal degrees
// ... note: the only format supported at this stage (201206) is degrees, decimal minutes
//
// porting to javascript would require independent implementations of:
//  - num2str, str2num, fillString, getDigitsOnly, isNum?
//
// v1: 20120612: bk - helper functions to convert degrees decimal-minutes to decimal-degrees
//
// todo:
// - no plans to further develop at this stage


function sConvertDDM( sdeg, smin, shem, dprec ) {
  var ihemmult = 1;
  var dret = 0;

  // check to see if the result should be negative
  switch( lower(shem) ) {

  case "w" :
  case "s" :
    ihemmult = -1;

  break;
  }

  // default to 0 decimal places, unless otherwise specified...
  if( (smin == null) || (dprec == null) || (dprec < 0)  ) {
    // assign dret the value of (degrees * hemisphere multiplier)
    dret = ( str2num(sdeg) * ihemmult );

    // return the string representation of the number, with no decimal places
    return num2str( dret, "0" );
  }

  // work out the minutes, truncated to n decimal places according to the precision
  else {
    var dmins;
    var iprec, imins;
    var sformatprec, sminmult, smindigs, smintrail;

    // get the inverse of the precision...
    iprec = (1 / dprec);

    // build a formatting string based on iprec (eg. 0.000)
    sformatprec = "0." + fillString( "0", (num2str(iprec).length - 2) );

    // will remove any non-digit values (including decimal point)
    smindigs = getDigitsOnly( smin );
    // will build a trailing number of zeroes out to the inverse of the precision
    smintrail = fillString( "0", (num2str(iprec).length - smindigs.length) );

    // build the integer for division by 60
    sminmult = smindigs + smintrail;

    // divide minutes by 60 (ie. step towards converting to points of a degree)
    // truncate the result (discard any false precision)
    imins = trunc( str2num(sminmult) / 60 );

    // now return the minutes to the right-hand side of the decimal point (decimal degrees)
    dmins = ( imins / iprec );

    // assign dret the value of (degrees + (mins / inverse of precision)) * hemisphere multiplier
    dret = (str2num(sdeg) + dmins) * ihemmult;

//writeToLog( "m", "> sConvert: " + num2str(sminmult) + "," + num2str(str2num(sminmult)/60) + "," + imins + "," + num2str(dmins) + "," + sformatprec + "," + ihemmult + "," + num2str(dret, sformatprec) + ";" );

    // return the string representation of the number
    return num2str( dret, sformatprec );
  }
}

// start with no precision, adjust the output to the 
// most precise of both the start & finish minute strings
// return the result as a decimal between 0 and 1
//
// with the both minutes components:
//   no decimal places (ie. one sixtieth of a degree) = 0.001
//   one decimal place (ie. one tenth of a minute)    = 0.0001
//   two or more decimal places (ie. < one hundredth) = 0.00001
//   otherwise, 0
//
function dPrecisionDDM( sstartmin, sfinmin ) {
  var dprec = 0;

//writeToLog("m", "> dPrecision: for minute-components [" + sstartmin + "," + sfinmin + "]");

  // minutes at starting point
  if( (sstartmin != null) && isNum(sstartmin) ) {
    var is, imc = 1000;

    // walk backwards through the string
    for( is = (sstartmin.length - 1); is >= 0; is-- ) {
      // if this is the decimal point, we've reached our goal!
      if( (sstartmin[is] == ".") ) {
        // set the precision to the inverse of the number of units
        if( (dprec == 0) || ((1 / imc) < dprec) ) {
          dprec = (1 / imc);
        }
        // no more passes for the start minutes
        break;
      }
      // otherwise, for each valid numerical unit, increment the multiplier by 10
      else if( isNum(sstartmin[is]) ) {
        imc *= 10;
      }

      // we may get to here if there are no decimal places
      // that's fine, in this case we don't touch dprec (leaving it at 0)
      if( is == 1 ) {
        dprec = 0.001;
      }
    }

//writeToLog("m", "> dPrecision:  [" + sstartmin + "]  " + is + ", " + imc + ", " + dprec + ";");
  }

  // minutes at finishing point
  if( (sfinmin != null) && isNum(sfinmin) ) {
    var is, imc = 1000;

    // walk backwards through the string
    for( is = (sfinmin.length - 1); is >= 0; is-- ) {
      // if this is the decimal point, we've reached our goal!
      if( (sfinmin[is] == ".") ) {
        // set the precision to the inverse of the number of units
        if( (dprec == 0) || ((1 / imc) < dprec) ) {
          dprec = (1 / imc);
        }
        // no more passes for the start minutes
        break;
      }
      // otherwise, for each valid numerical unit, increment the multiplier by 10
      else if( isNum(sfinmin[is]) ) {
        imc *= 10;
      }

      // we may get to here if there are no decimal places
      // that's fine, in this case we don't touch dprec (leaving it at 0)
      if( is == 1 ) {
        dprec = 0.001;
      }
    }

//writeToLog("m", "> dPrecision:  [" + sfinmin + "]  " + is + ", " + imc + ", " + dprec + ";");
  }

  return dprec;
}
