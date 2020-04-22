#!/bin/bash


# Fast way for adding lots of users to an openvpn-install setup
# See the main openvpn-install project here: https://github.com/Nyr/openvpn-install
# openvpn-useradd-bulk is NOT supported or maintained and could become obsolete or broken in the future
# Created to satisfy the requirements here: https://github.com/Nyr/openvpn-install/issues/435

if readlink /proc/$$/exe | grep -qs "dash"; then
	echo "This script needs to be run with bash, not sh"
	exit 1
fi

if [[ "$EUID" -ne 0 ]]; then
	echo "Sorry, you need to run this as root"
	exit 2
fi

	# Home directory of the user, where the client configuration (.ovpn) will be written
	if [ -e "/home/$CLIENT" ]; then  # if $1 is a user name
		homeDir="/home/$CLIENT"
	elif [ "${SUDO_USER}" ]; then # if not, use SUDO_USER
		homeDir="/home/${SUDO_USER}"
	else # if not SUDO_USER, use /root
		homeDir="/root"
	fi
	# Determine if we use tls-auth or tls-crypt
	if grep -qs "^tls-crypt" /etc/openvpn/server.conf; then
		TLS_SIG="1"
	elif grep -qs "^tls-auth" /etc/openvpn/server.conf; then
		TLS_SIG="2"
	fi
	
newclient () {
# Determine if we use tls-auth or tls-crypt
	
	# Generates the custom client.ovpn
	cp /etc/openvpn/client-template.txt "$homeDir/$1.ovpn"
	{
		echo "<ca>"
		cat "/etc/openvpn/easy-rsa/pki/ca.crt"
		echo "</ca>"
		echo "<cert>"
		awk '/BEGIN/,/END/' "/etc/openvpn/easy-rsa/pki/issued/$1.crt"
		echo "</cert>"
		echo "<key>"
		cat "/etc/openvpn/easy-rsa/pki/private/$1.key"
		echo "</key>"
		case $TLS_SIG in
			1)
				echo "<tls-crypt>"
				cat /etc/openvpn/tls-crypt.key
				echo "</tls-crypt>"
			;;
			2)
				echo "key-direction 1"
				echo "<tls-auth>"
				cat /etc/openvpn/tls-auth.key
				echo "</tls-auth>"
			;;
		esac
	} >> "$homeDir/$1.ovpn"
}

if [ "$1" = "" ]; then
	echo "This tool will let you add new user certificates in bulk to your openvpn-install"
	echo ""
	echo "Run this script specifying a file which contains a list of one username per line"
	echo ""
	echo "Eg: openvpn-useradd-bulk.sh users.txt"
	exit
fi

while read line; do
	cd /etc/openvpn/easy-rsa/
	./easyrsa build-client-full $line nopass
	newclient "$line"
	echo ""
	echo "Client $line added, configuration is available at" ~/"$line.ovpn"
	echo ""
done < $1
