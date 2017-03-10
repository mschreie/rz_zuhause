#!/bin/bash
# smart_fritz_terminal.sh
# power on/off a dect 200 power socket
# mostly derived from 
# http://www.pcwelt.de/ratgeber/Dect-Funksteckdosen-10022547.html
# some changes mschreie@redhat.com
# Fr 10. Mär 09:25:18 CET 2017, mschreie@redhat.com
#   all config as parameters


usage () {
	cat >&2 << EOF
   usage: $0 -f fbux_url [-i] [-v] -p password -u user -- 
   usage: $0 -h

       -f  url of the fritz-box to connect to. e.g.
               "https://192.168.178.1:444" # SSL-cipherd, Port 444
               "http://192.168.178.1" # http normal, Port 80
                "abcdef28kk6oabcdef.myfritz.net:444" # myfritz-Address, SSL, Port 444
                "https://[2001:a00:12b7:c300:a00:a000:feed:921c]:444" # IPv6-Address, SSL, Port 444
       -i  if connecting via https insecure is needed as the certificate is not officially signed
       -v  get more / full output
       -p  password needed to connect to the fritz box
       -u  username needed to connect to the fritz box
             This may be configured here: "System -> FRITZ!Box-Benutzer
  
  Arguments

EOF
}

### while getopts -o "f:ivp:u:h" -l "fbox:,insecure,verbose,password:,user:,help" arg ; do
while getopts "f:ivp:u:h" arg ; do
  case $arg in
	  f)
             fbox="$OPTARG" 
	     ;;
	  i)
             INSECURE="--insecure" 
	     ;;
          v)
             VIEW="full"
	     ;;
	  p)
             PASSWD="$OPTARG"
	     ;;
	  u)
             USER="$OPTARG" 
	     ;;
          h)
             echo "usage" ; exit 0
             ;;
	  --) 
             break ;; 
	  *) echo "ERROR: wrong parameter: $arg" >&2
             echo "usage" >&2
	     exit 1
	     ;;
  esac
done

shift $((OPTIND-1))
 
# rudimentary sanity check on parameters

if [ "$fbox" = "" -o "$PASSWD" = "" -o "$USER" = "" ]; then
   echo ERROR: Please add recommended parameters >&2
   usage
   exit 1
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m' 
YELLOW='\033[0;33m'
NC='\033[0m'
CURL=$(which curl) 
MD5SUM=$(which md5sum)
ICONV=$(which iconv)
AWK=$(which awk)

# Die SmartHome-Seite der Fritzbox
CURLCMD="$CURL $INSECURE -s $fbox/webservices/homeautoswitch.lua"

# Funktion zum Ermitteln der SID / Anmeldung bei der Fritzbox
get_sid() {
   SID=$($CURL $INSECURE -s $fbox/login_sid.lua | sed 's/.*<SID>\(.*\)<\/SID>.*/\1/')
   if [ "$SID" = "0000000000000000" ]; then
      challenge=$($CURL $INSECURE -s $fbox/login_sid.lua |  grep -o "<Challenge>[a-z0-9]\{8\}" | cut -d'>' -f 2)
      echo challenge: $challenge
      CPSTR="$challenge-$PASSWD"
      hash=`echo -n $CPSTR | $ICONV -f ISO8859-1 -t UTF-16LE | $MD5SUM -b | $AWK '{print substr($0,1,32)}'`
      echo MD5: $hash
      RESPONSE="$challenge-$hash"
      POSTDATA="?username=$USER&response=$RESPONSE"
      SID=$($CURL $INSECURE --data "$POSTDATA" -s $fbox/login_sid.lua | sed 's/.*<SID>\(.*\)<\/SID>.*/\1/')
   fi
   echo SID: $SID
}

# Funktion zum Ermitteln von Werten
get_value() {
   RESULT=""
   if [ "$2" = "" ]; then
      RESULT=$($CURLCMD"?sid=$SID&switchcmd=$1")
   else
      RESULT=$($CURLCMD"?sid=$SID&ain=$2&switchcmd=$1")
   fi
}

get_sid # SID holen
if [ "$SID" = "0000000000000000" ]; then
   echo -e  "${RED}Anmeldung fehlgeschlagen ${NC}"
   exit 1
fi
if [ "$SID" = "" ]; then
   echo -e  "${RED}Anmeldung fehlgeschlagen ${NC}"
   exit 1
fi

echo -e  "${GREEN}Anmeldung erfolgreich ${NC}"
echo

# Liste der Schalter ermitteln
get_value getswitchlist
COUNTER=0
IFS=', ' read -r -a array <<< "$RESULT"

# Werte der Schalter holen
for AIN in "${array[@]}" ;  do
   let COUNTER=COUNTER+1 
   echo -e  "${YELLOW}Actor #$COUNTER ${NC}"
   switchpresent=0
   get_value getswitchname $AIN
   echo -e  "${CYAN}Name: $RESULT ${NC}"
   get_value getswitchpresent $AIN
   echo AIN: $AIN
   echo Connected: $RESULT
   if [ "$RESULT" = "1" ]; then
      # bei aktiven Schaltern 
      # Parameter verarbeiten, etwa: 1 on
      if [ "$1" = "$COUNTER" ]; then
        if [ "$2" = "on" ]; then
          get_value setswitchon $AIN
      	echo "set #$COUNTER on"
        fi	
          if [ "$2" = "off" ]; then
            get_value setswitchoff $AIN
      	  echo "set #$COUNTER off"
          fi	
          if [ "$2" = "toggle" ]; then
            get_value setswitchtoggle $AIN
      	  echo "set #$COUNTER toggle"
          fi	
      fi
     
     # Alle Werte ermitteln/ausgeben (langsamer)
     if [ "$VIEW" = "full" ]; then
        get_value getswitchstate $AIN
        echo State: $RESULT
        get_value getswitchpower $AIN
        switchpower=`awk "BEGIN {printf \"%.2f\n\", $RESULT/1000}"`
        echo Power: $switchpower W
        get_value getswitchenergy $AIN
        echo Energy: $RESULT Wh
        get_value gettemperature $AIN
        temperature=`awk "BEGIN {printf \"%.1f\n\", $RESULT/10}"`
        echo Temperature: $temperature °C
        echo
     fi 
   fi
   
done
exit 0
