@echo off

setlocal
setlocal EnableDelayedExpansion

set thisScript=%0

goto:main

:apache2_license

echo view source code for license

rem Copyright 2017 Stuart Kenworthy
rem Licensed under the Apache License, Version 2.0 (the "License");
rem you may not use this file except in compliance with the License.
rem You may obtain a copy of the License at
rem     http://www.apache.org/licenses/LICENSE-2.0
rem Unless required by applicable law or agreed to in writing, software
rem distributed under the License is distributed on an "AS IS" BASIS,
rem WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
rem See the License for the specific language governing permissions and
rem limitations under the License.

exit /b

rem is_it_a_property, find_replace and get_mod_dates are specific to windows shell version and handle the way for loops are dealt with. 

:is_it_a_property

rem <newString> <oldString> <outputString>

rem ignores values that are commented out or begins with a space or tab

    set outputString=%3
    if not "%outputString:~1,1%" == "#" if not "%outputString:~1,1%" == " " if not "%outputString:~1,1%" == "	" (
		call:find_replace %1 %2 %outputString%
	)

exit /b

:find_replace

rem <newString> <oldString> <outputString> 

rem replaces strings in the parameters and outputs the result. A bit iffy but works for printing out the parameters to custom files.

	setlocal
    set newString=%~1
    set oldString=%2
    set outputString=%3
    set "outputString=!outputString:%oldString%=%newString%!"
    echo %outputString:~1,-1%
    
exit /b

:get_mod_dates

rem <file> <variableName> <searchString>

rem returns the modified date of a file. search string is a required argument to ensure the correct line out of dir is used

    set fileModDate=0
    for /F "tokens=1,2,*" %%i in ('DIR /T:W %1 ^| findstr "\.%3"') do set fileModDate=%%i %%j
    set fileModDate=!fileModDate: =!
    set fileModDate=!fileModDate:/=!
    set fileModDate=!fileModDate::=!
    set fileModDate=!fileModDate:~6,2!!fileModDate:~2,2!!fileModDate:~0,2!!fileModDate:~8!
    set %2=%fileModDate%

exit /b

:get_log_time

rem <logLevel> <logMessage>

rem a simple logger function that outputs logDateTime logLevel logMessage

    set logDateTime=%date:~6,4%/%date:~3,2%/%date:~0,2%-%time:~0,2%:%time:~3,2%:%time:~6,2%
    set logDateTime=%logDateTime: =0%
    set logLevel=%1
    echo %logDateTime% [%logLevel%] %~2
    
exit /b 

:check_instance <instance>

rem checks if value in instance field is a numerical value between 0 and 9.

    set isNumber=1
    for /f "delims=0123456789" %%i in ("%1") do set /a isNumber=%isNumber%-1
    
exit /b

:check_directories

rem <logsLocation> <jmeterHome>

rem checks if the required log, data and keystore files are present.

rem todo Additional checks need to be added at some point to ensure read/write access available to user but not easy in Windows

    if [%logsLocation%] == [] set dirChecks=1
    dir %logsLocation% > nul 2>&1
    set dirChecks=%dirChecks%%errorlevel%
    dir %jmeterHome%\keystores > nul 2>&1
    set dirChecks=%dirChecks%%errorlevel%
    
exit /b

:check_java

rem <jmeterHome> <javaHome>

rem retrieves the minimal version of java required by jmeter then checks against the version of java configured in dir_locals.config

	set minVersion=0
	set currVersion=0
	for /f "tokens=2 delims=." %%a in ('type %jmeterHome%\jmeter.bat ^| findstr /c:"set MINIMAL_VERSION"') do set minVersion=%%a
	for /f "tokens=4 delims=. " %%v in ('%javaHome%java -version 2^>^&1 ^| findstr /i "version"') do set currVersion=%%v
	if %currVersion% lss %minVersion% (
		call:get_log_time ERR "Java version in %javaHome% (%currVersion%) is below minimum required for this version of JMeter (%minVersion%). Either install a newer version of java or if already installed but not found, please manually set javaHome in %dirLocalsFile%"
		set javaOk=0
		pause
	) else (
		call:get_log_time INFO "Java version in %javaHome% (%currVersion%) is at a high enough version to support this JMeter"
		set javaOk=1
	)

exit /b

