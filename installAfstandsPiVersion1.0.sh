#!/bin/bash
# Raspberry Pi combined OpenVPN installation script
# (c) LinuXcien 2014
# To do:
# Random account name
# Random account pass
# Enable WOL site via script
# Python + modules installer
# More secure version of ssmtp

function switchErrorCheckingOn {
        # Check for variables that are not set (stop script):
	set -o nounset
	set -o errexit
	set -e
}

function oops {
        # Foreground color to red 
        echo -n "$(tput setaf 1)"
        echo -n "${PROGNAME}: ${1:-"Unknown Error"}" 1>&2
	# Foreground color back to white
        echo "$(tput setaf 7)"
        echo "${PROGNAME}: ${1:-"Unknown Error"}" >>$LOGFILE
        exit 1
}


function init {
	export VERSION="1.0"
	export DATE=`date +%Y%m%d%H%M%S`
	export PROGNAME=$0
	export PI_HOME="/home/pi"
	export PI_USER="pi"
	export LOGFILE="installAfstandsPi_$DATE.log"
	export LOCALE_VAR="nl_NL.UTF-8 UTF-8"
	export LOCALE_DEFAULT="nl_NL.UTF-8"
	export XKBMODEL="pc105"
	export XKBLAYOUT="us"
	export XKBVARIANT="euro"
	export XKBOPTIONS=""
	export BACKSPACE="guess"
	PRIMARY_IP=10.0.0.252
	PRIMARY_MASK=255.255.255.0
	PRIMARY_NETWORK=10.0.0.0
	PRIMARY_BROADCAST=10.0.0.255
	GW=10.0.0.1
	HOST_NAME=afstandspi
	HOST_FQDN_NAME=afstandspi.local
	DNS_PRIMARY=10.0.0.1
	DNS_SECONDARY=8.8.8.8
	DNS_SEARCH=afstandspi.local
	RANDOM_ACCOUNT=`cat /dev/urandom | tr -dc 'a-z' | fold -w 8 | head -n 1`
	RANDOM_PASSWD=`cat /dev/urandom | tr -dc '_A-Z-a-z-0-9_!@#$%^&*()_+{}|:<>?=' | fold -w 8 | head -n 1`
	ROUTE1="10.33.0.0/24 via 10.0.0.32"
	ROUTE2="10.128.0.0/24 via 10.0.0.32"
	# Certifcate and key file names:
	OVPN_SERVER_NAME=server
	OVPN_FIRST_CLIENT_NAME=client1
	OVPN_DEV=tun
	OVPN_PROTOCOL=tcp
	OVPN_PORT=443
	OVPN_NETWORK=10.10.0.0
	OVPN_MASK=255.255.255.0
	#echo "Script $0, version $VERSION"
	echo "Prepare fresh Raspbian AfstandsPi/OpenVPN installation, version $VERSION."
}

function create_log_file() {
        touch $LOGFILE || oops "$LINENO: Cannot create logfile."
}


function oops {
        # Foreground color to red 
        echo -n "$(tput setaf 1)"
        echo -n "${PROGNAME}: ${1:-"Unknown Error"}" 1>&2
	# Foreground color back to white
        echo "$(tput setaf 7)"
	if [ -f $LOGFILE ];
	then
        	echo "${PROGNAME}: ${1:-"Unknown Error"}" >>$LOGFILE
	fi
        exit 1
}


function check_version {
	# Are we running on the Raspbian?
	#BOARDREV = cat /proc/cmdline | awk -v RS=" " -F= '/boardrev/ { print $2 }'
	# Version 7.6 corresponds with 
	if [ -f /etc/debian_version ];
	then
		DEBIAN_VERSION=`cat /etc/debian_version`
		echo "Running on Debian $DEBIAN_VERSION"
	else
		oops "$LINENO: Not running on Debian, giving up."
	fi
}

function real_pi() {
	# Check if we are running on a real physical Raspberry Pi and not virtual (qemu)
	PI_REVISION=`cat /proc/cpuinfo | grep "Revision" | cut -d ":" -f2 | cut -d " " -f2`
	if [ PI_REVISION == "0000" ];
	then
		echo "Not running on real hardware, will skip certiain actions (OpenVPN not restarted for example)" >>$LOGFILE
	else
		echo "Running on hardware Pi, revision $PI_REVISION, continuing as normal." >>$LOGFILE
	fi

}

