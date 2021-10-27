#!/bin/bash

# Beschreibung:
# Das Skript liest per JSON-API Parameter wie Temperaturen, Volumenströme,
# Leistungen, etc. vom Control and Monitoring Interface (C.M.I.) der Technischen Alternative
# und schreibt diese dann per knxtool (knxd) auf Gruppenadressen am KNX-Bus.
#
# Abhängigkeiten:   - jq (Command-line JSON Processor)
#                   - bc (An arbitrary precision calculator language)
#                   - curl
#
# Autor: Sebastian Schnittert (schnittert@gmail.com)
# Datum: 27.10.2021

# Intervall (in Sekunden) der zyklischen Abfrage des TA C.M.I.
# ACHTUNG: Dieses Intervall darf nicht unter 60 Sekunden liegen, da das C.M.I. dann die Abfrage verweigert!
REFRESH_INTERVALL=60

# Intervall (in Sekunden) nach dem ein Datum auch ohne Änderung erneut auf den Bus gelegt werden soll
REPEAT_INTERVALL=900 # 15 min.

# Die IP-Adresse des TA C.M.I.
CMI_HOST="192.168.188.21"
# CAN-Bus Knotennummer Ofen-Regler RSM610
OVEN_NODE="32"
# CAN-Bus Knotennummer Solar-Regler RSM610
SOLAR_NODE="42"
# CAN-Bus Knotennummer CAN-Monitor
MONITOR_NODE="50"
# Absoluter Pfad zur Login-Credentials-Datei fürs C.M.I. - Login als "expert" notwendig
# Login-File Format: machine <ip> login <name> password <pw>
LOGIN_FILE="/home/pi/smarthome/cmi2knx/.cmi-credentials"

# IP-Adresse des knxd-Host ("localhost", wenn gleicher Rechner)
KNXD_HOST="localhost"
# Befehl zum Schreiben einer Gruppenadresse
KNX_GROUPWRITE="knxtool groupwrite ip:${KNXD_HOST}"


# Aufbau der Daten vom Ofen-Regler und Definition der entsprechenden Gruppenadresse:
# Inputs
#    1 - Temperatur Außenfühler                 - °C
OVEN_I1_GROUPADDRESS="2/3/0"
#    2 - Temperatur Wasser im Ofen              - °C
OVEN_I2_GROUPADDRESS="2/3/1"
#    3 - Temperatur (nach) Rücklaufanhebung     - °C
OVEN_I3_GROUPADDRESS="2/3/15"
#    4 - Temperatur Ofen-Vorlauf                - °C
OVEN_I4_GROUPADDRESS="2/3/2"
#    5 - Temperatur Vorlauf Fußbodenheizung     - °C
OVEN_I5_GROUPADDRESS="2/3/3"
#    6 - Volumenstrom Ofenpumpe                 - l/h
OVEN_I6_GROUPADDRESS="2/4/0"


# Aufbau der Daten vom Solar-Regler:
# Inputs
#    1 - Temperatur Kollektor 1                 - °C
SOLAR_I1_GROUPADDRESS="2/3/9"
#    2 - Solarstrahlung Dach                    - W/m²
SOLAR_I2_GROUPADDRESS="2/2/2"
#    3 - Temperatur Vorlauf Solar Primär        - °C
SOLAR_I3_GROUPADDRESS="2/3/11"
#    4 - Temperatur Rücklauf Solar Sekundär     - °C
SOLAR_I4_GROUPADDRESS="2/3/14"
#    5 - Temperatur Vorlauf Solar Sekundär      - °C
SOLAR_I5_GROUPADDRESS="2/3/13"
#    6 - Volumenstrom Solar Sekundär            - l/h
SOLAR_I6_GROUPADDRESS="2/4/1"
# DL-Bus
#    1 - Temperatur Speicher Oben               - °C
SOLAR_D1_GROUPADDRESS="2/3/8"
#    2 - Temperatur Speicher Oben Mitte         - °C
SOLAR_D2_GROUPADDRESS="2/3/7"
#    3 - Temperatur Speicher Mitte              - °C
SOLAR_D3_GROUPADDRESS="2/3/6"
#    4 - Temperatur Speicher Unten Mitte        - °C
SOLAR_D4_GROUPADDRESS="2/3/5"
#    5 - Temperatur Speicher Unten              - °C
SOLAR_D5_GROUPADDRESS="2/3/4"
#    6 - Temperatur Kollektor 2                 - °C
SOLAR_D6_GROUPADDRESS="2/3/10"
#    9 - Volumenstrom Solar Primär              - l/h
SOLAR_D7_GROUPADDRESS="2/4/2"
#   10 - Temperatur Rücklauf Solar Primär       - °C
SOLAR_D8_GROUPADDRESS="2/3/12"


