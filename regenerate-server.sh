#!/bin/sh
# Regenerate server cert for Guacamole GW
# Copyright 2018 S. Olivas <kg7qin@arrl.net>
#
# Revision history:
# v0.01 - 11/7/2018 - S. Olivas
#       * Initial script
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

EASYRSACMD="/opt/guacamole-docker-compose/easyrsa3/easyrsa"
DOCKERCOMPOSE="/usr/bin/docker-compose"
BASEPATH="/opt/guacamole-docker-compose"
CA_PATH="/opt/guacamole-docker-compose/easyrsa3"

#Needs to be FQDN or IP address of server
SERVER_CERT="192.168.0.1"

#SAN is required for cert to work without errors.  It needs to have IP:<address> and/or DNS:<fqdn? of server(s).
#If multiple entries, separate with comma.  Remove comma if only a single entry.  MUST BE AT LEAST ONE ENTRY!!!
SERVER_SAN="IP:192.168.0.1"

cd $BASEPATH

# Wrapper around printf - clobber print since it's not POSIX anyway
# shellcheck disable=SC1117
print() { printf "%s\n" "$*"; }

#confirmation routine
confirm() {
	# call with a prompt string or use a default
    	read -r -p "${1:-Are you sure? [y/N]} " response
    	case "$response" in
        	[yY][eE][sS]|[yY]) 
            		true
        	    	;;
        	*)
           		 false
            		;;
    esac
}

print "
- - - - - - - - - - - - - - - - - - - - - - - - - - -
-         Regenerate server certificate             -
- - - - - - - - - - - - - - - - - - - - - - - - - - -
"

print " >> CURRENT SERVER CERTIFICATE <<

"
cd $CA_PATH
$EASYRSACMD --batch show-cert $SERVER_CERT

print " ><><><><><><><><><><><><><><><><><><><><><><><><><><><> 
"

print "** WARNING:  This script will:
1. Stop the Guacamole GW server processes
2. Revoke the current server certificate
3. Generate a new server certificate
4. Start the Guacamole GW server processes

The revocation process will only affect the server.  It also canno tbe undone.
"

if confirm "Do you want to proceed [y/N]?"; then
	echo >&2 " "
	echo >&2 "* You have passed the point of no return -- reissuring server cert and restarting processess"
else
	echo >&2 " "
	echo >&2 "Exiting..."
	exit 1
fi

cd $BASEPATH

print "
 * Stopping Guacamole GW processes...
 "
$DOCKERCOMPOSE stop

req="$SERVER_CERT.req"
crt="$SERVER_CERT.crt"
key="$SERVER_CERT.key"
	
print " * Revoking cert for $SERVER_CERT...
"

cd $CA_PATH
$EASYRSACMD --batch revoke $SERVER_CERT

print "
 * Updating CRL...
 "
$EASYRSACMD --batch gen-crl
	
print "
 * Renaming $req to $req.old..."
cd ./pki/reqs
mv $req $req.old
	
print " * Renaming $key to $key.old..."
cd ../private
mv $key $key.old
	
print " * Renaming $crt to $crt.old..."
cd ../issued
mv $crt $crt.old

print "
 * Generating new server certificate for $SERVER_CERT...
 "

cd $CA_PATH

$EASYRSACMD --batch --subject-alt-name="$SERVER_SAN" build-server-full $SERVER_CERT nopass
$EASYRSACMD --batch gen-crl

cd ./pki/private
print " 
* Creating symlink of generated $SERVER_CERT.key and $SERVER_CERT.crt to server.key and server.crt...
"
#now create a symlink of the server key and cert called server.key and server.crt
/bin/rm server.key
/bin/ln -s ./$SERVER_CERT.key server.key
cd ../issued
/bin/rm server.crt
/bin/ln -s ./$SERVER_CERT.crt server.crt

print "
 * Restarting Guacamole GW services...
 "
 
cd $BASEPATH

$DOCKERCOMPOSE start 
 
print "
>>> FINISHED <<<
"


