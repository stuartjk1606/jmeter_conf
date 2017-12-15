#!/bin/bash

wget $(curl http://jmeter.apache.org/download_jmeter.cgi | grep tgz | grep binaries | grep -v 'md5\|sha\|asc' | tr '"' ' ' | awk '{print $3}')