function check_for_pi  {
	# Check to see if pi user is present
	IS_THIS_PI=true
	grep -q pi /etc/passwd || echo "No pi user found.";IS_THIS_PI=false
}

function updateDebian {
	echo "Updating Debian system ....."
	sudo apt-get -y update >>$LOGFILE || oops "$LINENO: Error running apt-get update."
	sudo apt-get -y upgrade >>$LOGFILE || oops "$LINENO: Error running apt-get upgrade."
	# Might want to add pi firmware upgrade.
	# sudo apt-get -y dist-upgrade || oops "$LINENO: Error running apt-get dist-upgrade."
}

function silent_boot {
	echo "Enable quiet boot startup process."
	sudo cp /boot/cmdline.txt /boot/cmdline.txt_$DATE >>$LOGFILE || oops "$LINENO: Failing to make backup copy of /boot/cmdline.txt."
	sudo sed /boot/cmdline.txt -i -e "s/console=tty1/console=tty3/g" >>$LOGFILE || oops "$LINENO: Error adjusting redirection output to tty3."
	if grep -q "quiet boot" /boot/cmdline.txt; then
		echo "cmdline.tx already patched, skipping."
	else
		sudo sed /boot/cmdline.txt -i -e "s/$/ quiet boot/g" >>$LOGFILE || oops "$LINENO: Error enabling silent boot."
	fi
}


function random_account()
{
	echo "Making new account with a random name"
	sudo adduser $RANDOM_ACCOUNT --disabled-login --gecos "LinuXcien, administrative account." || oops "$LINENO: Failing to add new account."
	#sudo echo "$RANDOM_ACCOUNT ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/$RANDOM_ACCOUNT
	sudo cp /etc/sudoers /etc/sudoers.bak || oops "$LINENO: Cannot make backup copy of sudoers file."
	sudo cp /etc/sudoers /etc/sudoers.tmp || oops "$LINENO: Cannot make temporary copy of sudoers file."
	sudo chmod 0666 /etc/sudoers.tmp || oops "$LINENO: Cannot set security on temporary copy of sudoers file."
	sudo echo "$RANDOM_ACCOUNT ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.tmp || oops "$LINENO: Cannot write to temporary copy of sudoers file."
	sudo cp /etc/sudoers.tmp /etc/sudoers || oops "$LINENO: Cannot write new sudoers file."
	sudo rm /etc/sudoers.tmp || oops "$LINENO: Cannot remove temporary sudoers file."
	echo "Account: $RANDOM_ACCOUNT added."
}

function random_password ()
{
	echo "Setting random password"
	echo $RANDOM_ACCOUNT:$RANDOM_PASSWD | sudo chpasswd || oops "$LINENO: Cannot set password on new account."
	echo "Random password for account: $RANDOM_ACCOUNT set."
}

function disable_pi ()
{
        # Check to see if pi user is present
	if grep -q pi /etc/passwd;
	then
		echo "Disabling pi account..."
		sudo usermod --expiredate 1 pi >>$LOGFILE || oops "$LINENO: Error disabling pi user."
	else
		echo "No pi user account found."
	fi
}

function make_interfaces ()
{
	echo "Setting interface(s) configuration."
	echo "Primary interface IP addres and mask: $PRIMARY_IP $PRIMARY_MASK"
#	echo "Secondary interface IP addres and mask: $SECONDARY_IP $SECONDARY_MASK"
	echo "Making backup of original interfaces... to /etc/network/interfaces.backup.$DATE"
	sudo bash -c "cp /etc/network/interfaces /etc/network/interfaces.backup.$DATE" || oops "$LINENO: Cannot make copy of interfaces file."
	cat > interfaces_tmp_$DATE << _EOF_ || oops "$LINENO: Cannot create new temporary interfaces file."
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto eth0
iface eth0 inet static
        address $PRIMARY_IP
        netmask $PRIMARY_MASK
        network $PRIMARY_NETWORK
        broadcast $PRIMARY_BROADCAST
        gateway $GW
	#post-up ip route add $ROUTE1
	#post-up ip route add $ROUTE2
        # dns-* options are implemented by the resolvconf package, if installed
        dns-nameservers $DNS_PRIMARY $DNS_SECONDARY
        dns-search $DNS_SEARCH
_EOF_
	sudo bash -c "cp interfaces_tmp_$DATE /etc/network/interfaces" || oops "$LINENO: Cannot overwrite copy of /etc/network/interfaces file."
	rm interfaces_tmp_$DATE || oops "$LINENO: Cannot remove temporary copy of interfaces file."
}

