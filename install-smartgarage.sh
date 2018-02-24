#!/usr/bin/env bash

# https://github.com/geekslant/smartgarage/
VERSION=v0.1

# The MIT License (MIT)
#
# Copyright (c) 2018 Geek Slant
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

set -e

function hashline() {
	echo "###############################################################"
}

clear
hashline
echo " Geek Slant Smart Garage Installation Script "
echo " ${VERSION}"
hashline
echo ""

if [[ $EUID -ne 0 ]]; then
   echo "install-smartgarage must be run as root."
   echo "Try: sudo ./install-smartgarage"
   echo ""
   exit 1
fi

DIR=`dirname $0`
SKIP_CAMERA=0
CAMERA_PASSWORD=""
CAMERA_IP_ADDRESS=""
INTERACTIVE_MODE=0
TOTAL_PARTS=10

function ask() {
    # https://djm.me/ask
    local prompt default reply

    while true; do

        if [ "${2:-}" = "Y" ]; then
            prompt="Y/n"
            default=Y
        elif [ "${2:-}" = "N" ]; then
            prompt="y/N"
            default=N
        else
            prompt="y/n"
            default=
        fi

        # Ask the question (not using "read -p" as it uses stderr not stdout)
        echo -n "$1 [$prompt] "

        # Read the answer (use /dev/tty in case stdin is redirected from somewhere else)
        read reply </dev/tty

        # Default?
        if [ -z "$reply" ]; then
            reply=$default
        fi

        # Check if the reply is valid
        case "$reply" in
            Y*|y*) return 0 ;;
            N*|n*) return 1 ;;
        esac

    done
}

function bail() {
	echo ""
	hashline
    if [ -z "$1" ]; then
        echo "Exiting due to error"
    else
        echo "Exiting due to error: $*"
    fi
    exit 1
}

function infopart() {
	echo ""
	hashline
	echo "Part ${1}/${TOTAL_PARTS}:"
	echo "${2}"
	hashline
	echo ""
}

function prompt_for_camera_password_and_ip_address() {
	echo "prompt here"
}

function configure_opener_and_camera() {
	echo ""
	if ask "Do you know the camera password and IP address?"; then
		echo ""
		echo "Configuring Pi Smart Garage Door Opener and HiKam S6 Camera..."
		echo ""
		while true; do
			echo -n "Camera password: "
			read CAMERA_PASSWORD </dev/tty
			echo -n "Camera IP address: "
			read CAMERA_IP_ADDRESS </dev/tty
			echo ""
			if ask "Are you sure these are correct?"; then
				SKIP_CAMERA=0
				echo ""
				break
			else
				echo ""
				continue
			fi
		done
	else
		bail "The camera password and IP address are required to configure the camera."
	fi
}

function configure_opener() {
	SKIP_CAMERA=1
	echo ""
	echo "Configuring Pi Smart Garage Door Opener only..."
	echo ""
}

function choose_installation_mode() {
	echo ""
	if ask "Do all steps automatically?" Y; then
		return
	else
		INTERACTIVE_MODE=1
	fi
}

function choose_installation_configuration() {
	local reply

	echo "Choose an installation configuration:"
	echo ""
	echo "0: Configure Pi Smart Garage Door Opener and HiKam S6 Camera"
	echo "1: Configure Pi Smart Garage Door Opener Only"
	echo "q: Quit"
	echo ""

	while true; do
		echo -n "0|1|q? "
		read reply </dev/tty
		case "$reply" in
			0) 
				configure_opener_and_camera 
				break
				;;
			1) 
				configure_opener 
				break
				;;
			q) exit 1 ;;
		esac
	done

	choose_installation_mode
}

function execute_step() {
	if [ ${INTERACTIVE_MODE} == "1" ] && !( ask "Do this step?" Y ) ; then
		echo "Skipping..."
		return 1
	fi
}

function update_package_database() {
	infopart 1 "Updating package database..."
	if execute_step ; then
		echo "apt-get update"
		apt-get update
	fi
}

function upgrade_installed_packages() {
	infopart 2 "Upgrading installed packages..."
	if execute_step ; then
		echo "apt-get -y upgrade"
		apt-get -y upgrade
	fi
}

function install_node_repo() {
	infopart 3 "Installing NodeSource Node.js v8.x repository..."
	if execute_step ; then
		echo "curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -"
		curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -
	fi
}

