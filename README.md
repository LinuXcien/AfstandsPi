---
layout: frontpage
comments: false
sharing: false
footer: true
sidebar: false
footer: false
title: AfstandsPi remote working Pi
---
## AfstandsPi / remote Working Pi script to make an OpenVPN appliance on a RaspberryPi

Features:
Creates a fully functional OpenVPN server from a Raspbian image (currently tested 2014-09-9)
Automatic random admin account and password created
Pi and root disabled
Automatic keys/certificates generation, with one client key/certificate
Install lighttp and CGI/PHP functionaly 
Modular Bash script

Description:
Installation:
Download version 2014-09-09-wheezy-rasbian (other versions have not been tested).
Copy installation script to home directory of pi user. Make it executable:
chmod +x installAfstandsPiVersion1.0.sh
make sure to adjust all the necessary variables in the init function and if needed information in the
OpenVPN configuration function, when done run the script:
./installAfstandsPiVersion1.0.sh
WARNING: This script disabled the pi user and creates a new management account with a (semi) random name and 
password. The name of the new account and password will only be shown when the script has finished. Make sure
to make a not of the new account name and corresponding password.