function set_hosts_hostname ()
{
	echo "Setting hostname and hosts file."
	echo "Making backup of hostname file to /etc/hostname.backup.$DATE."
	sudo bash -c "cp /etc/hostname /etc/hostname.backup.$DATE" || oops "$LINENO: Cannot create backup of hostname file."
	cat > hostname_tmp_$DATE << _EOF_ || oops "$LINENO: Cannot create new temporary hostname file."
$HOST_NAME
_EOF_
	echo "Making backup of hosts file to /etc/hosts.backup.$DATE."
	sudo bash -c "cp /etc/hosts /etc/hosts.backup.$DATE" || oops "$LINENO: Cannot create backup of hosts file."
	sudo cat > hosts_tmp_$DATE << _EOF_ || oops "$LINENO: Cannot create new temporary hosts file."
127.0.0.1	localhost
$PRIMARY_IP	$HOST_FQDN_NAME		$HOST_NAME

# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
_EOF_
	sudo bash -c "cp hostname_tmp_$DATE /etc/hostname" || oops "$LINENO: Cannot overwrite copy of /etc/hostname file."
	sudo bash -c "cp hosts_tmp_$DATE /etc/hosts" || oops "$LINENO: Cannot overwrite copy of /etc/hosts file."
	sudo bash -c "rm hostname_tmp_$DATE" || oops "$LINENO: Cannot remove temporary hostname file."
	sudo bash -c "rm hosts_tmp_$DATE" || oops "$LINENO: Cannot remove temporary hosts file."
	sudo hostname -b -F /etc/hostname || oops "$LINENO: Failing to set new hostname."
}

function fix_locale () {
	echo "Locale setup....."
	if grep -q "^$LOCALE_VAR" /etc/locale.gen;
	then
		echo "/etc/locale.gen already enabled for $LOCALE_VAR skipping." >> $LOGFILE
	else
		sudo bash -c "echo \$1 $LOCALE_VAR  >> /etc/locale.gen" || oops "$LINENO: Error writing to /etc/local.gen."
	fi
	if [ -f /etc/default.locale ]; 
	then
		# Make backup copy of /etc/default.locale if exists, otherwise make a new one:
        	sudo bash -c "cp /etc/default/locale /etc/default/locale.backup.$DATE"  ||  oops "$LINENO: Error making backup copy of /etc/default/locale."
	fi	
        sudo bash -c "echo \$1 LANG=$LOCALE_DEFAULT  > /etc/default/locale" || oops "$LINENO: Error writing to /etc/default/locale."
        sudo bash -c "echo \$1 LC_ALL=$LOCALE_DEFAULT  >> /etc/default/locale" || oops "$LINENO: Error writing to /etc/default/locale."
        sudo bash -c "echo \$1 LANGUAGE=$LOCALE_DEFAULT  >> /etc/default/locale" || oops "$LINENO: Error writing to /etc/default/locale."
        sudo locale-gen $LOCALE_DEFAULT >>$LOGFILE || oops "$LINENO: Error running locale-gen."
        #source /etc/default/locale || oops "$LINENO: Failing to add language environment variables from default locale."
	# Setting environment so we can continue:
        export LC_ALL=$LOCALE_DEFAULT 2>>$LOGFILE
        export LANG=$LOCALE_DEFAULT
}

function set_keyboard_layout() {
        echo "Setting keyboard layout.... "
	if [ -f /etc/default/keyboard ];
	then
		# Make backup copy of default keyboard layout setting, otherwise make a new one:
        	sudo bash -c "cp /etc/default/keyboard /etc/default/keyboard.backup.$DATE" >>$LOGFILE || oops "$LINENO: Error making backup copy of /etc/default/keyboard" 
	else
        	sudo bash -c "echo \$1 XKBMODEL=$XKBMODEL > /etc/default/keyboard" || oops "$LINENO: Error writing to /etc/default/keyboard."
        	sudo bash -c "echo \$1 XKBLAYOUT=$XKBLAYOUT >> /etc/default/keyboard" || oops "$LINENO: Error writing to /etc/default/keyboard."
        	sudo bash -c "echo \$1 XKBVARIANT=$XKBVARIANT >> /etc/default/keyboard" || oops "$LINENO: Error writing to /etc/default/keyboard."
        	sudo bash -c "echo \$1 XKBOPTIONS=$XKBOPTIONS >>  /etc/default/keyboard" || oops "$LINENO: Error writing to /etc/default/keyboard."
        	sudo bash -c "echo \$1 BACKSPACE=$BACKSPACE >> /etc/default/keyboard" || oops "$LINENO: Error writing to /etc/default/keyboard."
	fi
        sudo udevadm trigger --subsystem-match=input --action=change || oops "$LINENO: Error running udevadm to update keyboard layout."
}

