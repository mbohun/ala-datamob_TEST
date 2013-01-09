@echo off

REM #/**************************************************************************
REM # *  Copyright (C) 2011 Atlas of Living Australia
REM # *  All Rights Reserved.
REM # *
REM # *  The contents of this file are subject to the Mozilla Public
REM # *  License Version 1.1 (the "License"); you may not use this file
REM # *  except in compliance with the License. You may obtain a copy of
REM # *  the License at http://www.mozilla.org/MPL/
REM # *
REM # *  Software distributed under the License is distributed on an "AS
REM # *  IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
REM # *  implied. See the License for the specific language governing
REM # *  rights and limitations under the License.
REM # ***************************************************************************/
REM #
REM #/*
REM # DwC data export query
REM #
REM # this file executes the anwc_dwc.sql query, and exports any resultant data as a csv
REM #
REM # v2: 20121025: bk - file naming conventions for ingest
REM # v1: 20120604: bk - first iteration for initial anwc testing
REM #
REM # todo:
REM #
REM # dependencies:
REM #  * sql server 2008 powershell - sqlps.exe - 
REM #    http://jasonq.com/index.php/2012/03/3-things-to-do-if-invoke-sqlcmd-is-not-recognized-in-windows-powershell/
REM #  * 7zip command line - 7z.exe - 
REM #    http://sourceforge.net/projects/sevenzip/files/7-Zip/9.22/7z922.exe/download
REM #
REM #*/

REM the date and time elements in a locale-safe manner (vs %DATE:~10,4%%DATE:~7,2%%DATE:~4,2%.%TIME:~0,2%%TIME:~3,2%)
REM more details: http://www.winnetmag.com/windowsscripting/article/articleid/9177/windowsscripting_9177.html
for /f "tokens=1-7 delims=:/-, " %%i in ('echo exit^|cmd /q /k"prompt $d $t"') do (
   for /f "tokens=2-4 delims=/-,() skip=1" %%a in ('echo.^|date') do (
      set dow=%%i
      set %%a=%%j
      set %%b=%%k
      set %%c=%%l
      set hh=%%m
      set min=%%n
      set ss=%%o
   )
)

rem echo %dow% %yy%-%mm%-%dd% @ %hh%:%min%:%ss%
rem pause

if "%1"=="" (
sqlps -nologo -noprofile -command "invoke-sqlcmd -inputfile .\anwc_dwc.sql -database mssql_database_name -serverinstance mssql_server | Export-CSV -notype ([Environment]::CurrentDirectory + '\anwc-dwcdata.csv')"
) else (
sqlps -nologo -noprofile -command "invoke-sqlcmd -inputfile %1 -database mssql_database_name -serverinstance mssql_server | Export-CSV -notype ([Environment]::CurrentDirectory + '\anwc-dwcdata.csv')"
)

7z a -y -bd -tzip anwc-dwc.%yy%%mm%%dd%-%hh%%min%.zip anwc-dwcdata.csv anwc_dwc.sql anwc_dwc.bat

echo put anwc-dwc.%yy%%mm%%dd%-%hh%%min%.zip | psftp -4 -pw password user@upload.ala.org.au

pause
