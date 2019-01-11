#!/bin/sh
#
# Generate client self-siged certs and prepare in .p12 format for import
# into Windows
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

#set -x

EASYRSACMD="/opt/guacamole-docker-compose/easyrsa3/easyrsa"
CA_PATH="/opt/guacamole-docker-compose/easyrsa3"
BASEPATH="/opt/guacamole-docker-compose"

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

#build user cert
build_cert() {
	#pull filename base (username@domain)
	[ -n "$1" ] || die "\
Error: didn't find <username@domain> as the first argument."

	#pull email address
	[ -n "$2" ] || die "\
Error: didn't find user email address as second argument"

	filename="$1"
	email="$2"

	print " 
	
	* Generating client certificate...
	
	"
	
	cd $CA_PATH
	$EASYRSACMD --batch --req-email="$email" build-client-full $filename nopass
	print " 
	
	* Updating CRL...
	
	"
	$EASYRSACMD --batch gen-crl
	
	print "
	
	* Exporting to .p12 format.  When prompted, enter an export password...
	
	"
	$EASYRSACMD --batch export-p12 $filename

	print "
	
	* Certificate will be in $CA_PATH/pki/private/$filename.p12
	  
	  NOTE: All client certificates are good for 3 years from issue (generation) date.
	  
	  "
	cd $BASEPATH
	
} # => build-cert()

#revoke user cert
revoke_cert() {
	#pull filename base (username@domain)
	[ -n "$1" ] || die "\
Error: didn't find <username@domain> as the first argument."
	
	filename="$1"
	
	print "
	
	* Revoke client certificate 
	
	"
	
	echo "** WARNING:  Revoking a user certificate cannot be undone.  You will need to reissue a new cert to the user."
	echo " "

	if confirm "Do you want to proceed [y/N]?"; then
		echo >&2 " "
		echo >&2 "* You have passed the point of no return -- user certificate is being revoked..."
	else
		echo >&2 " "
		echo >&2 "Exiting..."
		exit 1
	fi

	req="$filename.req"
	crt="$filename.crt"
	key="$filename.key"
	
	print " * Revoking cert for $filename
	
	"

	cd $CA_PATH
	$EASYRSACMD --batch revoke $filename
	
	print " * Renaming $req to $req.old..."
	cd ./pki/reqs
	mv $req $req.old
	
	print " * Renaming $key to $key.old..."
	cd ../private
	mv $key $key.old
	print " * Renaming $filename.p12 to $filename.p12.old..."
	mv $filename.p12 $filename.p12.old
	
	print " * Renaming $crt to $crt.old..."
	cd ../issued
	mv $crt $crt.old

	cd $BASEPATH
	
	
} # => reokve-cert()

#show user cert
show_cert() {
	#pull filename base (username@domain)
	[ -n "$1" ] || die "\
Error: didn't find <username@domain> as the first argument."

	filename="$1"

	cd $CA_PATH
	$EASYRSACMD --batch show-cert $filename
	

} # => show-cert()

# Wrapper around printf - clobber print since it's not POSIX anyway
# shellcheck disable=SC1117
print() { printf "%s\n" "$*"; }

# Exit fatally with a message to stderr
# present even with EASYRSA_BATCH as these are fatal problems
die() {
	print "
Easy-RSA error:

$1" 1>&2
	prog_exit "${2:-1}"
} # => die()

prog_exit() {
	ESTAT=0
	[ ! -z "$1" ] && ESTAT=$1
	(set -o echo 2>/dev/null) || stty echo
	echo "" # just to get a clean line
	exit $ESTAT
} # => prog_exit()

# Register prog_exit on SIGHUP, SIGINT, SIGQUIT, and SIGABRT
trap "prog_exit" 0 1 2 3 6

#main routine
cmd="$1"
[ -n "$1" ] && shift # scrape off command
case "$cmd" in
	build)
		build_cert "$@"
		;;
	revoke)
		revoke_cert "$@"
		;;	
	show)
		show_cert "$@"
		;;
	*)
                print "

You must specify a command and argument:

build <user@domain> <email> - Generate client certificate and .p12 file for export
revoke <user@domain>  - Revoke client certificate
show <user@domain>    - Show client certificate

                "

		;;
esac

