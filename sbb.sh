#!/bin/bash

SBB_HTTP_URL="http://fahrplan.sbb.ch/bin/query.exe/dn?jumpToDetails=yes"
SBB_API_BASE='http://transport.opendata.ch/v1/connections'

function usage {
    echo "Usage ./sbb.sh OPTIONS FROM TO"
    echo "  OPTIONS:"
    echo "      -t  Time to search for connections"
    echo "      -d  Date to search for connections"
    echo "      -v  Spevifies a via Station"
    echo "      -a  Uses the Date and Time for Arrival"
    echo "      -i  Use it and be happy"
    exit
}

function append_if_not_empty {
    if [ -z $2 ] ; then
        echo $1
    else
        echo "$1$2"
    fi
}

function request_connection {
    queryString="from=$1&to=$2"
    queryString=$(append_if_not_empty $queryString "&via=$3")
    queryString=$(append_if_not_empty $queryString "&date=$4")
    queryString=$(append_if_not_empty $queryString "&time=$5")
    queryString=$(append_if_not_empty $queryString "&isArrivalTime=$6")
    
    resultJson=$(curl -s "$SBB_API_BASE?$queryString")
    
    readarray connections < <(echo $resultJson | jq -r '.connections[].duration')

    i_connection=0
    for connection in "${connections[@]}"
    do
	print_connection "$resultJson" ".connections[$i_connection]"
	i_connection=$(expr $i_connection + 1)
    done
}

function print_connection {
    print_connection_header "$1" "$2"

    readarray sections < <(echo $1 | jq -r "$2.sections[].walk")
    i_section=0
    for section in "${sections[@]}"
    do
	print_section "$1" "$2.sections[$i_section]" $i_section
	i_section=$(expr $i_section + 1)
    done
}

function print_connection_header {
    echo ""
    
    station_from=$(echo $1 | jq -r "$2.from.station.name")
    station_to=$(echo $1 | jq -r "$2.to.station.name")

    echo "$station_from - $station_to"
    
    departure_time=$(date -d @$(echo $1 | jq -r "$2.from.departureTimestamp") +"%H:%M")
    arrival_time=$(date -d @$(echo $1 | jq -r "$2.to.arrivalTimestamp") +"%H:%M")
    duration=$(echo $(echo $1 | jq -r "$2.duration") | sed -r 's/^[0-9]+d//gi')
    transfers=$(echo $1 | jq -r "$2.transfers")

    echo "Abfahrt: $departure_time"
    echo "Ankunft: $arrival_time"
    echo "Dauer: $duration, Umsteigen: $transfers"
}

function print_section {
    if [ $i_section -ne 0 ] ; then
	echo "|  - [Umsteigen]"
    fi

    station=$(printf "%-15s" "$(echo $1 | jq -r "$2.departure.station.name")")
    stime=$(date -d @$(echo $1 | jq -r "$2.departure.departureTimestamp") +"%H:%M")
    platform=$(echo $1 | jq -r "$2.departure.platform")
    product=$(echo $1 | jq -r "$2.journey.name")

    echo "+- $station ab $stime: Gleis $platform [$product]"

    station=$(printf "%-15s" "$(echo $1 | jq -r "$2.arrival.station.name")")
    stime=$(date -d @$(echo $1 | jq -r "$2.arrival.arrivalTimestamp") +"%H:%M")
    platform=$(echo $1 | jq -r "$2.arrival.platform")

    echo "+- $station an $stime: Gleis $platform"
}

