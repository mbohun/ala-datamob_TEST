#!/usr/bin/env python

"""
Thu May  1 11:33:51 EST 2014

on stdin get date/time data extracted from "irn" file formatted like this:

30/07/2006,16:02

Convert to list of datetime objects and print most recent formatted like this:

2006/07/30 16:02

"""

import sys
from datetime import datetime

datetimes = []

for line in sys.stdin:
	try:
		date,time = line.split(',')
		date,month,year = date.split('/')
		year = int(year)
		month = int(month)
		date = int(date)
		hour,minute = time.split(':')
		hour = int(hour)
		minute = int(minute)
		if year <= datetime.now().year : # filter out wrong dates like 2987. Dont expect this script to still be in use in 2030
			datetimes.append(datetime(year,month,date,hour,minute))
	except:
		print >> sys.stderr, 'ignoring incorrectly formatted date:', line,
	

print max(datetimes).strftime("%Y/%m/%d %H:%M")