function set_timezone() {
        echo "Timezone setup....."
        #echo "sudo debconf-set-selections debconf/frontend select noninteractive" | sudo debconf-set-selections || oops "$LINENO: Error setting Debian packaging to non-interactive."
        sudo bash -c 'echo "Europe/Amsterdam" > /etc/timezone' || oops "$LINENO: Error writing to /etc/timezone."
        #sudo dpkg-reconfigure -f noninteractive tzdata << _EOF_ >>$LOGFILE || oops "$LINENO: Could not set timezone."
	#Europe
	#Amsterdam
	#_EOF_
        sudo dpkg-reconfigure -f noninteractive tzdata
}


function install_vim ()
{
	echo "Installing VIM ....."
	sudo apt-get -y install vim >>$LOGFILE || oops "$LINENO: Error installing vim."
}

function install_openvpn ()
{
	echo "Installing OpenVPN and OpenSSL."
	sudo apt-get -y install openvpn openssl >>$LOGFILE || oops "$LINENO: Error installing OpenVPN and OpenSSL."
}

function configure_openvpn ()
{	
	# Only interactive part at the moment, trying to figure out how to automate this also.
	echo "Configuring OpenVPN server and create client certificate."
	# Check if existing OpenVPN configuration present, if so make a backup:
	if [ -f /etc/openvpn/server.conf ];
	then
		sudo tar cfz openvpn_config_backup_$DATE.tgz /etc/openvpn  >>$LOGFILE 2>&1  || oops "$LINENO: Found existing OpenVPN configuration but could not make backup."
	fi
	# "Using three environment vars files one for creation of CA key, one for server key"
	# "and one for first client keys."
	sudo cp -R /usr/share/doc/openvpn/examples/easy-rsa /etc/openvpn  >>$LOGFILE || oops "$LINENO: Error copying easy-rsa folder to /etc/openvpn."
	# Environment file for creation of CA key:
	cat > openVPN_vars_CA_$DATE << "_EOF_" || oops "$LINENO: Error cannot create temporary vars CA file."
export EASY_RSA="`pwd`"
export OPENSSL="openssl"
export PKCS11TOOL="pkcs11-tool"
export GREP="grep"
export KEY_CONFIG=`$EASY_RSA/whichopensslcnf $EASY_RSA`
export KEY_DIR="$EASY_RSA/keys"
echo NOTE: If you run ./clean-all, I will be doing a rm -rf on $KEY_DIR
export PKCS11_MODULE_PATH="dummy"
export PKCS11_PIN="dummy"
export KEY_SIZE=1024
export KEY_EXPIRE=3650
export KEY_COUNTRY="NL"
export KEY_PROVINCE="Utrecht"
export KEY_CITY="Leusden"
export KEY_ORG="LinuXcien"
export KEY_EMAIL="info@linuxcien.nl"
export KEY_CN="AfstandsPI CA"
export KEY_NAME="AfstandsPI"
export KEY_OU="LinuXcien"
export PKCS11_MODULE_PATH=changeme
export PKCS11_PIN=1234
_EOF_
	# Environment file for creation of server key:
	cat > openVPN_vars_SERVER_$DATE << "_EOF_" || oops "$LINENO: Error cannot create temporary vars server file."
export EASY_RSA="`pwd`"
export OPENSSL="openssl"
export PKCS11TOOL="pkcs11-tool"
export GREP="grep"
export KEY_CONFIG=`$EASY_RSA/whichopensslcnf $EASY_RSA`
export KEY_DIR="$EASY_RSA/keys"
echo NOTE: If you run ./clean-all, I will be doing a rm -rf on $KEY_DIR
export PKCS11_MODULE_PATH="dummy"
export PKCS11_PIN="dummy"
export KEY_SIZE=1024
export KEY_EXPIRE=3650
export KEY_COUNTRY="NL"
export KEY_PROVINCE="Utrecht"
export KEY_CITY="Leusden"
export KEY_ORG="LinuXcien"
export KEY_EMAIL="info@linuxcien.nl"
export KEY_CN="AfstandsPI server"
export KEY_NAME="AfstandsPI server"
export KEY_OU="LinuXcien"
export PKCS11_MODULE_PATH=changeme
export PKCS11_PIN=1234
_EOF_
	# Environment file for creation of first client key / cert:
	cat > openVPN_vars_CLIENT_$DATE << "_EOF_" || oops "$LINENO: Error cannot create temporary vars server file."
export EASY_RSA="`pwd`"
export OPENSSL="openssl"
export PKCS11TOOL="pkcs11-tool"
export GREP="grep"
export KEY_CONFIG=`$EASY_RSA/whichopensslcnf $EASY_RSA`
export KEY_DIR="$EASY_RSA/keys"
echo NOTE: If you run ./clean-all, I will be doing a rm -rf on $KEY_DIR
export PKCS11_MODULE_PATH="dummy"
export PKCS11_PIN="dummy"
export KEY_SIZE=1024
export KEY_EXPIRE=3650
export KEY_COUNTRY="NL"
export KEY_PROVINCE="Utrecht"
export KEY_CITY="Leusden"
export KEY_ORG="LinuXcien"
export KEY_EMAIL="info@linuxcien.nl"
export KEY_CN="AfstandsPI Client One"
export KEY_NAME="AfstandsPI Client One"
export KEY_OU="LinuXcien"
export PKCS11_MODULE_PATH=changeme
export PKCS11_PIN=1234
_EOF_
	sudo bash -c "cp openVPN_vars_CA_$DATE /etc/openvpn/easy-rsa/2.0/vars_CA" >>$LOGFILE || oops "$LINENO: Error cannot copy vars CA file to /etc/openvpn/easy-rsa/2.0"
	sudo bash -c "cp openVPN_vars_SERVER_$DATE /etc/openvpn/easy-rsa/2.0/vars_SERVER" >>$LOGFILE || oops "$LINENO: Error cannot copy vars SERVER file to /etc/openvpn/easy-rsa/2.0"
	sudo bash -c "cp openVPN_vars_CLIENT_$DATE /etc/openvpn/easy-rsa/2.0/vars" >>$LOGFILE || oops "$LINENO: Error cannot copy vars file to /etc/openvpn/easy-rsa/2.0"
	#. ./vars
	sudo bash -c "cd /etc/openvpn/easy-rsa/2.0;source vars_CA;./clean-all" >>$LOGFILE 2>&1
	# First build CA key:
	sudo bash -c "cd /etc/openvpn/easy-rsa/2.0;source vars_CA;./pkitool --initca \$*" >>$LOGFILE 2>&1
	# Next build server key:
	sudo bash -c "cd /etc/openvpn/easy-rsa/2.0;source vars_SERVER;./pkitool --server $OVPN_SERVER_NAME \$*" >>$LOGFILE 2>&1
	#sudo ./build-key-server server
	# Next build first client key:
	sudo bash -c "cd /etc/openvpn/easy-rsa/2.0;source vars;./pkitool $OVPN_FIRST_CLIENT_NAME \$*" >>$LOGFILE 2>&1
	# sudo ./build-key client1
	echo "Running Diffie Hellman calculation, this can take over 30 minutes..."
	sudo bash -c "cd /etc/openvpn/easy-rsa/2.0;source vars;./build-dh"
	#cd /etc/openvpn/easy-rsa/2.0/keys
	sudo bash -c "cd /etc/openvpn/easy-rsa/2.0/keys;cp ca.crt ca.key dh1024.pem ${OVPN_SERVER_NAME}.crt ${OVPN_SERVER_NAME}.key /etc/openvpn" || oops "$LINENO: Error copying keys and certificates to /etc/openvpn folder."
	# Removing temporary environment var files:
	rm openVPN_vars_CA_$DATE || oops "$LINENO: This shouldn't happen, but cannot remove openVPN_vars_CA_$DATE"
	rm openVPN_vars_SERVER_$DATE || oops "$LINENO: This shouldn't happen, but cannot remove openVPN_vars_SERVER_$DATE"
	rm openVPN_vars_CLIENT_$DATE || oops "$LINENO: This shouldn't happen, but cannot remove openVPN_vars_CLIENT_$DATE"
	sudo bash -c "cp /usr/share/doc/openvpn/examples/sample-config-files/server.conf.gz /etc/openvpn" || oops "$LINENO: Error copying sample configuration to /etc/openvpn folder."
	sudo bash -c "gunzip -q -f /etc/openvpn/server.conf.gz"  >>$LOGFILE || oops "$LINENO: Error unzipping sample configuration to /etc/openvpn folder."
	# Adjusting OpenVPN server configuration to run on configured procotol and port:
	if [ $OVPN_PROTOCOL == "tcp" ];
	then
		sudo sed /etc/openvpn/server.conf -i -e "s/proto udp/;proto udp/g" || oops "$LINENO: Error disabling OpenVPN server listening to UDP."
		sudo sed /etc/openvpn/server.conf -i -e "s/;proto tcp/proto tcp/g" || oops "$LINENO: Error enabling OpenVPN server listening to TCP."
	fi
	sudo sed /etc/openvpn/server.conf -i -e "s/port 1194/port $OVPN_PORT/g" || oops "$LINENO: Failing to set port number in OpenVPN server configuration."
	sudo sed /etc/openvpn/server.conf -i -e "s/server 10.8.0.0 255.255.255.0/server $OVPN_NETWORK $OVPN_MASK/g" || oops "$LINENO: Failing to set IP network and mask in OpenVPN server configuration."
	if [ $PI_REVISION != "0000" ];
	then
		# Running on real Raspberry Pi hardware, restarting OpenVPN.
		sudo /etc/init.d/openvpn stop;sudo /etc/init.d/openvpn start >>$LOGFILE || oops "$LINENO: Cannot restart OpenVPN daemon."
	else
		# Running virtual.....
		echo "Not restarting OpenVPN, we seem to be running in virtual mode, kernel might not be compatible." >>$LOGFILE
	fi
	echo "OpenVPN setup done, first client certificate: /etc/openvpn/easy-rsa/2.0/keys/${OVPN_FIRST_CLIENT_NAME}.key"
}