# Aufbau der Daten vom Monitor:
# Inputs
#    1 - Temperatur Technikraum                 - °C
MONITOR_I1_GROUPADDRESS="2/3/16"
#    2 - rel. Luftfeuchte Technikraum           - %
MONITOR_I2_GROUPADDRESS="2/5/0"
#    3 - Temperatur Taupunkt                    - °C
MONITOR_I3_GROUPADDRESS="2/3/17"
#    4 - Luftdruck Technikraum                  - mbar
MONITOR_I4_GROUPADDRESS="2/6/0"

main() {
    case $1 in
    # ===== OFEN-Regler =====
        "--oven")
        # Daten vom Ofen-Regler abholen und prüfen
        get_and_check_json "${OVEN_NODE}" "I"

        # Verarbeitung der Ofen-Input-Daten
        for i in {1..6}
        do
            # Wert mittels JSON-Parser holen und in DPT 9.xxx Format umwandeln
            HEX="$(dec_to_dpt_9 "$(jq '.Data.Inputs['$((i-1))'].Value.Value' <<< "${JSON}")")"
            # Wert am Bus setzen
            write_to_knx_grp "${HEX}" "OVEN" "I" ${i}
        done
        ;;

    # ===== SOLAR-Regler =====
        "--solar")
        # Daten vom Solar-Regler abholen und prüfen
        get_and_check_json "${SOLAR_NODE}" "I,D"

        # Verarbeitung der Solar-Input-Daten
        for i in {1..6}
        do
            # Wert mittels JSON-Parser holen und in DPT 9.xxx Format umwandeln
            HEX="$(dec_to_dpt_9 "$(jq '.Data.Inputs['$((i-1))'].Value.Value' <<< "${JSON}")")"
            # Wert am Bus setzen
            write_to_knx_grp "${HEX}" "SOLAR" "I" ${i}
        done
        # Verarbeitung der Solar-DL-Bus-Daten
        for i in {1..8}
        do
            # Wert mittels JSON-Parser holen und in DPT 9.xxx Format umwandeln
            HEX="$(dec_to_dpt_9 "$(jq '.Data."DL-Bus"['$((i-1))'].Value.Value' <<< "${JSON}")")"
            # Wert am Bus setzen
            write_to_knx_grp "${HEX}" "SOLAR" "D" ${i}
        done
        ;;

    # ===== MONITOR =====
        "--monitor")
        # Daten vom Monitor abholen und prüfen
        get_and_check_json "${MONITOR_NODE}" "I"

        # Verarbeitung der Monitor-Input-Daten
        for i in {1..4}
        do
            # Wert mittels JSON-Parser holen und in DPT 9.xxx Format umwandeln
            HEX="$(dec_to_dpt_9 "$(jq '.Data.Inputs['$((i-1))'].Value.Value' <<< "${JSON}")")"
            # Wert am Bus setzen
            write_to_knx_grp "${HEX}" "MONITOR" "I" "${i}"
        done
        ;;

    # ===== DEFAULT =====
        *) 
        echo "Falscher Eingabeparameter."
        echo "Nur --oven, --solar oder --monitor sind für die Spezifikation des CAN-Knoten zugelassen"
    esac
}

# Funktion zur Prüfung ob eine Änderung des Wertes stattgefunden hat
# oder das Wiederholungsintervall abgelaufen ist.
# $1: 2-Byte-HEX-Wert
# $2: Gruppenadressen-Prefix
# $3: Parameter-Typ [I | O | D | ...] (vgl. CMI_JSON_API_V5.pdf)
# $4: Index
value_is_new_or_elapsed() {
    # Data-Cache und Timestamp referenzieren
    local CACHE=""${2}"_"${3}""${4}"_CACHE"
    local TIMESTAMP=""${2}"_"${3}""${4}"_TIMESTAMP"
    # Timestamp beim ersten Durchlauf setzen
    if [ -z "${!TIMESTAMP}" ]; then
        eval "${TIMESTAMP}=0"
    fi

    # Die Zeit seit der letzten Aktualisierung berechnen
    ELAPSED=$(($(date +%s)-${!TIMESTAMP}))
    # Hat eine Änderung des Datums stattgefunden? (KNX-Last verringern)
    # ODER ist das Wiederholungsintervall abgelaufen?
    if [ "${!CACHE}" != "${1}" ] || [ "${ELAPSED}" -ge "${REPEAT_INTERVALL}" ]; then
        # Das neue Datum sichern
        eval "${CACHE}='${1}'"
        # Den aktuellen Timestamp setzen
        eval "${TIMESTAMP}=$(date +%s)"
        return 1
    else
        return 0
    fi
}