function print_ascii_art {
    echo " ____ ____ ____ _________ ____ ____ ____ ____ ____ "
    echo "||C |||L |||I |||       |||R |||U |||L |||E |||Z ||"
    echo "||__|||__|||__|||_______|||__|||__|||__|||__|||__||"
    echo '|/__\|/__\|/__\|/_______\|/__\|/__\|/__\|/__\|/__\|'
    echo ""
    echo "Created by absturztaube <me@absturztau.be>"
    echo "░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░"
    echo "░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░"
    echo "░░░░░░░░░░░░░░░░░░░░▒▓██████▓▓▓███▓▒░░░░░░░░░░░░░░░░░░░░░░░"
    echo "░░░░░░░░░░░░░░░░░░▒████████████████████▓░░░░░░░░░░░░░░░░░░░"
    echo "░░░░░░░░░░░░░░░░▒████████████████████████▓░░░░░░░░░░░░░░░░░"
    echo "░░░░░░░░░░░░░░░▓▓██████████████████████████▒░░░░░░░░░░░░░░░"
    echo "░░░░░░░░░░░░░░░█████████████████████████████▒░░░░░░░░░░░░░░"
    echo "░░░░░░░░░░░░░░▓█████████████████████████████▓░░░░░░░░░░░░░░"
    echo "░░░░░░░░░░░░░░█████████████████████████████████▓░░░░░░░░░░░"
    echo "░░░░░░░░░░░░░▒██████████████████▓█████████████████▓░░░░░░░░"
    echo "░░░░░░░░░░░░▒▓███▒███████████▓▒▒▒▓██████████████▓▒░░░░░░░░░"
    echo "░░░░░░░░░░░░░▓██▒▒▓█████▓██▓▒▒▒▒▒▓█████████████▒░░░░░░░░░░░"
    echo "░░░░░░░░░░░░░░▒▓▒▒▒▒▒▒█▓▒▒▒▒▒▒▒▒▒▒▒████████████▓░░░░░░░░░░░"
    echo "░░░░░░░░░░░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓████████████▒░░░░░░░░░░"
    echo "░░░░░░░░░░░░░░░▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓████████████▒░░░░░░░░░"
    echo "░░░░░░░░░░░░░░░▓█████▒▒▒▒▒▓███████▒▒▒███████████▒░░░░░░░░░░"
    echo "░░░░░░░░░░░░░░░▓▓▒░░▒▓▒▒▒▒▓▒░░░░▒▓▒▒▒███████████▒░░░░░░░░░░"
    echo "░░░░░░░░░░░░░░░▒▒░░▒▓▓▒▒▒▓░░░░░▓░▒▒▒▒███████████▒░░░░░░░░░░"
    echo "░░░░░░░░░░░░░░░░▒▓▒▓▓▒▒▒▒▒▓▓▓▓▓▓▒▒▒▒▒█▒▓███████▒░░░░░░░░░░░"
    echo "░░░░░░░░░░░░░░░░▒▒▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▒█████▓░░░░░░░░░░░░"
    echo "░░░░░░░░░░░░░░░▒▓▒▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓█████▒░░░░░░░░░░░░"
    echo "░░░░░░░░░░░░░░░▒▒▒▒▒▓▓▓▒▒▒▒▒▒▒▓▓▒▒▒▒▒▒▒▒▒████▒░░░░░░░░░░░░░"
    echo "░░░░░░░░░░░░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▒▒▒▒▒▒▒▒▓████▒░░░░░░░░░░░░░"
    echo "░░░░░░░░░░░░░░░░▒▓▓▒▒▒▒▒▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▓███▓░░░░░░░░░░░░░░"
    echo "░░░░░░░░░░░░░░░░░░░░░▓▓▒▒▒▒▒▓▓▒▒▒▒▒▒▒▒▒▒████░░░░░░░░░░░░░░░"
    echo "░░░░░░░░░░░░░░░░░░░░░░░██████▓▒▒▒▒▒▒▒▒▒▒▓▒░░░░░░░░░░░░░░░░░"
    echo "░░░░░░░░░░░░░░░░░░░░░░░▒████▓▒▒▒▒▒▒▒▒▒▒▒▒░░░░░░░░░░░░░░░░░░"
    echo "░░░░░░░░░░░░░░░░░░░░░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░░░░░░░░░░░░░░░░░"
    echo "░░░░░░░░░░░░░░░░░░░░░░░░▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░░░░░░░░░░░░░░░░░"
    echo ""
    exit
}

arrival=0
while getopts ":t:d:v:aiV" o; do
    case "${o}" in
        t)
            timestamp_raw=${OPTARG}
            timestamp=$(date -d $timestamp_raw +"%H:%M")
            ;;
        d)
            datestamp_raw=${OPTARG}
            datestamp=$(date -d "$(echo $datestamp_raw | sed -r 's/([0-9]+)\.([0-9]+)\.([0-9]+)/\3-\2-\1/')" +"%d.%m.%Y")
            ;;
        v)
            via=${OPTARG}
            ;;
        a)
            arrival=1
            ;;
	i)
	    print_ascii_art
	    ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

from=$1
to=$2

if [ -z "${from}" ] || [ -z "${to}" ] ; then
    usage
    exit
fi

if [ -z "${datestamp}" ] ; then
    datestamp=$(date +"%d.%m.%Y")
fi

if [ -z "${timestamp}" ] ; then
    timestamp=$(date +"%H:%M")
fi

request_connection "$from" "$to" "$via" "$datestamp" "$timestamp" "$arrival"
