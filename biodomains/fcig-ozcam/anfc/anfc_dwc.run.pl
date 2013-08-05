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

# code in this file contains the 'plumbing' -
# reading data in, writing mapped data, catching errors and writing logs
#
# it relies on another file to provide the header and data mapping to the target spec, simple-dwc
# (the mapping is easier to read, and theoretically, the mapping could be used elsewhere)
#
# it flows roughly as:
# 1. process the cmd-line arguments
# 2. read the input file until we find a header row (>0 fields separated by the delimiter)
# 3. process the header row
# 4. read the input file until we find a data row (#fields matching #columns in the header)
# 5. process the data row & write to output recipient (file, stdout, ...)
# 6. when there are no more data rows, summarise and finish up
#


#use strict; use warnings;

# NOTE:
# Text::CSV for input didn't work - no surprises there as many text-parser libraries don't allow
# for more than one char as the delimiter... as a result, we must parse the line;
#
#my $csv = Text::CSV_XS->new ({
#	binary                => 0,
#	eol                   => "\n",
#	sep_char              => '+|',
#});
#
# we will use it for output though
use Text::CSV;

use POSIX qw( strftime );

use Data::Dumper qw( Dumper );
use Carp;

# file contains map_header and map_record
require './anfc_dwc.map.pl';