:check_prop_files

rem <jmeterConf> <jmeterHome> <thisScript>

rem checks the custom properties files against all source files

	rem files that would affect what is written to the instance properties files.

    set jmeterHostsFile=%jmeterConf%\custom_properties\jmeter_hosts.dat
    
	rem default jmeter source properties files

    set jmeterSourceProps=%jmeterHome%\jmeter.properties
    set systemSourceProps=%jmeterHome%\system.properties
    set userSourceProps=%jmeterHome%\user.properties

	rem your custom source properties files to be writted to all instances
	
    set jmeterCustomProps=%jmeterConf%\custom_properties\custom_jmeter.properties
    set systemCustomProps=%jmeterConf%\custom_properties\custom_system.properties
    set userCustomProps=%jmeterConf%\custom_properties\custom_user.properties

	rem the instance properties files to be compared and then overwritten if out of date
	
    set jmeterPropertiesFile=%jmeterConf%\instance_properties\jmeter%instance%.properties
    set systemPropertiesFile=%jmeterConf%\instance_properties\system%instance%.properties
    set userPropertiesFile=%jmeterConf%\instance_properties\user%instance%.properties

	rem grab all the modified dates for the files identified above.
	
    call:get_mod_dates %jmeterPropertiesFile% jmeterPropertiesFileDate properties 2> nul
    call:get_mod_dates %jmeterSourceProps% jmeterSourcePropsDate properties 2> nul
    call:get_mod_dates %jmeterCustomProps% jmeterCustomPropsDate properties 2> nul
    call:get_mod_dates %thisScript% thisScriptDate bat 2> nul
    call:get_mod_dates %systemPropertiesFile% systemPropertiesFileDate properties 2> nul
    call:get_mod_dates %systemSourceProps% systemSourcePropsDate properties 2> nul
    call:get_mod_dates %systemCustomProps% systemCustomPropsDate properties 2> nul
    call:get_mod_dates %userPropertiesFile% userPropertiesFileDate properties 2> nul
    call:get_mod_dates %userSourceProps% userSourcePropsDate properties 2> nul
    call:get_mod_dates %userCustomProps% userCustomPropsDate properties 2> nul
    call:get_mod_dates %jmeterHostsFile% jmeterHostsFileDate dat 2> nul
    call:get_mod_dates %dirLocalsFile% dirLocalsFileDate config 2> nul
    set needsRebuild=0
    
	rem compare the instance files with any source files and mark as needing rebuild.
	
    for %%d in (%jmeterSourcePropsDate% %jmeterCustomPropsDate% %thisScriptDate% %jmeterHostsFileDate% %dirLocalsFileDate%) do (
        if %jmeterPropertiesFileDate% lss %%d (
            set /a needsRebuild=1
            call:get_log_time WARN "A source file has been updated since jmeter%instance%.properties was created. Custom properties files will be rebuilt."
			exit /b
        )
    )
    for %%d in (%systemSourcePropsDate% %systemCustomPropsDate% %thisScriptDate%) do (
        if %systemPropertiesFileDate% lss %%d (
            set /a needsRebuild=1
            call:get_log_time WARN "A source file has been updated since system%instance%.properties was created. Custom properties files will be rebuilt."
			exit /b
        )
    )
    for %%d in (%userSourcePropsDate% %userCustomPropsDate% %thisScriptDate%) do (
        if %userPropertiesFileDate% lss %%d (
            set /a needsRebuild=1
            call:get_log_time WARN "A source file has been updated since user%instance%.properties was created. Custom properties files will be rebuilt."
			exit /b
        )
    )
    
exit /b

:import_prop_files

rem <jmeterConf> <jmeterHome> <instance>

