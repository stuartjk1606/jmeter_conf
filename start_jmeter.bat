@echo off
goto:main
:apache2_license
Copyright 2017 Stuart Kenworthy
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at
    http://www.apache.org/licenses/LICENSE-2.0
Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
exit /b
:get_log_time <logLevel> <logMessage>
    set logDateTime=%date:~6,4%/%date:~3,2%/%date:~0,2%-%time:~0,2%:%time:~3,2%:%time:~6,2%
    set logDateTime=%logDateTime: =0%
    set logLevel=%1
    echo %logDateTime% [%logLevel%] %~2
    
exit /b 
:check_instance <instance>
    set isNumber=1
    for /f "delims=0123456789" %%i in ("%1") do set /a isNumber=%isNumber%-1
    
exit /b
:check_directories <systemLogs> <jmeterHome>
    if [%systemLogs%] == [] set dirChecks=1
    dir %systemLogs% > nul 2>&1
    set dirChecks=%errorlevel%
    dir %jmeterHome%\keystores > nul 2>&1
    set dirChecks=%dirChecks%%errorlevel%
    
exit /b
:check_prop_files <jmeterConf> <jmeterHome> <thisScript>
    SET jmeterConf=C:\Users\44036736\fdTransformation\fd-group-sapi-testing\jmeter_conf
    SET jmeterHome=C:\SWDTOOLS\APACHE-JMETER-3.0\bin
    set jmeterConfScript=%thisScript%
    set jmeterPropertiesFile=%jmeterConf%\instance_properties\jmeter%instance%.properties
    set jmeterSourceProps=%jmeterHome%\jmeter.properties
    set jmeterCustomProps=%jmeterConf%\custom_properties\custom_jmeter.properties
    set systemPropertiesFile=%jmeterConf%\instance_properties\system%instance%.properties
    set systemSourceProps=%jmeterHome%\system.properties
    set systemCustomProps=%jmeterConf%\custom_properties\custom_system.properties
    set userPropertiesFile=%jmeterConf%\instance_properties\user%instance%.properties
    set userSourceProps=%jmeterHome%\user.properties
    set userCustomProps=%jmeterConf%\custom_properties\custom_user.properties
    call:get_mod_dates %jmeterPropertiesFile% jmeterPropertiesFileDate properties 2> nul
    call:get_mod_dates %jmeterSourceProps% jmeterSourcePropsDate properties 2> nul
    call:get_mod_dates %jmeterCustomProps% jmeterCustomPropsDate properties 2> nul
    call:get_mod_dates %jmeterConfScript% jmeterConfScriptDate bat 2> nul
    call:get_mod_dates %systemPropertiesFile% systemPropertiesFileDate properties 2> nul
    call:get_mod_dates %systemSourceProps% systemSourcePropsDate properties 2> nul
    call:get_mod_dates %systemCustomProps% systemCustomPropsDate properties 2> nul
    call:get_mod_dates %userPropertiesFile% userPropertiesFileDate properties 2> nul
    call:get_mod_dates %userSourceProps% userSourcePropsDate properties 2> nul
    call:get_mod_dates %userCustomProps% userCustomPropsDate properties 2> nul
    set needsRebuild=0
    
    for %%d in (%jmeterSourcePropsDate% %jmeterCustomPropsDate% %jmeterConfScriptDate%) do (
        if %jmeterPropertiesFileDate% lss %%d (
            set /a needsRebuild=1
            call:get_log_time WARN "A source file has been updated since jmeter%instance%.properties was created. Custom properties files will be rebuilt."
        )
    )
    for %%d in (%systemSourcePropsDate% %systemCustomPropsDate% %jmeterConfScriptDate%) do (
        if %systemPropertiesFileDate% lss %%d (
            set /a needsRebuild=1
            call:get_log_time WARN "A source file has been updated since system%instance%.properties was created. Custom properties files will be rebuilt."
        )
    )
    for %%d in (%userSourcePropsDate% %userCustomPropsDate% %jmeterConfScriptDate%) do (
        if %userPropertiesFileDate% lss %%d (
            set /a needsRebuild=1
            call:get_log_time WARN "A source file has been updated since user%instance%.properties was created. Custom properties files will be rebuilt."
        )
    )
    