#------------------------------------------------------------------------------
main: {
#------------------------------------------------------------------------------

my $iArgCount = @ARGV;

my $fhIn;		# input file handle (or STDIN)
my $fhOut;	# output file handle (or STDOUT)
my $fhErr;	# error file handle (or STDERR)
my $fhLog;	# running log file handle

#$\ = "\n";

my $ocsvOut = Text::CSV->new({ 
   quote_char          => '"',
   escape_char         => '\\',
   sep_char            => ',',
   eol                 => "\n", #$\,
   always_quote        => 1,
   quote_space         => 1,
   quote_null          => 1,
   binary              => 1,
# unused at this stage:
#   keep_meta_info      => 0,
#   allow_loose_quotes  => 0,
#   allow_loose_escapes => 0,
#   allow_whitespace    => 0,
#   blank_is_undef      => 0,
#   empty_is_undef      => 0,
#   verbatim            => 0,
#   auto_diag           => 0,
});

# input file delimiter
my $reDelim = "[+][|]";

# input file row number
my $iRow = 0;

# number of valid records encountered (prior to a mapping attempt, after mapping)
my $iRecordCount = -1, $iMappedCount = -1;

# number of fields in the header row
# also controls the flow of the main 'while' loop:
#  * -1 val means no header with at least 1 field has been encountered yet
#  * -2 val means to abort the loop at the next pass
#  *  0 val would be an empty line encountered before a header has been mapped; will be reset to -1
#  * >0 val is the number of header fields mapped, but is also used to control a data row's call to split()
#
# let's say $iHeaderCount >0 and data row:	+|+|+|+|asd+|+|+|+|+|+|+|+|+|+|+|+|+|+|+|+|+|+|+|
# a call to split() without passing in the minimum expected # of elements will result in only a 5-element array returned
# this is undesirable behaviour because these trailing empty values may well be 'null'
# so for data rows, we use: split( /PATTERN/,EXPR,LIMIT ) to ensure we have empty values included
# - we also issue a warning incase the row is a dud record anyway
# see: http://perldoc.perl.org/functions/split.html
my $iHeaderCount = -1, $iLastHdrCnt = -1000;

# textual errors keyed by <row>:<line> ($iRow + ":" + __LINE__) or <row>:<line>:<string> ($iRow + ":" + __LINE__ + ":" + $your_string)
my %hErrors;

# the source data header (columns) and index
my @arrHeader;
my %hSrcHdrInd;

# the output data header and index
my @arrDwcHeader;
my %hDwcHdrInd;
my $bDwcHdrPrinted = 0;


# 1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  1

#------------------------------------------------------------------------------
# parse command line arguments
#	usage: anfc_dwc.mapper.pl <IN> <OUT> <ERROR> <LOG>
#	 - all 4 arguments:  input file (or 'STDIN'), output file (or 'STDOUT'), error file, log file
#	 - 3 arguments:      input file, output file, error file (run log to stdout)
#	 - 2 arguments:      input file, output file (errors stderr, run log to stdout)
#	 - 1 argument:       input file (output stdout, errors stderr, no run log)
#	 - no arguments:     (input stdin, output stdout, errors stderr, no run log)
{
#------------------------------------------------------------------------------
	# help message only
	if( @ARGV[0] =~ /--h/i ) {
		print
			  "--------------------------------------------------------------------------\n"
			. __FILE__ . strftime("#%F#%T#", localtime) . "\n"
	    . "--------------------------------------------------------------------------\n"
	    . "usage: anfc_dwc.mapper.pl <IN> <OUT> <ERROR> <LOG>\n"
			. "- all 4:   input file(or 'STDIN'), output file(or 'STDOUT'), error file, log file\n"
			. "- 3 args:  input file, output file, error file (run log to stdout)\n"
			. "- 2 args:  input file, output file (errors stderr, run log to stdout)\n"
			. "- 1 arg:   input file (output stdout, errors stderr, no run log)\n"
			. "- no args: (input stdin, output stdout, errors stderr, no run log)\n"
			. "--------------------------------------------------------------------------\n";

		exit;
	}

	# warning, continue as if ($iArgCount == 4)
	if( $iArgCount > 4 ) {
		$hErrors{("0:" . __LINE__)} = "WARNING: Arguments after <$ARGV[3]> (" . join(', ', @ARGV[4..$#ARGV]) . ") ignored.";
		$iArgCount = 4;
	}

	# (input from stdin, output to stdout, errors to stderr, no run logging)
	if( $iArgCount == 0 ) {
		$hErrors{("0:" . __LINE__)} = "WARNING: No run logging, errors to STDERR only (input from STDIN, output to STDOUT)";

		$fhIn = *STDIN;
		$fhOut = *STDOUT;
		$fhErr = *STDERR;
	}

	# input file (output to stdout, errors to stderr, no run logging)
	elsif( $iArgCount == 1 ) {
		$hErrors{("0:" . __LINE__)} = "WARNING: No run logging, errors to STDERR only (input from $ARGV[0], output to STDOUT)";

		open $fhIn, "<", $ARGV[0] or die $!;
		$fhOut = *STDOUT;
		$fhErr = *STDERR;
	}

	# input file, output file (errors to stderr, run logging to stdout)
	elsif( $iArgCount == 2 ) {
		print
	      "--------------------------------------------------------------------------\n"
			. "STARTED#" . __FILE__ . strftime("#%F#%T#", localtime) . ":\n"
	    . " - input file: $ARGV[0]\n"
			. " - output file: $ARGV[1]\n"
	 		. " - run logging to STDOUT, errors to STDERR\n"
	    . "--------------------------------------------------------------------------\n";

		open $fhIn, "<", $ARGV[0] or die $!;
		open $fhOut, ">", $ARGV[1] or die $!;
		$fhErr = *STDERR;
		$fhLog = *STDOUT;
	}

	# input file, output file, error file (run logging to stdout)
	elsif( $iArgCount == 3 ) {
		print
	      "--------------------------------------------------------------------------\n"
			. "STARTED#" . __FILE__ . strftime("#%F#%T#", localtime) . " started:\n"
	    . " - input file:  $ARGV[0]\n"
			. " - output file: $ARGV[1]\n"
			. " - error file:  $ARGV[2]\n"
	 		. " - run logging to STDOUT\n"
	    . "--------------------------------------------------------------------------\n";

		open $fhIn, "<", $ARGV[0] or die $!;
		open $fhOut, ">", $ARGV[1] or die $!;
		open $fhErr, ">", $ARGV[2] or die $!;
		$fhLog = *STDOUT;
	}

	# input file, output file, error file, log file
	elsif( $iArgCount == 4 ) {
		# check to see if the caller wants STDIN
		if( $ARGV[0] =~ m/STDIN/ ) {
			$fhIn = *STDIN;
		}
		else {
			open $fhIn, "<", $ARGV[0] or die $!;
		}

		# check to see if the caller wants STDOUT
		if( $ARGV[1] =~ m/STDOUT/ ) {
			$fhOut = *STDOUT;
		}
		else {
			open $fhOut, ">", $ARGV[1] or die $!;
		}

		open $fhErr, ">", $ARGV[2] or die $!;
		open $fhLog, ">", $ARGV[3] or die $!;

		print $fhLog
	      "--------------------------------------------------------------------------\n"
			. "STARTED#" . __FILE__ . strftime("#%F#%T#", localtime) . " started:\n"
	    . " - input file:  $ARGV[0]\n"
			. " - output file: $ARGV[1]\n"
			. " - error file:  $ARGV[2]\n"
	 		. " - log file:    $ARGV[3]\n"
	    . "--------------------------------------------------------------------------\n";
	}

	# an unexpected condition...
	else {
	print "HALTED#" . __FILE__ . strftime("#%F#%T#", localtime) . " Unexpected number of arguments at line " . __LINE__ . " - cannot continue.";
	exit;
	}

	# these next commands instruct the file handles not to buffer
	select( $fhLog );		$|++; # we want our logging stream to be up-to-date
	select( $fhErr );		$|++; # we want our error stream to be up-to-date
	# ... data output and input will still be bufferred

#------------------------------------------------------------------------------
}	# parsing arguments


#------------------------------------------------------------------------------
while( my $line = <$fhIn> ) {
#------------------------------------------------------------------------------

	chomp $line;

	$iRow++;

	$Data::Dumper::Terse = 1;        # don't output names where feasible
	$Data::Dumper::Indent = 0;       # turn off all pretty print


# 2  2  2  2  2  2  2  2  2  2  2  2  2  2  2  2  2  2  2  2  2  2  2  2  2  2

	#------------------------------------------------------------------------------
	# if we haven't established the header array & hash of indices ...
	if( $iHeaderCount == -1 ) {
	#------------------------------------------------------------------------------
		# store each column name in an array
		@arrHeader = split( $reDelim, $line );
		$iHeaderCount = scalar( @arrHeader );


# 3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3

		# store the index of each column against the column name in a hash
		# this allows us to reference a value by column name without knowing its index
		# eg. $arr_values[$hSrcHdrInd{'species'}]
		for( my $i = 0; $i < $iHeaderCount; $i++ ) {
			# there are multiple columns with the same name... (ambiguous case)
			if( exists($hSrcHdrInd{@arrHeader[$i]}) ) {
				# we still use the later column anyway, as this could have changed over time
				# by someone with constraints, eg. a limited technical ability or a cranky system
				$hSrcHdrInd{@arrHeader[$i]} = $i;
				$hErrors{($iRow . ":" . __LINE__ . ":" . $i)} = sprintf( "WARNING: Column '%s' at index [%d] already stored at [%d] (ie. same column names) - values from latter will be used.\n", @arrHeader[$i], $i, $hSrcHdrInd{@arrHeader[$i]} );
			}
			else {
				# key 'column name' = i_array_index
				$hSrcHdrInd{@arrHeader[$i]} = $i;
			}
		}


# 3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3

		# if we successfully parsed a header row...
		if( $iHeaderCount > 0 ) {
			my $serr;

			# we sub the building and indexing of the dwc header (for clarity)
			# test for failure (which will end the export)
			if( !map_dwc_header(\@arrDwcHeader, \%hDwcHdrInd, \$serr) ) {
				# this condition will end processing, because we have nothing to do
				$iHeaderCount = -2;
	#print "DWC Mapping error: $serr";

				# store more errors associated with the dwc header indices...
				if( defined($serr) ) {
					$hErrors{($iRow . ":" . __LINE__)} = $serr;
				}
			}
			# we were successful in building the dwc header
			else {
				# next pass, data rows
				$iRecordCount = 0;
				$iMappedCount = 0;

				print $fhLog 
							"SOURCE HEADER:\n"
						. join(',', keys(%hSrcHdrInd) )
						. "\n" . join(',', values(%hSrcHdrInd) )
					  . "\n--------------------------------------------------------------------------\n"
					  . "DwC TARGET HEADER:\n"
						. join(',', keys(%hDwcHdrInd) )
						. "\n" . join(',', values(%hDwcHdrInd) )
					  . "\n--------------------------------------------------------------------------\n"
						.	"Parsing data from row $iRow";

	#print "[" . $iHeaderCount . "] " . Dumper( \%hSrcHdrInd ) . "\n";
			}
		} # if( $iHeaderCount > -1 )


# 2  2  2  2  2  2  2  2  2  2  2  2  2  2  2  2  2  2  2  2  2  2  2  2  2  2

		# this may be an error condition, or we may have not yet encountered a valid header row (ie, something other than an empty string)
		else {
			# have another go at the next line
			$iHeaderCount = -1;
		}

	#------------------------------------------------------------------------------
	} #if( $iHeaderCount == -1 )

	#------------------------------------------------------------------------------
	# we're now in the data
	else {
	#------------------------------------------------------------------------------

		# (see comments on $iHeaderCount at top of file)
		# count the # of values using a limitless split
		my $icntvals = scalar( split($reDelim, $line) );

		# if this data row is in error by a larger number of fields
		if( $icntvals > $iHeaderCount ) {
			# store info on the error line
			$hErrors{($iRow . ":" . __LINE__)} = sprintf( "ERROR: %d fields expected, found %d: %.35s", $iHeaderCount, $icntvals, $line );
		}


# 4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4

		# <= expected number of fields ...
		elsif( ($icntvals > 0) || ($icntvals == $iHeaderCount) ) {
			# this is a valid data row - let's try to map it
			$iRecordCount++;

			# split again, including a limit to ensure trailing empty values are included
			# don't like split()ing twice, however, the code was expedient & it's only machine's work...
			# (does this even matter? ie. if there are trailing nulls and we still try to map
			#  those data won't be included... need to do some tests?)
			my @arr_values = split( $reDelim, $line, $iHeaderCount );

			# we counted the number of fields without the limit (trailing empties discarded)
			# if there's a discrepancy between that figure and the current count, log a warning
			if( $icntvals != scalar(@arr_values) ) {
########### is this even an error condition?? ###########
$hErrors{($iRow . ":" . __LINE__)} = sprintf( "WARNING: %d fields expected vs %d found - mapping still attempted", scalar(@arr_values), $icntvals );
########### for now (mar 2013) it is ###########
			}


# 5  5  5  5  5  5  5  5  5  5  5  5  5  5  5  5  5  5  5  5  5  5  5  5  5  5

			# an output array
			my @arr_output;
			# ... made as big as the header array
			$#arr_output = $#arrDwcHeader;
			# a string for the error (if any)
			my $serr;

			# attempt to map the record...
			my $imapresult = map_record( \@arr_values, \@arr_output, \%hSrcHdrInd, \%hDwcHdrInd, \$serr );

			# ...the mapping worked
			if( $imapresult ) {
				$iMappedCount++;

				# if we haven't already printed the header row...
				$ocsvOut->print($fhOut, \@arrDwcHeader)	if( !$bDwcHdrPrinted++ );
				# ... and print the data row as well
				$ocsvOut->print( $fhOut, \@arr_output );
				# older print tests;
#				print $fhOut Dumper( \@arr_values ) . "\n";
#				print $fhOut "\"" . join("\",\"", @arr_values) . "\"\n";

				# store warnings associated with the dwc record mapping
				# (map_record succeeded, but $serr is defined)
				if( defined($serr) ) {
					$hErrors{($iRow . ":" . __LINE__)} = $serr;
				}

				# produce some running output as feedback for the user
				print $fhLog "." 								if( $iRow % 333 == 0 );
				print $fhLog $iRow							if( $iRow % 5000 == 0 );
			}

			# ...something went wrong with the mapping
			else {
				# running output
				print $fhLog $iRow . "x";
				# store more errors associated with the dwc record mapping...
				if( defined($serr) ) {
					$hErrors{($iRow . ":" . __LINE__)} = $serr;
				}
			}

			undef $serr;
		} #elsif #fields in data row is <= expected number of fields (from header)

#print Dumper( join(";", @arr_values) ) . "\n";
	} #else data row

	# we've been instructed to stop processing the source-data file
	if( $iHeaderCount == -2 ) {
		# log some errors and stuff
		last; #while( my $line = <$io> )
	}

#	if( $iLastHdrCnt != $iHeaderCount ) {
#print "$iLastHdrCnt-$iHeaderCount,";
#		$iLastHdrCnt = $iHeaderCount;
#	}

#------------------------------------------------------------------------------
} #while each line

print $fhLog $iRow;


# 6  6  6  6  6  6  6  6  6  6  6  6  6  6  6  6  6  6  6  6  6  6  6  6  6  6

# print summary
print $fhLog sprintf( "\nCOMPLETE#%s\n - fields %d\n - records %d, mapped %d\n - errors %d\n", (__FILE__ . strftime("#%F#%T#", localtime)), $iHeaderCount, $iRecordCount, $iMappedCount, scalar(keys(%hErrors)) );

# print errors
if( scalar(keys(%hErrors)) > 0 ) {
	print $fhErr "ERRORS#" . __FILE__ . strftime("#%F#%T#", localtime);
	print $fhErr "<" . join('><', @ARGV[0..$#ARGV]) . ">" if( $iArgCount > 0 );
	print "\n";

	for $key ( sort {$a<=>$b} keys %hErrors ) {
		print $fhErr sprintf( "%s - %s\n", $key, $hErrors{$key} );
	}
}

#------------------------------------------------------------------------------
}
#:main
