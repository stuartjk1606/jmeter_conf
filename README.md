# jmeter_conf
Shell scripts for both windows and linux allowing custom configuration of jmeter instances, be it many instances or a on locked down machine. Should work on Unix too with the right packages.

utils/run_first - goes off and finds your installations of jmeter. Linux uses the first one it finds, windows uses the last one it finds. Best to only have 1 installed at a time.
               - On linux you can use the home argument to only look in your home directory for jmeter, in case you do not have access to root. Ommiting "home" will not look in /home/* and requires root access.

start_jmeter - checks whether run_first has been executed by ensuring the required directories are available, any problems found and it will not run.
             - checks to ensure the source configuration files and itself have not changed since the instance properties files were created and rebuilds them if there is any change.
             - starts jmeter. To run as client either just run or add an instance number as arg1. To run as server, arg1 must say server and arg2 an instance number 1 or higher.

start_jmeter.bat currently has the path for Java defined whereas start_jmeter.sh uses the system level instance of Java. Feel feee to change this, I just have not had need to.

custom*.properties files are added last so anything already defined in the default jmeter files will be overwritten with the custom versions.

jmeter_hosts.dat - contains a list of addresses used for RMI. These can be defined as address:portor address where address can be hostname or IP, I suggest IP. If port is omitted, the default instance RMI port (instance number + baseRmiPort) is appended to it automatically.

You can run as many different jmeter instances on your box as your kit will allow and have them all talk to eachother via RMI.

Apart from "server" and the instance number, all arguments passed to start_jmeter get passed onto the JVM. However at least an instance number must be provided if other arguments are being sent.

These scripts require no bespoke packages, although realpath is not always present on Linux boxes and is required.

Packages that are called from within bash scripts, most if not all should be already on your system:
    - bash
    - date
    - grep
    - awk
    - ls
    - echo
    - sed
    - wc
    - gsub
    - dirname
    - realpath
    - mkdir
    - chmod