rem imports the default jmeter source properties files into the instance files. only writes valid none commented properties identified using is_it_a_property

	set dataLocation=/%dataLocation:\=/%/
    set jmeterConfVar=/%jmeterConf:\=/%/
    call:get_log_time DEBUG "Importing default properties files from %jmeterHome%."
    echo # A custom JMeter properties file created by %thisScript% > %jmeterPropertiesFile%
    for /f "delims=|" %%p in ( 'type %jmeterSourceProps%' ) do (
        if not ["%%p"] == [""] (
            call:is_it_a_property "%jmeterConfVar%" {jmeterConfVar} "%%p"  >> %jmeterPropertiesFile%
        )
    )
    echo # A custom JMeter properties file created by %thisScript% > %systemPropertiesFile%
    for /f "delims=|" %%p in ( 'type %systemSourceProps%' ) do (
        if not ["%%p"] == [""] (
            call:is_it_a_property "%jmeterConfVar%" {jmeterConfVar} "%%p"  >> %systemPropertiesFile%
        )
    )
    
    echo # A custom JMeter properties file created by %thisScript% > %userPropertiesFile%
    for /f "delims=|" %%p in ( 'type %userSourceProps%' ) do (
        if not ["%%p"] == [""] (
            call:is_it_a_property "%jmeterConfVar%" {jmeterConfVar} "%%p"  >> %userPropertiesFile%
        )
    )
    call:get_log_time DEBUG "Default properties files imported"
    
exit /b

:update_prop_files

rem <jmeterConf> <instance>

rem imports any custom properties files found in jmeter_conf/custom/properties into instance properties.
rem Originally replaced placeholders for variables similar to this label in the bash script but easier to include variable definitions in the custom properties files.

    set jmeterConfVar=/%jmeterConf:\=/%/
    set jmeterHomeVar=/%jmeterHome:\=/%/
    call:get_log_time DEBUG "merging custom properties with default jmeter.properties. custom properties take priority if there is a confict."
    for /f "delims=|" %%p in ( 'type %jmeterCustomProps%' ) do (
        if not ["%%p"] == [""] (
            call:is_it_a_property "%jmeterConfVar%" {jmeterConfVar} "%%p"  >> %jmeterPropertiesFile%
        )
    )
	
    call:get_log_time DEBUG "merging custom properties with default jmeter.properties complete."

    call:get_log_time DEBUG "merging custom properties with default system.properties. custom properties take priority if there is a confict."
    for /f "delims=|" %%p in ( 'type %systemCustomProps%' ) do (
        if not ["%%p"] == [""] (
            call:is_it_a_property "%jmeterConfVar%" {jmeterConfVar} "%%p"  >> %systemPropertiesFile%
        )
    )
	
    call:get_log_time DEBUG "merging custom properties with default system.properties complete."

    call:get_log_time DEBUG "merging custom properties with default user.properties. custom properties take priority if there is a confict."

    for /f "delims=|" %%p in ( 'type %userCustomProps%' ) do (
        if not ["%%p"] == [""] (
		
            call:is_it_a_property "%jmeterConfVar%" {jmeterConfVar} "%%p"  >> %userPropertiesFile%
        
		)
	)
	
    call:get_log_time DEBUG "merging custom properties with default user.properties complete."

exit /b

:set_rmi

rem <jmeterConf> <rmiport> <instance>

rem calculates the RMI and beanshell server ports relevant for this instance and adds them to instance properties file.

    call:get_log_time DEBUG "Building list of RMI hosts from jmeter_hosts.dat with port number %rmiPort%"
    set rmiHosts=
    for /f %%h in ( 'type %jmeterHostsFile%' ) do (
        echo %%h | findstr [:] > nul 2>&1
        if !errorlevel! == 0 (
			set rmiHosts=!rmiHosts!%%h,
		) else (
			set rmiHosts=!rmiHosts!%%h:%rmiPort%,
		)
    )
    set rmiHosts=%rmiHosts:~0,-1%
    call:get_log_time DEBUG "Adding list of RMI hosts to jmeter%instance%.properties file."
    echo remote_hosts=%rmiHosts% >> %jmeterConf%/instance_properties/jmeter%instance%.properties
    echo server.rmi.port=%rmiPort% >> %jmeterConf%/instance_properties/jmeter%instance%.properties
    set /a bsPort=%baseBsPort%+(0%instance%*10)
    call:get_log_time DEBUG "Adding beanshell server port %bsPort% to jmeter%instance%.properties file."
    echo beanshell.server.port=%bsPort% >> %jmeterConf%/instance_properties/jmeter%instance%.properties

exit /b

:start_jmeter

