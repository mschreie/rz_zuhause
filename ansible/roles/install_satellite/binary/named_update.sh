#! /usr/bin/bash
# small script which updates dns van nsupdate
# needs 3 parameters
#    hostname - full qualified  (with a . at the end)
#    ipaddress
#    reverse - reverse ipaddress full qualified (with in-addr.arpa. ) 
if [ $# -ne 3 ]
then
   echo "usage: $0 hostname ipaddress reverse" >&2
   echo "  with:" >&2
   echo "    hostname - full qualified  (with a . at the end)" >&2
   echo "    ipaddress" >&2
   echo "    reverse - reverse ipaddress full qualified (with in-addr.arpa. ) " >&2
   exit 1
fi
echo $1
echo $2
echo $3
nsupdate -k /etc/rndc.key << EOF
update add $1 3600 A $2
send
update add $3  3600 PTR $1
send
EOF
   

