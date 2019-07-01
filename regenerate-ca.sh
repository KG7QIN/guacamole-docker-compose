#!/bin/sh
# Generate/regenerate self-signed CA for Guacamole GW
# Copyright 2018 S. Olivas <kg7qin@arrl.net>
#
# Revision history:
# v0.01 - 11/7/2018 - S. Olivas
#       * Initial script
#
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
BASEPATH="/opt/guacamole-docker-compose"
CA_PATH="/opt/guacamole-docker-compose/easyrsa3"
# Change this to the server's primary IP address
SERVER_CERT="192.168.0.1"
#Change this to the server's primary IP address as well
SERVER_SAN="IP:192.168.0.1"

cd $BASEPATH

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

echo " "
echo "- - - - - - - - - - - - - - - - - - - - - - - - - - -"
echo "Generating/regenerating CA.  If prompted, answer yes"
echo "- - - - - - - - - - - - - - - - - - - - - - - - - - -"
echo " "

echo "** WARNING:  All user keys will need to be regenerated and reinstalled by users for use!!"
echo " "

if confirm "Do you want to proceed [y/N]?"; then
	echo >&2 " "
	echo >&2 "* You have passed the point of no return -- all user certs will need to be regenerated and reissued...."
else
	echo >&2 " "
	echo >&2 "Exiting..."
	exit 1
fi

echo "* Deleting exisitng CA certificates..."

/bin/rm -rf ./easyrsa3/pki

echo " "
echo "* Initializing CA and generating server cert..."
echo " "

cd ./easyrsa3
$EASYRSACMD --batch init-pki
$EASYRSACMD --batch build-ca nopass
$EASYRSACMD --batch --subject-alt-name="$SERVER_SAN" build-server-full $SERVER_CERT nopass
$EASYRSACMD --batch gen-crl

cd ..
echo " "
echo "Creating symlink of generated server key and cert to server.key and server.crt..."
echo " "
#now create a symlink of the server key and cert called server.key and server.crt
cd ./easyrsa3/pki/private
/bin/ln -s ./$SERVER_CERT.key server.key
cd ../issued
/bin/ln -s ./$SERVER_CERT.crt server.crt

echo " "
echo "Done"

