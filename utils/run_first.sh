#!/bin/bash

## Copyright 2017 Stuart Kenworthy
## Licensed under the Apache License, Version 2.0 (the "License");
## you may not use this file except in compliance with the License.
## You may obtain a copy of the License at
##     http://www.apache.org/licenses/LICENSE-2.0
## Unless required by applicable law or agreed to in writing, software
## distributed under the License is distributed on an "AS IS" BASIS,
## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions and
## limitations under the License.

get_log_time() {

    echo $(date $dateArgs"$dateString") | sed 's!"!!g'

}

setup_directories() {

## Makes sure that the keystore and log directories are available and builds desktop file.

    for instanceDir in $jmeterConf/instance_properties $jmeterConf/instance_services
    do
        if [[ "$(ls $instanceDir 2>&1)" == *"No such file or directory"* ]]
            then
            echo "$(get_log_time) [INFO] Creating $instanceDir"
            mkdir $instanceDir
        fi
    done

    cp $jmeterConf/service_templates/jmeter.desktop $jmeterConf/instance_services/jmeter$firstArg.desktop
    sed -i $sedInline 's!.*Exec=.*!Exec='$runJmeter!'' $jmeterConf/instance_services/jmeter$firstArg.desktop
    sed -i $sedInline 's!.*Name=.*!Name=JMeter '$firstArg'!g' $jmeterConf/instance_services/jmeter$firstArg.desktop
    sed -i $sedInline 's!.*Icon=.*!Icon='$jmeterConf'/service_templates/jmeter.png!g' $jmeterConf/instance_services/jmeter$firstArg.desktop
    if [[ $useSudo ]]
    then
        sudo cp $jmeterConf/instance_services/jmeter$firstArg.desktop /usr/share/applications/ 2> /dev/null
    fi

    cp $jmeterConf/instance_services/jmeter$firstArg.desktop /home/$userName/Desktop/ 2> /dev/null

    if [[ $(ls -ld $jmeterHome/keystores| grep keystores | awk '{print $1}') != drwxrwxrwx ]]
    then
        $useSudo mkdir $jmeterHome/keystores
        $useSudo chmod 777 $jmeterHome/keystores
    fi 2> /dev/null

    if [[ $(ls -ld $systemLogs| grep jmeter | awk '{print $1}') != drwxrwxrwx ]]
    then
        $useSudo mkdir -p $systemLogs
        $useSudo chmod 777 $systemLogs
    fi 2> /dev/null

}

set_jmeterHome() {

## sets jmeterHome in dir_locals.config by searching for instances available on the system or returns error if no instance found.

echo "$(get_log_time) [INFO] Looking for an instance of jmeter. If more than 1 version is present, the wrong one may be used. Please ensure on 1 is extracted on the system."

    jmeterJar=$(dirname $($useSudo find /$searchHome -iname ApacheJmeter.jar 2> /dev/null | grep bin | $useHome ) 2> /dev/null)
    jmeterShell=$(dirname $($useSudo find /$searchHome -iname jmeter 2> /dev/null | grep -v /usr/bin | grep bin ) 2> /dev/null)

    jmeterFound=( $jmeterJar )
    jmeterFound=${jmeterFound[0]}


    if [[ $jmeterFound && $jmeterShell && ( $jmeterShell == *"$jmeterFound"* ) ]]
    then
        echo "$(get_log_time) [INFO] Jmeter located in $jmeterFound will be used. If this is wrong, please remove this version and run this script again."
        echo jmeterHome=$jmeterFound>> $jmeterConf/custom_properties/dir_locals.config
        $useSudo ln -sf $jmeterConf/start_jmeter.sh $runJmeter 2> /dev/null
    else
        echo "$(get_log_time) [ERR] Unable to determine location of a JMeter installation. Please check JMeter is available on this sytem."
        echo jmeterHome=>> $jmeterConf/custom_properties/dir_locals.config
        $useSudo rm $runJmeter /home/$userName/jmeter 2> /dev/null
        exit
    fi

}

## Sets global variables or variables that do not normally need to be changed.

jmeterConf=$(dirname $(realpath $(dirname $0)))
userName=$(whoami)
useHome="grep -v /home/"
useSudo=sudo
checkUser=0
runJmeter=/usr/bin/jmeter
firstArg=$(if [[ "home" == $1 ]] ;then echo "home"; fi)

## Checks combination of user, sudo access and whether home is set. if sudo needs to be used but not script not run as sudo, it checks if the user has sudo access first and uses it for all subsequent connands and stops if not. 
## log location config is checked as for home settings, no need to run root, but for system wide settings, 1 user doesn't want all the logs.

if [[ $(uname) != Linux ]]
then
    sedInline=bak
    dateArgs="+"
    dateString="\"%d/%m/%Y %H:%M:%S\"" 2> /dev/null
    logDateString='+%Y%m%d%H%M%S'
else
    dateArgs="-d now +"
    dateString="\"%d/%m/%Y %T.%3N %Z\"" 2> /dev/null
    logDateString='-d now +%Y%m%d%H%M%S'
fi

if [[ "home" == "$firstArg" && $userName != "root"  ]]
then
    systemLogs=/home/$userName/logs/jmeter
    echo "$(get_log_time) [WARN] Only jmeter versions in /home/$userName will be searched."
    useHome="grep /home/$userName"
    searchHome="home/$userName"
    if [[ $(grep systemLogs $jmeterConf/custom_properties/dir_locals.config) != systemLogs=/home/$userName/logs/jmeter ]]
    then
        echo "$(get_log_time) [WARN] systemLogs was not set to user home in dir_locals.config. Setting has been changed so to log to /home/$userName/logs/jmeter"
    fi
    useSudo=
    runJmeter=/home/$userName/jmeter
elif [[ "home" != "$firstArg" && $userName != "root"  ]]
then
    systemLogs=/var/log/jmeter
    if [[ $(grep systemLogs $jmeterConf/custom_properties/dir_locals.config) == "systemLogs=/home/"* ]]
    then
       echo "$(get_log_time) [WARN] systemLogs was set to a user home directory in dir_locals.config. Setting has been changed so to log to /var/log/jmeter"
    fi
    echo "$(get_log_time) [WARN] User must be root or have sudo access to run this script, please provide your password for sudo. All versions under /home/ will be ignored."
    checkUser=$(sudo whoami 1> /dev/null && echo $?)
elif [[ "home" == "$firstArg" && $userName == "root"  ]]
then
    systemLogs=/var/log/jmeter
    echo "$(get_log_time) [WARN] Running this script as sudo or root will ignore \"home\"."
fi

echo systemLogs=$systemLogs> $jmeterConf/custom_properties/dir_locals.config

## In the event of not home and not using sudo or root, the availability of sudo is checked. If it fails the script fails and returns an ERR.
## If successful, or sudo is not as part of the script, log directories, resource location config and shortcuts are created.
## Need to add in a OS Menu shortcut.

if [[ $checkUser != 0 ]]
then
    echo "$(get_log_time) [ERR] You do not appear have sudo access and not running as root. You must have sudo access to run this script."
    sed -i $sedInline 's!jmeterHome=.*!jmeterHome='$jmeterFound'!' $jmeterConf/custom_properties/dir_locals.config
else
    set_jmeterHome $jmeterConf $useHome
    source $jmeterConf/custom_properties/dir_locals.config
    setup_directories $systemLogs $jmeterHome $useSudo
fi