exit /b
:import_prop_files <jmeterConf> <jmeterHome> <instance>
    set jmeterConfVar=/%jmeterConf:\=/%/
    call:get_log_time DEBUG "Importing default properties files from %jmeterHome%."
    set jmeterPropertiesFile=%jmeterConf%\instance_properties\jmeter%instance%.properties
    set systemPropertiesFile=%jmeterConf%\instance_properties\system%instance%.properties
    set userPropertiesFile=%jmeterConf%\instance_properties\user%instance%.properties
    echo # A custom JMeter properties file created by %0> %jmeterPropertiesFile%
    for /f "delims=|" %%p in ( 'type %jmeterHome%\jmeter.properties' ) do (
        if not ["%%p"] == [""] (
            call:is_it_a_property "%jmeterConfVar%" {jmeterConfVar} "%%p"  >> %jmeterPropertiesFile%
        )
    )
    echo # A custom JMeter properties file created by %0> %systemPropertiesFile%
    for /f "delims=|" %%p in ( 'type %jmeterHome%\system.properties' ) do (
        if not ["%%p"] == [""] (
            call:is_it_a_property "%jmeterConfVar%" {jmeterConfVar} "%%p"  >> %systemPropertiesFile%
        )
    )
    
    echo # A custom JMeter properties file created by %0> %userPropertiesFile%
    for /f "delims=|" %%p in ( 'type %jmeterHome%\user.properties' ) do (
        if not ["%%p"] == [""] (
            call:is_it_a_property "%jmeterConfVar%" {jmeterConfVar} "%%p"  >> %userPropertiesFile%
        )
    )
    call:get_log_time DEBUG "Default properties files imported"
    
exit /b
:update_prop_files <jmeterConf> <instance>
    set jmeterConfVar=/%jmeterConf:\=/%/
    set jmeterPropertiesFile=%jmeterConf%\instance_properties\jmeter%instance%.properties
    set jmeterCustomProps=%jmeterConf%\custom_properties\custom_jmeter.properties
    call:get_log_time DEBUG "merging custom properties with default jmeter.properties. custom properties take priority if there is a confict."
    for /f "delims=|" %%p in ( 'type %jmeterCustomProps%' ) do (
        if not ["%%p"] == [""] (
            call:is_it_a_property "%jmeterConfVar%" {jmeterConfVar} "%%p"  >> %jmeterPropertiesFile%
        )
    )
    
    set systemPropertiesFile=%jmeterConf%\instance_properties\system%instance%.properties
    set systemCustomProps=%jmeterConf%\custom_properties\custom_system.properties
    call:get_log_time DEBUG "merging custom properties with default system.properties. custom properties take priority if there is a confict."
    for /f "delims=|" %%p in ( 'type %systemCustomProps%' ) do (
        if not ["%%p"] == [""] (
            call:is_it_a_property "%jmeterConfVar%" {jmeterConfVar} "%%p"  >> %systemPropertiesFile%
        )
    )
    set userPropertiesFile=%jmeterConf%\instance_properties\user%instance%.properties
    set userCustomProps=%jmeterConf%\custom_properties\custom_user.properties
    call:get_log_time DEBUG "merging custom properties with default user.properties. custom properties take priority if there is a confict."
    for /f "delims=|" %%p in ( 'type %userCustomProps%' ) do (
        if not ["%%p"] == [""] (
            call:is_it_a_property "%jmeterConfVar%" {jmeterConfVar} "%%p"  >> %userPropertiesFile%
        )
    )
    
exit /b
:set_rmi <jmeterConf> <rmiport> <instance>
    call:get_log_time DEBUG "Building list of RMI hosts from jmeter_hosts.dat with port number %rmiPort%"
    set rmiHosts=
    for /f %%h in ( 'type %jmeterConf%\custom_properties\jmeter_hosts.dat' ) do (
        echo %%h | findstr [:] > nul 2>&1
        if !errorlevel! == 0 set rmiHosts=!rmiHosts!%%h,
        if not !errorlevel! == 0 set rmiHosts=!rmiHosts!%%h:%rmiPort%,
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
    if ["%isServer%"] == ["server"] (
        set instanceType=server
        for /f "tokens=1,2,3,4,5,* delims= " %%a in ("%*") do set jmeterArgs=%%f
        set jmeterProps=-Dserver_port=%rmiPort% -s
        set HEAP=%serverHeap%
    )
    if not ["%isServer%"] == ["server"] (
        set instanceType=client
        for /f "tokens=1,2,3,4,* delims= " %%a in ("%*") do set jmeterArgs=%%e
        set jmeterProps=-Jproxy.cert.file=keystores/%USERNAME%.jmeter.keystore
        set HEAP=%clientHEAP%
    )
    set logDateString=%date:~6,4%%date:~3,2%%date:~0,2%%time:~0,2%%time:~3,2%%time:~6,2%
    set logDateString=%logDateString: =0%
    set java_opts=-Xms%HEAP% -Xmx%HEAP% -XX:NewSize=128m -XX:MaxNewSize=128m
    call:get_log_time INFO "Starting jmeter %instance% as %instanceType%."
    echo %javaHome% %java_opts% -XX:+HeapDumpOnOutOfMemoryError -XX:SurvivorRatio=8 -XX:TargetSurvivorRatio=50 -XX:MaxTenuringThreshold=2  -XX:+CMSClassUnloadingEnabled -jar %jmeterHome%/ApacheJMeter.jar %jmeterProps% -j %systemLogs%\jmeter_logs\jmeter%instance%-%USERNAME%-%logDateString%-%instanceType%.log -Jlogs_location=%systemLogs% -p %jmeterConf%\instance_properties\jmeter%instance%.properties %jmeterArgs% >> C:\SWDTOOLS\APACHE-JMETER-3.0\bin\jmeter_bat.log
    %javaHome% %java_opts% -XX:+HeapDumpOnOutOfMemoryError -XX:SurvivorRatio=8 -XX:TargetSurvivorRatio=50 -XX:MaxTenuringThreshold=2  -XX:+CMSClassUnloadingEnabled -jar %jmeterHome%/ApacheJMeter.jar %jmeterProps% -j %systemLogs%\jmeter_logs\jmeter%instance%-%USERNAME%-%logDateString%-%instanceType%.log -Jlogs_location=%systemLogs% -p %jmeterConf%\instance_properties\jmeter%instance%.properties %jmeterArgs%
exit /b
rem is_it_a_property, find_replace and get_mod_dates are specific to windows shell version and handle the way for loops are dealt with. 
:is_it_a_property <newString> <oldString> <outputString>
    set outputString=%3
    if not "%outputString:~1,1%" == "#" if not "%outputString:~1,1%" == " " if not "%outputString:~1,1%" == "    " (
            call:find_replace %1 %2 %outputString%
        )
    )
