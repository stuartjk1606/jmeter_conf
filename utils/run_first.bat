@echo off
setlocal
setlocal EnableDelayedExpansion
goto:main
:apach2_license
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
:setup_directories <jmeterHome> <systemLogs>
    for %%i in ("%jmeterConf%\instance_properties" "%jmeterConf%\instance_services") do (
        call:get_log_time INFO "Creating %%~i"
        mkdir %%i 2>nul
    )
    mkdir %jmeterHome%\keystores 2> nul
    
    dir %systemLogs% > nul 2>&1
    if "%errorlevel%" == "0" if not [%systemLogs%] == [] (
        goto:systemLogs
        exit /b
    )
    mkdir %jmeterConf%\..\logs 2> nul
    pushd %jmeterConf%\..\logs
        set systemLogs=!cd!
    popd
    if "%errorlevel%" == "0" if not [%systemLogs%] == [] (
        :systemLogs
        echo systemLogs=!systemLogs!>>%jmeterConf%\custom_properties\dir_locals.config
        call:get_log_time INFO "All logs for JMeter will be stored in %systemLogs%. If you require this location to be different, edit the systemLog entry in %jmeterConf%\custom_properties\dir_locals.config"
        exit /b
    )
exit /b
:set_jmeterHome <jmeterConf>
    call:get_log_time INFO "Looking for an instance of jmeter. If more than 1 version is present, the wrong one may be used. Please ensure only 1 is extracted on the system."
    pushd c:\
        for /f "tokens=*" %%a in ('dir ApacheJMeter.jar /b /s') do (
            set jmeterJar=%%a
            set jmeterFound=1
            pushd !jmeterJar!\.. 2> nul
                set jmeterHome=!cd!
            popd
        )
    popd
    if "%jmeterFound%" == "1" (
        call:get_log_time INFO "Jmeter located in %jmeterHome% will be used. If this is wrong, please remove this version and run this script again."
        echo jmeterHome=%jmeterHome%>%jmeterConf%\custom_properties\dir_locals.config
    )
    if not "%jmeterFound%" == "1" (
        call:get_log_time ERROR "Unable to determine location of a Jmeter installation. Please check JMeter is available on this system."
        echo jmeterHome=nul>%jmeterConf%\custom_properties\dir_locals.config
    )
        
exit /b
:main
    pushd %~dp0..
        set jmeterConf=%cd%
    popd
    for /f "tokens=*" %%p in ('type %jmeterConf%\custom_properties\dir_locals.config') do set %%p
    call:set_jmeterHome %jmeterConf%
    call:setup_directories %jmeterHome% %systemLogs%
    pause
exit /b