function install_nodejs_and_npm() {
	infopart 4 "Installing Node.js and npm..."
	if execute_step ; then
		echo "apt-get install -y nodejs"
		apt-get install -y nodejs
	fi
}

function install_avahi() {
	infopart 5 "Installing Avahi..."
	if execute_step ; then
		echo "apt-get install -y libavahi-compat-libdnssd-dev"
		apt-get install -y libavahi-compat-libdnssd-dev
	fi
}

function install_ffmpeg() {
	if [ ${SKIP_CAMERA} == "1" ]; then
		infopart 6 "No camera: Skipping ffmpeg installation..."
		return
	fi
	infopart 6 "Installing ffmpeg..."
	if execute_step ; then
		echo "apt-get install -y ffmpeg"
		apt-get install -y ffmpeg
	fi
}

function install_homebridge() {
	infopart 7 "Installing Homebridge..."
	if execute_step ; then
		echo "npm install -g --unsafe-perm homebridge"
		npm install -g --unsafe-perm homebridge
	fi
}

function install_homebridge_garage_door_opener_plugin() {
	infopart 8 "Installing Homebridge garage door opener plugin..."
	if execute_step ; then
		echo "npm install -g homebridge-rasppi-gpio-garagedoor"
		npm install -g homebridge-rasppi-gpio-garagedoor
	fi
}

function install_homebridge_camera_plugin() {
	if [ ${SKIP_CAMERA} == "1" ]; then
		infopart 9 "No camera: Skipping Homebridge camera plugin installation..."
		return
	fi
	infopart 9 "Installing Homebridge camera plugin..."
	if execute_step ; then
		echo "npm install -g homebridge-camera-ffmpeg"
		npm install -g homebridge-camera-ffmpeg
	fi
}

function configure_homebridge() {
	infopart 10 "Configuring Homebridge..."
	if execute_step ; then
		echo "mkdir /var/lib/homebridge"
		mkdir /var/lib/homebridge

		echo "cp ${DIR}/homebridge /etc/default/"
		cp ${DIR}/homebridge /etc/default/

		echo "cp `${DIR}/homebridge.service /etc/systemd/system/"
		cp ${DIR}/homebridge.service /etc/systemd/system/

		echo "cp ${DIR}/garage-door-gpio /var/lib/homebridge/"
		cp ${DIR}/garage-door-gpio /var/lib/homebridge/

		if [ ${SKIP_CAMERA} == "1" ]; then
			echo "cp ${DIR}/config-without-camera.json /var/lib/homebridge/config.json"
			cp ${DIR}/config-without-camera.json /var/lib/homebridge/config.json
		else
			echo "cp ${DIR}/config-with-camera.json /var/lib/homebridge/config.json"
			cp ${DIR}/config-with-camera.json /var/lib/homebridge/config.json

			echo "sed -i 's/CAMERA_PASSWORD/${CAMERA_PASSWORD}' /var/lib/homebridge/config.json"
			sed -i 's/CAMERA_PASSWORD/${CAMERA_PASSWORD}' /var/lib/homebridge/config.json

			echo "sed -i 's/CAMERA_IP_ADDRESS/${CAMERA_IP_ADDRESS}' /var/lib/homebridge/config.json"
			sed -i 's/CAMERA_IP_ADDRESS/${CAMERA_IP_ADDRESS}' /var/lib/homebridge/config.json
		fi

		echo "useradd -M --system homebridge"
		useradd -M --system homebridge

		echo "chmod -R 0777 /var/lib/homebridge"
		chmod -R 0777 /var/lib/homebridge

		echo "systemctl daemon-reload"
		systemctl daemon-reload

		echo "systemctl enable homebridge"
		systemctl enable homebridge

		echo "systemctl start homebridge"
		systemctl start homebridge
	fi
}

choose_installation_configuration

update_package_database || bail "Failed to update package database."

upgrade_installed_packages || bail "Failed to upgrade installed packages."

install_node_repo || bail "Failed to install Node.js repository."

install_nodejs_and_npm || bail "Failed to install Node.js and npm."

install_avahi || bail "Failed to install Avahi."

install_ffmpeg || bail "Failed to install ffmpeg."

install_homebridge || bail "Failed to install Homebridge."

install_homebridge_garage_door_opener_plugin || bail "Failed to install Homebridge garage door opener plugin."

install_homebridge_camera_plugin || bail "Failed to install Homebridge camera plugin."

configure_homebridge

echo ""
hashline
echo "Installation complete"
hashline
