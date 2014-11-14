---
layout: frontpage
comments: false
sharing: false
footer: true
sidebar: false
footer: false
title: AfstandsPi remote working Pi
---
##AfstandsPi / remote Working Pi script to make an OpenVPN appliance on a RaspberryPi


###Features:
Creates a fully functional OpenVPN server from a Raspbian image (currently tested 2014-09-9)
* Automatic generation of (semi) random admin account name and password 
* pi and root accounts disabled (assuming root hasn't been enabled in standard Raspbian image)
* Automatic keys/certificates generation, with one client key/certificate included automatically
* Install lighttpd and CGI/PHP for web server functionality 
* Modular Bash script
* Based on standard Raspbian

###Description:
To streamline our installation process for the AfstandsPi Raspberry Pi based VPN product we build this installation script. The script takes a standard Raspbian installation and installs an OpenVPN server plus a lighttpd based webserver. Except for functions required to make the script work, the following functions are functional to create the AfstandsPi. Each function can be switched on/off at the bottom of the script:
* init: set here different variables, such as IP addresses, locale, keyboard, OpenVPN configuration etc.
* silent_boot: boots Pi with only Raspberry log in top left corner, looks nicest like that
* random_account: generates semi random (and valid) account name and adds account to system and sudoers
* random_password: does what is says for the new account
* disable_pi: disables the omnipresent Pi user
* make_interfaces: creates a static IP address by removing the interfaces file (makes backup first) and replacing it with variables set in init
* set_hosts_name: does the same for the system host name
* fix_locale: sets local to whatever is set in init
* set_keyboard_layout: does the same for keyboard
* set_timezone: does the same for timezone
* install_vim: to get some colours while editing in vi
* install_openvpn: does just that (and openssl)
* configure_openvpn: from variables set in init, creates a working OpenVPN configuration, generates CA, server and client keys/certificates, copies CA and server certs to /etc/openvpn
* install_lighttpd: installs a web server and CGI/PHP for additional AfstandsPi functionality (such as Wake The Computer)
* display_results: shows IP address and account information (make note of new account name and password, because login as pi is not possible any more from this point)
Output of all commands are re-directed to a logfile in the same directory as where script was ran.

###Installation:
Download version 2014-09-09-wheezy-rasbian (other versions have not been tested).
Copy installation script to home directory of pi user. Make it executable:

>
> chmod +x installAfstandsPiVersion1.0.sh
>

make sure to adjust all the necessary variables in the init function and if needed information in the
OpenVPN configuration function, when done run the script:

>
> ./installAfstandsPiVersion1.0.sh
>

WARNING: This script disables the pi user and creates a new management account with a (semi) random name and 
password. The name of the new account and password will only be shown when the script has finished. Make sure
to make a note of the new account name and corresponding password.