exit /b
:find_replace <newString> <oldString> <outputString> 
setlocal
    set newString=%~1
    set oldString=%2
    set outputString=%3
    setlocal enabledelayedexpansion
    set "outputString=!outputString:%oldString%=%newString%!"
    echo %outputString:~1,-1%
    
exit /b
:get_mod_dates <file> <variableName> <searchString>
    set fileModDate=0
    for /F "tokens=1,2,*" %%i in ('DIR /T:W %1 ^| findstr "\.%3"') do set fileModDate=%%i %%j
    set fileModDate=!fileModDate: =!
    set fileModDate=!fileModDate:/=!
    set fileModDate=!fileModDate::=!
    set fileModDate=!fileModDate:~6,2!!fileModDate:~2,2!!fileModDate:~0,2!!fileModDate:~8!
    set %2=%fileModDate%
exit /b
:main
setlocal
setlocal EnableDelayedExpansion
rem Lets make sure the arguments passed are going to start a valid instance
if "%1" == "server" (
    set isServer=%1
    set instance=%2
)
if not "%1" == "server" (
    set instance=%1
)
call:check_instance %instance%
if %isNumber% == 0 (
    call:get_log_time ERR "Variables are set without an instance number. Please set using %0 {instance} or %0 server {instance}. Please note, server cannot be run without and instance and instance must be 1 or greater.
    goto:earlyExit
)
if a%isServer% == aserver (
    if a%instance% == a0 (
        call:get_log_time ERR "Server instance 0 is invalid. Please set using %0 {instance} or %0 server {instance}. Please note, server cannot be run without and instance and instance must be 1 or greater.
        goto:earlyExit
    )
    if a%instance% == a (
        call:get_log_time ERR "No server instance provided. Please set using %0 {instance} or %0 server {instance}. Please note, server cannot be run without and instance and instance must be 1 or greater.
        goto:earlyExit
    )
)   
set javaHome=C:\SWDTOOLS\JDK1.8.0_66\bin\java
set thisScript=%0
pushd %~dp0
    set jmeterConf=%cd%
popd
for /f "tokens=*" %%p in ('type %jmeterConf%\custom_properties\dir_locals.config') do set %%p
for /f "tokens=*" %%p in ('type %jmeterConf%\custom_properties\jmeter_general.config') do set %%p
call:check_directories %systemLogs% %jmeterHome% %thisScript%
if %dirChecks% == 00 (
    call:get_log_time INFO "All jmeter logs will be written to %systemLogs% and proxy keystores will be written to %jmeterHome%\keystores."
)
if not %dirChecks% == 00 (
    call:get_log_time ERR "Jmeter is not set up correctly to use this script. Please run "utils\run_first.sh" before running this script."
    goto:earlyExit
)
set /a rmiPort=%baseRmiPort%+0%instance%
call:get_log_time INFO "Checking existing custom files to ensure they are up to date."
call:check_prop_files %jmeterConf% %jmeterHome% %instance%
if not %needsRebuild% == 0 (
    call:get_log_time WARN "Rebuilding all properties and services files. If customisations have been made to these files since this instance was last run, please fix after starting this instance."
    call:import_prop_files %jmeterConf% %jmeterHome% %instance%
    call:update_prop_files %jmeterConf% %instance%
    call:set_rmi %jmeterConf% %rmiport% %instance%
    call:get_log_time INFO "All custom files have now been rebuilt."
)
if %needsRebuild% == 0 (
    call:get_log_time INFO "All custom files are up to date."
)
call:start_jmeter %systemLogs% %jmeterConf% %jmeterHome% %*
:earlyExit
exit /b
