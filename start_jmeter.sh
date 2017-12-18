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

check_instance() {

## Makes sure if variables 1 or 2 are populated, 1 is the instance ID or 1 is server and 2 is instance ID.

    isNumber='^[1-9]+$'
    if [[ $1 =~ $isNumber ]]
    then
        isNumber1=1
    elif [[ $2 =~ $isNumber ]]
    then
        isNumber2=1
    fi
    if [[ ($isNumber1 && $1) || ("$1" == "server" && $isNumber2 && $2) || ! $1 ]]
    then
        echo 0
    else
        echo 1
    fi

}

check_directories() {

## Makes sure that the keystore and log directories are available.

    if [[ $jmeterHome == "/home/"* ]]
    then
        runJmeter=/home/$(whoami)/jmeter
    else
        runJmeter=/usr/bin/jmeter
    fi

    if [[ ($(ls -ld $jmeterHome/keystores| grep keystores | awk '{print $1}') == drwxrwxrwx) && ($(ls -ld $systemLogs| grep jmeter | awk '{print $1}') == drwxrwxrwx) && $(ls -l $runJmeter | grep start_jmeter) ]]
    then
        echo "$(get_log_time) [INFO] All jmeter logs will be written to $systemLogs and proxy keystores will be written to $jmeterHome/keystores."
    else
        echo "$(get_log_time) [ERR] Jmeter is not set up correctly to use this script. Please run "utils/run_first_as_root.sh" as sudo or root before running this script."
        exit
    fi 2> /dev/null

}

check_prop_files(){

## Checks that the custom and system level properties files and host list are not newer than the instance version.

needsRebuild=0

# Checks if source files for jmeter.properties have changed since build, including this file

    for propsFile in $jmeterHome/jmeter.properties $jmeterConf/custom_properties/custom_jmeter.properties $jmeterConf/custom_properties/jmeter_hosts.dat $jmeterConf/custom_properties/dir_locals.config $jmeterConf/custom_properties/jmeter_general.config $jmeterConf/start_jmeter.sh
    do
        if [[ $propsFile -nt $jmeterConf/instance_properties/jmeter$instance.properties ]]
        then
            let needsRebuild=$needsRebuld+1
            echo "$(get_log_time) [WARN] $propsFile has been updated since jmeter$instance.properties was created. All instance files will be rebuilt."
        fi
    done

# Checks if source files for system.properties have changed since last build

    for propsFile in $jmeterHome/system.properties $jmeterConf/custom_properties/custom_system.properties $jmeterConf/start_jmeter.sh
    do
        if [[ $propsFile -nt $jmeterConf/instance_properties/system.properties ]]
        then
            let needsRebuild=$needsRebuld+1
            echo "$(get_log_time) [WARN] $propsFile has been updated since system.properties was created. Custom system.properties file will be rebuilt."
        fi
    done

    if [[ $needsRebuild == 0 ]]
    then
        echo 0
    fi

}

import_prop_files() {

## Imports the system level properties files.

    echo "$(get_log_time) [DEBUG] Importing default properties files from $jmeterHome"

    cat $jmeterHome/jmeter.properties | grep -v "#" | grep "=" > $jmeterConf/instance_properties/jmeter$instance.properties
    cat $jmeterHome/system.properties | grep -v "#" | grep "=" > $jmeterConf/instance_properties/system.properties

    echo "$(get_log_time) [DEBUG] Default properties files imported"

}

update_prop_files(){

## Merges custom properties with the copies of the system level files created.

    echo "$(get_log_time) [DEBUG] merging custom properties with default jmeter.properties. custom properties take priority if there is a confict."

    jmeterPropFileLineCount=$(wc -l $jmeterConf/custom_properties/custom_jmeter.properties | awk '{print $1}')
    jmeterCustomProps=$(for ((i=1 ; i<="$jmeterPropFileLineCount";i++)) ; do sed "${i}q;d" $jmeterConf/custom_properties/custom_jmeter.properties | grep "=" | tr '=' ' ' | awk '{print $1}'  ; done)
    for prop in $jmeterCustomProps
    do
        if [[ $(grep $prop $jmeterConf/instance_properties/jmeter$2.properties) ]]
        then
            newProp=$(grep $prop $jmeterConf/custom_properties/custom_jmeter.properties)
            sed -i $sedInline 's!'.*$prop'=.*!'"$newProp"'!' $jmeterConf/instance_properties/jmeter$instance.properties
        else
            grep $prop $jmeterConf/custom_properties/custom_jmeter.properties >> $jmeterConf/instance_properties/jmeter$instance.properties
        fi
    done

    echo "$(get_log_time) [DEBUG] merging custom properties with default system.properties. custom properties take priority if there is a confict."

    systemPropFileLineCount=$(wc -l $jmeterConf/custom_properties/custom_system.properties | awk '{print $1}')
    systemCustomProps=$(for ((i=1 ; i<="$systemPropFileLineCount";i++)) ; do sed "${i}q;d" $jmeterConf/custom_properties/custom_system.properties | grep "=" | tr '=' ' ' | awk '{print $1}'  ; done)
    for prop in $systemCustomProps
    do
        if [[ $(grep $prop $jmeterConf/instance_properties/system.properties) ]]
        then
            newProp=$(grep $prop $jmeterConf/custom_properties/custom_system.properties)
            sed -i $sedInline 's!'.*$prop'=.*!'"$newProp"'!' $jmeterConf/instance_properties/system.properties
        else
            grep $prop $jmeterConf/custom_properties/custom_system.properties >> $jmeterConf/instance_properties/system.properties
        fi
    done

}

