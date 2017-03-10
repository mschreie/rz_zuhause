#!/bin/bash
# Die Adresse der Fritzbox
# Beispiele:
# fbox="https://192.168.178.1:444" # SSL-Verschlüsselt, Port 444
# fbox="http://192.168.178.1" # http normal, Port 80
# fbox="abcdef28kk6oabcdef.myfritz.net:444" # myfritz-Adresse, SSL, Port 444
# fbox="https://[2001:a00:12b7:c300:a00:a000:feed:921c]:444" # IPv6-Adresse, SSL, Port 444

#################
# Konfiguration #
fbox="fritz.box"
INSECURE="--insecure" # Bei https, sonst leer lassen
# das bei der Fritzbox konfigurierte Passwort
PASSWD=""
# Der Benutzernamen für die Fritzbox
# Dieser lässt sich unter "System -> FRITZ!Box-Benutzer" konfigurieren
USER="admin"
#####################

if [ "$fbox" = "" ]; then
echo "Content-type: text/html"
echo ""
echo "Bitte Fritzbox Adresse im Script eintragen"
exit 1
fi

CURL=$(which curl) 
MD5SUM=$(which md5sum)
ICONV=$(which iconv)
AWK=$(which awk)
STYLE_RED="<font color=\"red\">"
STYLE_GREEN="<font color=\"green\">"
STYLE_YELOW="<font color=\"yellow\">"
STYLE_CYAN="<font color=\"cyan\">"
STYLE_BLUE="<font color=\"blue\">"
STYLE_END="</font>"

CURLCMD="$CURL $INSECURE -s $fbox/webservices/homeautoswitch.lua"

get_sid() {
SID=$($CURL $INSECURE -s $fbox/login_sid.lua | sed 's/.*<SID>\(.*\)<\/SID>.*/\1/')
if [ "$SID" = "0000000000000000" ]; then
challenge=$($CURL $INSECURE -s $fbox/login_sid.lua |  grep -o "<Challenge>[a-z0-9]\{8\}" | cut -d'>' -f 2)
echo "Challenge: $challenge"
echo "<br />"
CPSTR="$challenge-$PASSWD"
hash=`echo -n $CPSTR | $ICONV -f ISO8859-1 -t UTF-16LE | $MD5SUM -b | $AWK '{print substr($0,1,32)}'`
echo "MD5: $hash"
echo "<br />"
RESPONSE="$challenge-$hash"
POSTDATA="?username=$USER&response=$RESPONSE"
SID=$($CURL $INSECURE --data "$POSTDATA" -s $fbox/login_sid.lua | sed 's/.*<SID>\(.*\)<\/SID>.*/\1/')
fi
echo "SID: $SID"
echo "<br />"
}

get_value() {
RESULT=""
if [ "$2" = "" ]; then
RESULT=$($CURLCMD"?sid=$SID&switchcmd=$1")
else
RESULT=$($CURLCMD"?sid=$SID&ain=$2&switchcmd=$1")
fi
}

echo "Content-type: text/html"
echo ""
echo "<html><head><title>Fritzbox Smarthome steuern</title></head>"
echo "<body>"
echo 
echo "<input type=\"button\" name=\"reload\" onClick=\"location.assign(window.location.pathname)\" value=\"Seite neu laden, aktuelle Werte ermitteln\">"
echo "<br />"

# Bei der Fritzbox anmelden
get_sid
if [ "$SID" = "0000000000000000" ]; then
echo "$STYLE_RED Anmeldung fehlgeschlagen $STYLE_END"
echo "<br />"
exit 1
fi
if [ "$SID" = "" ]; then
echo "$STYLE_RED Anmeldung fehlgeschlagen $STYLE_END"
echo "<br />"
exit 1
fi

echo "$STYLE_GREEN Anmeldung erfolgreich $STYLE_END"
echo "<br />"

# Liste der Schalter ermitteln
get_value getswitchlist
ainlist=$RESULT

# Formular auswerten / Schalter umchalten
if [ "$QUERY_STRING" != "" ]; then
THEAIN=`echo "$QUERY_STRING" | sed -n 's/^.*ain=\([^&]*\).*$/\1/p' | sed "s/%20/ /g"`
switch=$($CURLCMD"?ain=$THEAIN&switchcmd=setswitchtoggle&sid=$SID&")
fi

# Werte der Schalter holen
echo "AIN list: $ainlist"
echo "<br />"
echo "<br />"
COUNTER=0
IFS=', ' read -r -a array <<< "$ainlist"
for AIN in "${array[@]}"
do
let COUNTER=COUNTER+1 
echo "$STYLE_RED Actor #$COUNTER $STYLE_END"
echo "<br />"
switchpresent=0
get_value getswitchname $AIN
echo "$STYLE_BLUE Name: $RESULT $STYLE_END"
echo "<br />"
get_value getswitchpresent $AIN
echo "Connected: $RESULT"
echo "<br />"
if [ "$RESULT" = "1" ]; then
get_value getswitchstate $AIN
echo "State: $RESULT"
echo "<br />"
get_value getswitchpower $AIN
switchpower=`awk "BEGIN {printf \"%.2f\n\", $RESULT/1000}"`
echo "Power: $switchpower W"
echo "<br />"
get_value getswitchenergy $AIN
echo "Energy: $RESULT Wh"
echo "<br />"
echo "<form action=\"smart_fritz_server.sh\" method=\"get\">"
echo "<input type=\"text\" name=\"ain\" value=\"$AIN\"></input>"
echo "<input type=\"submit\" name=\"subbtn\" value=\"Umschalten\">"
echo "</form>"

fi
echo "<br />"
done

echo "</body></html>" 