rem calculates relevant memory and options based on parameters passed to it then starts jmeter.

    if ["%isServer%"] == ["server"] (
        set instanceType=server
        for /f "tokens=1,2,3,4,5,* delims= " %%a in ("%*") do set jmeterArgs=%%f
        set jmeterProps=-Dserver_port=%rmiPort% -s
		if ["%HEAP%"] == [""] (
			set HEAP=%serverHeap%
		)
    ) else (
        set instanceType=client
        for /f "tokens=1,2,3,4,* delims= " %%a in ("%*") do set jmeterArgs=%%e
        set jmeterProps=-Jproxy.cert.file=keystores/%USERNAME%.jmeter.keystore
		if ["%HEAP%"] == [""] (
			set HEAP=%clientHEAP%
		)
	)
    set logDateString=%date:~6,4%%date:~3,2%%date:~0,2%%time:~0,2%%time:~3,2%%time:~6,2%
    set logDateString=%logDateString: =0%
    set java_opts=-Xms%HEAP% -Xmx%HEAP% -XX:NewSize=128m -XX:MaxNewSize=128m
    call:get_log_time INFO "Starting jmeter %instance% as %instanceType%."
    %javaHome%java %java_opts% -XX:+HeapDumpOnOutOfMemoryError -XX:SurvivorRatio=8 -XX:TargetSurvivorRatio=50 -XX:MaxTenuringThreshold=2  -XX:+CMSClassUnloadingEnabled -jar %jmeterHome%/ApacheJMeter.jar %jmeterProps% -j %logsLocation%\jmeter_logs\jmeter%instance%-%USERNAME%-%logDateString%-%instanceType%.log -JlogsLocation=%logsLocation% -p %jmeterPropertiesFile% %jmeterArgs%

exit /b

:main

rem Lets make sure the arguments passed are going to start a valid instance

if "%1" == "server" (
    set isServer=%1
    set instance=%2
) else (
    set instance=%1
)
call:check_instance %instance%
if %isNumber% == 0 (

    call:get_log_time ERR "Variables are set without an instance number. Please set using %thisScript% {instance} or %thisScript% server {instance}. Please note, server cannot be run without and instance and instance must be 1 or greater."

    exit /b
)
if a%isServer% == aserver (
    if a%instance% == a0 (

		call:get_log_time ERR "Server instance 0 is invalid. Please set using %thisScript% {instance} or %thisScript% server {instance}. Please note, server cannot be run without and instance and instance must be 1 or greater."
        
		exit /b
    )
    if a%instance% == a (
        
		call:get_log_time ERR "No server instance provided. Please set using %thisScript% {instance} or %thisScript% server {instance}. Please note, server cannot be run without and instance and instance must be 1 or greater."
        
		exit /b
    )
)   
pushd %~dp0
    set jmeterConf=%cd%
popd
set dirLocalsFile=%jmeterConf%\custom_properties\dir_locals.config
for /f "tokens=*" %%p in ('type %dirLocalsFile%') do set %%p
for /f "tokens=*" %%p in ('type %jmeterConf%\custom_properties\jmeter_general.config') do set %%p
call:check_directories %logsLocation% %jmeterHome% %thisScript%
call:check_java %jmeterHome% %javaHome%
if "%javaOk%" == "0" (
	exit /b
)

if "%dirChecks%" == "00" (
    call:get_log_time INFO "All jmeter logs will be written to %logsLocation% and proxy keystores will be written to %jmeterHome%\keystores."
) else (
    call:get_log_time ERR "Jmeter is not set up correctly to use this script. Please run "utils\run_first.sh" before running this script."
	pause
    exit /b
)
set /a rmiPort=%baseRmiPort%+0%instance%

call:get_log_time INFO "Checking existing custom files to ensure they are up to date."

call:check_prop_files %jmeterConf% %jmeterHome% %instance%

if not "%needsRebuild%" == "0" (
    call:get_log_time WARN "Rebuilding all properties and services files. If customisations have been made to these files since this instance was last run, please fix after starting this instance."
    call:import_prop_files "%jmeterConf%" "%jmeterHome%" %instance%
	
    call:update_prop_files "%jmeterConf%" %instance%
    
	call:set_rmi "%jmeterConf%" "%rmiport%" "%instance%"
    
	call:get_log_time INFO "All custom files have now been rebuilt."

) else (
    call:get_log_time INFO "All custom files are up to date."
)
call:start_jmeter %logsLocation% %jmeterConf% %jmeterHome% %*

:earlyExit

exit /b