set_rmi() {

## Sets RMI hosts and ports in instance properties for distributed load.

    echo "$(get_log_time) [DEBUG] Building list of RMI hosts from jmeter_hosts.dat with port number $rmiPort"

    rmiHosts=
    for i in $(cat $jmeterConf/custom_properties/jmeter_hosts.dat)
    do
        if [[ $(echo $i | grep ":") ]]
        then
            rmiHosts=$rmiHosts$i,
        else
            rmiHosts=$rmiHosts$i:$rmiPort,
        fi
    done
    rmiHosts=${rmiHosts%?}

    echo "$(get_log_time) [DEBUG] Adding list of RMI hosts to jmeter$instance.properties file."

    sed -i $sedInline 's!.*remote_hosts=.*!remote_hosts='$rmiHosts'!' $jmeterConf/instance_properties/jmeter$instance.properties
    sed -i $sedInline 's!.*server.rmi.port=.*!server.rmi.port='$rmiPort'!' $jmeterConf/instance_properties/jmeter$instance.properties

    echo "$(get_log_time) [DEBUG] Adding beanshell server port 90"$instance"0 to jmeter$instance.properties file."

    bsPort="90"$instance"0"
    sed -i $sedInline 's!.*beanshell.server.port=.*!beanshell.server.port='$bsPort'!' $jmeterConf/instance_properties/jmeter$instance.properties
}

fix_file_paths() {

## If custom properties files contain file paths of configured variables is %jmeter_conf%, this sets then as physical path. replicate for any other custom file paths created.

    echo "$(get_log_time) [DEBUG] Updating file paths in jmeter$instance.properties."

    filePathVars=(jmeterConfVar jmeterHomeVar)
    filePathValues=($jmeterConf $jmeterHome)

    for ((count=0 ; count<="${#filePathVars[@]}-1";count++))
    do
        filePathVar=${filePathVars[$count]}
        filePathValue=${filePathValues[$count]}
        propFile=$(awk '{ gsub ("%'$filePathVar'%","'$filePathValue'" );print}' $jmeterConf/instance_properties/jmeter$instance.properties)
        echo "$propFile" > $jmeterConf/instance_properties/jmeter$instance.properties
    done
}

create_service() {

## Creates the service files for systemd and upstart.

    echo "$(get_log_time) [DEBUG] Creating systemd and upstart service scripts."

    for i in conf service ; do sed 's/{instance}/'$instance'/g' $jmeterConf/service_templates/jmeter-server.$i > $jmeterConf/instance_services/jmeter-server$instance.$i ; done
    jmeterExec=$(whereis jmeter | awk '{print $2}')
    jmeterService=$(awk '{ gsub ("{jmeter}","'$jmeterExec'" );print}' $jmeterConf/instance_services/jmeter-server$instance.service)
    echo "$jmeterService" > $jmeterConf/instance_services/jmeter-server$instance.service

}

start_jmeter() {

## Does the doing. Uses different memory profiles whether server or and adds proxy keystore if not.

    if [[ "$4" == "server" ]]
    then
        instance=$5
        instanceType=server
        jmeterArgs=${@:6}
        jmeterProps="-Dserver_port=$rmiPort -s"
        HEAP="$serverHEAP"
    else
        instance=$4
        instanceType=client
        jmeterArgs=${@:5}
        jmeterProps="-Jproxy.cert.file=keystores/$(whoami).jmeter.keystore "
        HEAP="$clientHEAP"
    fi

    java_opts="-Xms$HEAP -Xmx$HEAP -XX:PermSize=128m -XX:MaxPermSize=256m"

    echo "$(get_log_time) [INFO] Starting jmeter $instance as $instanceType."

    java -server $java_opts -XX:MaxTenuringThreshold=2 -XX:+CMSClassUnloadingEnabled -jar $jmeterHome/ApacheJMeter.jar $jmeterProps -j $systemLogs/jmeter$instance-$(whoami)-$(date $logDateString)-$instanceType.log -Jlogs_location=$systemLogs -p $jmeterConf/instance_properties/jmeter$instance.properties "$jmeterArgs"

}

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


## Lets make sure the args passed are going to start a valid instance.

validInstance=$(check_instance $1 $2)

if [[ "$validInstance" != "0" ]]
then
    echo "$(get_log_time) [ERR] Variables are set without an instance number. Please set using \"$0 <instance>\" or \"$0 server <instance>\". Please note, server cannot be run without an instance and instance must be 1 or greater."
    exit
fi

## Get and check directories used by JMeter. Need sudo/root for this bit.

jmeterConf=$(dirname $(realpath $0))

source $jmeterConf/custom_properties/dir_locals.config
source $jmeterConf/custom_properties/jmeter_general.config
check_directories $systemLogs $jmeterHome
#check_directories $systemLogs $jmeterHome $1

## Sets instance number and type

if [[ $1 == server ]]
then
    isServer=$1
    instance=$2
else
    instance=$1
fi

let rmiPort=$baseRmiPort+0$instance

## Check the properties files and create again if necessary

echo "$(get_log_time) [INFO] Checking existing custom files to ensure they are up to date."

updatePropFile=$(check_prop_files $jmeterConf $jmeterHome $instance)
if [[ "$updatePropFile" != "0" ]]
then
    echo "$updatePropFile"
    echo "$(get_log_time) [WARN] Rebuilding all properties and services files. If customisations have been made to these files since this instance was last run, please fix after starting this instance."
    import_prop_files $jmeterConf $jmeterHome $instance
    update_prop_files $jmeterConf $instance
    set_rmi $jmeterConf $instance
    fix_file_paths $jmeterConf $instance
    create_service $jmeterConf $instance
    echo "$(get_log_time) [INFO] All custom files have now been rebuilt."
else
    echo "$(get_log_time) [INFO] All custom files are up to date."
fi

## Ready

start_jmeter $systemLogs $jmeterConf $jmeterHome $@