function install_lighttpd ()
{
	echo "Installing lighttpd Web server and enabling fastcgi"
	sudo apt-get -y install lighttpd >>$LOGFILE || oops "$LINENO: Error installing lighttpd"
	sudo chown -R www-data:www-data /var/www >>$LOGFILE || oops "$LINENO: Failing to set security on /var/www."
	# Enabling fast-cgi and fast-cgi for PHP
	if [ -f /etc/lighttpd/conf-enabled/10-fastcgi.conf ];
	then
		echo "FastCGI for lighttpd seems to be already enabled, skipping." >>$LOGFILE
	else
		sudo ln -s /etc/lighttpd/conf-available/10-fastcgi.conf /etc/lighttpd/conf-enabled/10-fastcgi.conf >>$LOGFILE || oops "$LINENO: Failing to enable fastcgi."
	fi
	if [ -f /etc/lighttpd/conf-enabled/15-fastcgi-php.conf ];
	then
		echo "FastCGI for lighttpd and PHP seems to be already enabled, skipping." >>$LOGFILE
	else
		sudo ln -s /etc/lighttpd/conf-available/15-fastcgi-php.conf /etc/lighttpd/conf-enabled/15-fastcgi-php.conf >>$LOGFILE || oops "$LINENO: Failing to enable fastcgi for PHP."
	fi
	sudo apt-get -y install php5-common php5-cgi php5 >>$LOGFILE || oops "$LINENO: Failing to install php5 modules."
	sudo lighty-enable-mod fastcgi-php >>$LOGFILE || echo "fastcgi-php already enabled." >>$LOGFILE
	sudo service lighttpd restart >>$LOGFILE || oops "$LINENO: Failing to restart lighttpd."
}

function display_results ()
{
	echo "User account made with username: $RANDOM_ACCOUNT and password: $RANDOM_PASSWD"
	echo "Primary interface IP addres and mask: $PRIMARY_IP $PRIMARY_MASK"
	echo "OpenVPN configuration in /etc/openvpn, keys and certificates in /etc/openvpn/"
}

switchErrorCheckingOn
init
create_log_file
check_version
real_pi
fix_locale
set_keyboard_layout
set_timezone
updateDebian
random_account
random_password
install_vim
install_openvpn
silent_boot
make_interfaces
set_hosts_hostname
install_openvpn
configure_openvpn
install_lighttpd
disable_pi
display_results