# Funktion zum Abholen und prüfen der JSON-Daten vom C.M.I.
# $1: CAN-Knotennummer
# $2: Abzuholende Parameter [I | O | D | ...] (vgl. CMI_JSON_API_V5.pdf)
get_and_check_json() {
    # curl URL zusammensetzen
    local URL="http://${CMI_HOST}/INCLUDE/api.cgi?jsonnode=${1}&jsonparam=${2}"
    # Daten vom C.M.I abholen
    JSON=$(curl -s --netrc-file "${LOGIN_FILE}" "${URL}")
    # Auf Erfolg prüfen
    if [ "$?" != "0" ]; then
        echo "ABBRUCH: Abrufen der JSON-Daten vom C.M.I. fehlgeschlagen." & exit 0
    fi
    # Prüfen, ob sinvolle Daten vom C.M.I. geliefert wurden.
    # Werden z.B. mehr als eine Anfrage pro Minute an das C.M.I. gestellt,
    # wird mit "TOO MANY REQUESTS" geantwortet.
    if [ "$(jq '.Status' <<< "${JSON}")" != "\"OK\"" ]; then
        echo "ABBRUCH: Keine validen Daten vom C.M.I. erhalten." & exit 0
    fi
}

# Funktion zum Schreiben der Gruppenadressen am KNX-Bus
# $1: Zu schreibender 2-Byte-HEX-Wert
# $2: Gruppenadressen-Prefix
# $3: Parameter-Typ [I | O | D | ...] (vgl. CMI_JSON_API_V5.pdf)
# $4: Index
write_to_knx_grp() {
    # Liegt ein neuer Wert vor oder ist das Wiederholungs-Intervall abgelaufen?
    value_is_new_or_elapsed "${1}" "${2}" "${3}" "${4}"
    if [ $? -eq 1 ]; then
        # Zu schreibende Gruppenadresse
        local GRP="\$"${2}"_"${3}""${4}"_GROUPADDRESS"
        # Wert am Bus setzen
        eval "${KNX_GROUPWRITE} ${GRP} ${1} &> /dev/null"
    fi
}

# Funktionsbeschreibung:
# Der Eingabeparameter in Dezimalschreibweise (z.B. 154.93) wird 
# in das KNX DPT 9.xxx Format umgewandelt und als 2-Byte Hex zurückgegeben.
# Binärformat des DPT 9.xxx:    FEEEEMMM MMMMMMMM
#                               F = 0/1 -> positiver/negativer Wert
#                               E = Exponent
#                               M = Mantisse
# Uwandlung: Dezimalwert = ((1-2*F) * 2^E * M) / 100
#
# Funktionsparameter: $1 - Dezimalwert zur Umrechnung in DPT 9.xxx
#                     $2 - Multiplikationsfaktor (z.B. um Einheiten anzupassen)
#
# Abhängigkeiten:   - bc (An arbitrary precision calculator language)
#
# Autor: Sebastian Schnittert (schnittert@gmail.com)
# Datum: 18.10.2020
dec_to_dpt_9() {

    # Multiplikationsfaktor setzen
    FACT="1"
    if [[ $# -gt 1 ]] ; then
        FACT=$2
    fi

    # Exponent initialisieren
    let E=0
    # Zwei Dezimalstellen mitnehmen
    M=$(bc <<< "$1*$FACT*100/1")

    # Exponenten bestimmen
    while [ "$M" -gt 2047 ] || [ "$M" -lt -2047 ]; do
        M=$(bc <<< "$M/2")
        let E++
    done

    # Zweier-Komplement für negative Werte
    if [ "$M" -lt 0 ]; then
        M=$(bc <<< "2^12+$M")
    fi
        
    # Binärwerte zusammenbauen
    EB=$(printf "%4b" "$(bc <<< "obase=2; $E")" | sed 's^ ^0^g')
    MB=$(printf "%12b" "$(bc <<< "obase=2; $M")" | sed 's^ ^0^g')
    B=$(cut -c -1 <<< "$MB")${EB}$(cut -c 2- <<< "$MB")

    # Als Hex formatieren
    H=$(printf "%04X" "$(bc <<< "obase=10;ibase=2; $B")")
    echo "$(cut -c -2 <<< "$H") $(cut -c 3- <<< "$H")"
}

# Wenn mit Parameter aufgerufen wird, so weitergeben und nur einmalig ausführen.
if [[ $# -gt 0 ]] ; then
    # Main-Funktion mit allen Kommandozeilen-Parametern aufrufen
    main "$@"
else
    # Prüfen, ob das Abfrageintervall mind. 60 Sekunden beträgt
    # (Wird nötig, da das C.M.I. nur 1 Anfrage pro Minute zulässt)
    if [[ $REFRESH_INTERVALL -lt 60 ]]; then
        echo "Das REFRESH_INTERVAL darf nicht unter 60 liegen" & exit 0
    fi
    # Mit dem Ofen-Regler beginnen
    NEXT_NODE=0
    # Ohne Parameter wird das Skript dauerhaft jede Minute ausgeführt
    while true; do
        # Zyklisch alle Knoten durchlaufen
        case $NEXT_NODE in
            "0")
            main --oven
            NEXT_NODE=1
            ;;
            "1")
            main --solar
            NEXT_NODE=2
            ;;
            "2")
            main --monitor
            NEXT_NODE=0
            ;;
        esac
        # Das Abfrageintervall abwarten
        sleep "${REFRESH_INTERVALL}"
    done
fi