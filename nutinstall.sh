#!/bin/bash

Help()
{
   echo "Proxmox SNMP UPS Installer Configuration."
   echo
   echo "Syntax: $0 [-a|-c|-p]"
   echo "options:"
   echo "  -a a.b.c.d     The IP Address of the UPS to configure"
   echo "  -c public      SNMP Community Name to connect to UPS"
   echo "                 Default: public"
   echo "  -p ********    Password for Localhost nut access"
   echo "                 If not specified, a password will be generated."
   echo
}

# Set defaults if not specified on commandline
IPADDR="127.0.0.1"
UPSCOMM="public"
NUTPASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 32; echo)

# Pass Commandline Arguments
while getopts ":a:c:p:" opt; do
   case $opt in
      a) # UPS IP Address
        IPADDR="${OPTARG}";;
      c) # UPS Community
        UPSCOMM="${OPTARG}";;
      p) # nut password
        NUTPASS="${OPTARG}";;
      :) # no argument
         echo "Option -${OPTARG} requires an argument."
         exit;;
      *) # invalid option
         Help
         exit;;
   esac
done

# Check for the IP Address, this is the minimum required option
if [[ "${IPADDR}" == "127.0.0.1" ]]; then
  echo -e "ERROR: IP Address of UPS notspecified see help...\n"
  Help
  exit 404
fi

# Install Nut
apt install -y nut nut-snmp

# Download configuration files directly (no tarball)
# These 4 vars let you point the installer to YOUR fork / branch / profile folder
GH_OWNER="devstuff2453"
GH_REPO="proxmox-nut"
GH_REF="main"
GH_PROFILE="profiles/default"

GH_BASE="https://raw.githubusercontent.com/${GH_OWNER}/${GH_REPO}/${GH_REF}/${GH_PROFILE}"

echo "Downloading configuration files from ${GH_OWNER}/${GH_REPO}@${GH_REF} (${GH_PROFILE}/) ..."
mkdir -p /etc/nut

for f in nut.conf ups.conf upsd.conf upsd.users upsmon.conf upssched-cmd upssched.conf; do
  echo "  - ${f}"
  wget -qO "/etc/nut/${f}" "${GH_BASE}/${f}" || { echo "ERROR: failed to download ${GH_BASE}/${f}"; exit 1; }
done

echo "Configuring NUT"
echo "  UPS IP Address = ${IPADDR}"
echo "  UPS SNMP Community = ${UPSCOMM}"
echo "  NUT Password = ***********"
# Edit ups.conf replace port=<ipaddress>
sed -i "s/^port.*/port=$IPADDR/g" /etc/nut/ups.conf
# Edit ups.conf replace community=public (if required)
sed -i "s/^community.*/community=$UPSCOMM/g" /etc/nut/ups.conf
# Edit upsd.users - edit password=
sed -i "s/^password.*/password = $NUTPASS/g" /etc/nut/upsd.users
# Edit upsmon.conf - update password to match upsd.users
sed -i "s/^MONITOR.*/MONITOR ups@localhost 1 upsadmin $NUTPASS master/g" /etc/nut/upsmon.conf

#Ensure our actions are executable
chmod +x /etc/nut/upssched-cmd

# Restart/Start services with our new configuration
service nut-server restart
service nut-client restart
systemctl restart nut-monitor

echo "Nut successfully configured"
