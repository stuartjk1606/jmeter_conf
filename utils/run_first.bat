@echo off
setlocal
setlocal EnableDelayedExpansion
goto:main
:apach2_license
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

:get_log_time <logLevel> <logMessage>
    set logDateTime=%date:~6,4%/%date:~3,2%/%date:~0,2%-%time:~0,2%:%time:~3,2%:%time:~6,2%
    set logDateTime=%logDateTime: =0%
    set logLevel=%1
    echo %logDateTime% [%logLevel%] %~2
    
exit /b 
:check_java <jmeterHome> <jmeterConf>

    call:get_log_time INFO "Checking java version available against jmeter requirements"
	for /f "tokens=2 delims=." %%a in ('type %jmeterHome%\jmeter.bat ^| findstr /c:"set MINIMAL_VERSION"') do set minVersion=%%a
	pushd "c:\Program Files\java" 2> nul
	if %errorlevel% == 0 (
		for /f "tokens=*" %%a in ('dir java.exe /b /s') do (
			set javaExe=%%~sa
			set javaFound=1
			pushd !javaExe!\.. 2> nul
				set javaHome=!cd!\
			popd
		)

	) else (
		call:get_log_time WARN "No java instance found in C:\Program files\java. Please manually set javaHome in %jmeterConf%\custom_properties\dir_locals.config"
		echo javaHome=>> %jmeterConf%\custom_properties\dir_locals.config
		exit /b
	)
	for /f " tokens=4 delims=. " %%v in ('%javaExe% -version 2^>^&1 ^| findstr /i "version"') do set currVersion=%%v

	if %currVersion% lss %minVersion% (
		call:get_log_time ERR "Java version in %javaHome% is below minimum required for this version of JMeter. Either install a newer version of java or if already installed but not found, please manually set javaHome in %jmeterConf%\custom_properties\dir_locals.config"
		echo javaHome=>> %jmeterConf%\custom_properties\dir_locals.config
	) else (
		call:get_log_time INFO "Java version in %javaHome% is at a high enough version to support this JMeter"
		echo javaHome=%javaHome%>> %jmeterConf%\custom_properties\dir_locals.config
	)
	

exit /b
popd
:setup_directories <jmeterHome> <logsLocation> <dataLocation>
    for %%i in ("%jmeterConf%\instance_properties" "%jmeterConf%\instance_services") do (
        call:get_log_time INFO "Creating %%~i"
        mkdir %%i 2>nul
    )
    mkdir %jmeterHome%\keystores 2> nul
    
    dir %logsLocation% > nul 2>&1
    if "%errorlevel%" == "0" if not [%logsLocation%] == [] (
        goto:logsLocation
        exit /b
    )
    mkdir %jmeterConf%\..\logs 2> nul
    pushd %jmeterConf%\..\logs
        set logsLocation=!cd!
    popd
	mkdir %logsLocation%\jmeter_logs
    pushd %logsLocation%\jmeter_logs
	popd
    :logsLocation
	if "%errorlevel%" == "0" if not [%logsLocation%] == [] (
        echo logsLocation=!logsLocation!>>%jmeterConf%\custom_properties\dir_locals.config
        call:get_log_time INFO "All logs for JMeter will be stored in %logsLocation%. If you require this location to be different, edit the systemLog entry in %jmeterConf%\custom_properties\dir_locals.config"
    ) else (
	    call:get_log_time ERR "Unable to create and verify logging folder. Please ensure user has read write access to $logsLocation$ and sub directories.
		pause
		goto:early_exit
	)

    dir %dataLocation% > nul 2>&1
    if "%errorlevel%" == "0" if not [%dataLocation%] == [] (
        goto:dataLocation
        exit /b
    )
    mkdir %jmeterConf%\..\data 2> nul
    pushd %jmeterConf%\..\data
        set dataLocation=!cd!
    popd
    :dataLocation
	if "%errorlevel%" == "0" if not [%dataLocation%] == [] (
        echo dataLocation=!dataLocation!>>%jmeterConf%\custom_properties\dir_locals.config
        call:get_log_time INFO "All data for JMeter will be taken from %dataLocation%. If you require this location to be different, edit the dataLocation entry in %jmeterConf%\custom_properties\dir_locals.config"
    ) else (
	    call:get_log_time ERR "Unable to create and verify data folder. Please ensure user has read write access to $dataLocation$ and sub directories.
		pause
		goto:early_exit
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
		goto:early_exit
    )
        
exit /b
:main
    pushd %~dp0..
        set jmeterConf=%cd%
    popd
    for /f "tokens=*" %%p in ('type %jmeterConf%\custom_properties\dir_locals.config') do set %%p
    call:set_jmeterHome %jmeterConf%
	call:check_java %jmeterHome% %jmeterConf%
	
    call:setup_directories %jmeterHome% %logsLocation%
    pause
:early_exit
exit /b
