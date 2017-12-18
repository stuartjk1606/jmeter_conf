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
:check_java <jmeterHome> <jmeterConf>

    call:get_log_time INFO "Checking java version available against jmeter requirements"
	for /f "tokens=2 delims=." %%a in ('type %jmeterHome%\jmeter.bat ^| findstr /c:"set MINIMAL_VERSION"') do set minVersion=%%a
	pushd "c:\Program Files\java" 2> nul
	if errorlevel == 0 (
		for /f "tokens=*" %%a in ('dir java.exe /b /s') do (
			set javaExe=%%~sa
			set javaFound=1
			pushd !javaExe!\.. 2> nul
				set javaHome=!cd!\
			popd
		)

	) else (
		call:get_log_time WARN "No java instance found in C:\Program files\java. Please manually set javaHome in %jmeterConf%\custom_properties\dir_locals.config"
		echo javaHome=> %jmeterConf%\custom_properties\dir_locals.config
		exit /b
	)
	for /f " tokens=4 delims=. " %%v in ('%javaExe% -version 2^>^&1 ^| findstr /i "version"') do (
		set currVersion=%%v
	)
	if %currVersion% lss %minVersion% (
		call:get_log_time ERR "Java version in %javaHome% is below minimum required for this version of JMeter. Either install a newer version of java or if already installed but not found, please manually set javaHome in %jmeterConf%\custom_properties\dir_locals.config"
		echo javaHome=> %jmeterConf%\custom_properties\dir_locals.config
	) else (
		call:get_log_time INFO "Java version in %javaHome% is at a high enough version to support this JMeter"
		echo javaHome=%javaHome%> %jmeterConf%\custom_properties\dir_locals.config
	)
	

exit /b
popd
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
	call:check_java %jmeterHome% %jmeterConf%
	
    call:setup_directories %jmeterHome% %systemLogs%
    pause
exit /b
