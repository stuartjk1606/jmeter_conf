@echo off
cd %~dp0
set summaryFile=%1%
set logDateTime=%date:~6,4%%date:~3,2%%date:~0,2%%time:~0,2%%time:~3,2%%time:~6,2%
set logDateTime=%logDateTime: =0%
pushd %summaryFile%\..\dashboards
    set dashboardDir=%cd%\%logDateTime%
    mkdir %dashboardDir%
popd
call jmeter.bat -g "%summaryFile%" -o "%dashboardDir%"
start "" %dashboardDir%\index.html
