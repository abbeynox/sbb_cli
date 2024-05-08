#!/usr/bin/env bash

SBB_HTTP_URL="http://fahrplan.sbb.ch/bin/query.exe/dn?jumpToDetails=yes"
SBB_API_BASE='http://transport.opendata.ch/v1/connections'

function usage {
    echo "Usage sbb OPTIONS FROM TO"
    echo "  OPTIONS:"
    echo "      -t  Time to search for connections"
    echo "      -d  Date to search for connections"
    echo "      -v  Spevifies a via Station"
    echo "      -a  Uses the Date and Time for Arrival"
    exit
}


function append_if_not_empty {
    if [ -z "$2" ] || [ "$2" = "null" ] ; then
        echo $1
    else
        echo "$1$3"
    fi
}

format_product() {
    local category=$1
    local number=$2

    case $category in
        "T")
            emoji="🚊T"
            ;;
        "B")
            emoji="🚌B"
            background_color="\e[43m"
            ;;
        "S")
            background_color="\e[44m"
            ;;
        "IR" | "IC" | "ICE" | "TGV" | "EC" | "NJ" | "IRE")
            background_color="\e[41m"
            font_style="\e[3;1m"
            ;;
        "RE")
            background_color="\e[47m" 
            font_style="\e[31m"
            ;;
        *)
            #background_color="\e[47m"  
            ;;
    esac

    if [ -n "$emoji" ]; then
        formatted_product="${emoji}${number}"
    else
        formatted_product="${category}${number}"
    fi

    if [ "$category" = "ICE" ] || [ "$category" = "EC" ] || [ "$category" = "TGV" ] || [ "$category" = "NJ" ]; then
        formatted_product="${category}"
    fi

    echo -e "\e[97m${background_color}${font_style} ${formatted_product} \e[0m"
}

function request_connection {
    queryString="from=$1&to=$2"
    queryString=$(append_if_not_empty $queryString "$3" "&via=$3")
    queryString=$(append_if_not_empty $queryString "$4" "&date=$4")
    queryString=$(append_if_not_empty $queryString "$5" "&time=$5")
    queryString=$(append_if_not_empty $queryString "$6" "&isArrivalTime=$6")
    
    resultJson=$(curl -s "$SBB_API_BASE?$queryString")
    
    local i_connection=0
    echo $resultJson | jq -r '.connections[].duration' | while read connection; do
        print_connection "$resultJson" ".connections[$i_connection]"
        (( i_connection++ ))
    done
}
function print_connection {
    local divider_top="\e[1m╭───────────────────────────────.★..──────╮\e[0m"
    local divider_bottom="\e[1m╰──────..★.───────────────────────────────╯\e[0m \n"

    echo -e $divider_top

    print_connection_header "$1" "$2"

    local i_section=0
    echo $1 | jq -r "$2.sections[].departure.station.name" | while read section; do
        print_section "$1" "$2.sections[$i_section]" $i_section
        (( i_section++ ))
    done

    echo -e $divider_bottom
}

function print_connection_header {    
    station_from=$(echo $1 | jq -r "$2.from.station.name")
    station_to=$(echo $1 | jq -r "$2.to.station.name")

    echo -e "\e[1m$station_from → $station_to\e[0m" 

    if [[ "$os" = Linux ]]; then                                                                                                                                                                                     
        departure_time=$(date -d @$(echo $1 | jq -r "$2.from.departureTimestamp") +"%H:%M")                                                                                                                          
        arrival_time=$(date -d @$(echo $1 | jq -r "$2.to.arrivalTimestamp") +"%H:%M")                                                                                                                                
        duration_hours=$(echo $(echo $1 | jq -r "$2.duration") | awk -F: '{print int($1)}')                                                                                                                              
        duration_minutes=$(echo $(echo $1 | jq -r "$2.duration") | awk -F: '{print int($2)}')                                                                                                                            
        duration="${duration_hours}h ${duration_minutes}min"                                                                                                     
    elif [[ "$os" = "macOS" ]]; then                                                                                                                                                                                 
        departure_time=$(date -j -f "%s" $(echo $1 | jq -r "$2.from.departureTimestamp") +"%H:%M")                                                                                                                   
        arrival_time=$(date -j -f "%s" $(echo $1 | jq -r "$2.to.arrivalTimestamp") +"%H:%M")                                                                                                                         
        duration=$(echo $(echo $1 | jq -r "$2.duration") | sed -E 's/^[0-9]+d//g' | awk -F: '{print $1":"$2}')                                                                                                       
    else                                                                                                                                                                                                             
        echo "Unkown OS"                                                                                                                                                                                             
        exit 1                                                                                                                                                                                                       
    fi                                                                                                                                                                                                               
    transfers=$(echo $1 | jq -r "$2.transfers")                                                                                                                                                                      
                                                                                                                                                                                                                    
    echo "$SBB_API_BASE?$queryString"                                                                                                                                                                                
    echo -e "Abfahrt: \x1b[37;42m$departure_time\e[0m"                                                                                                                                                               
    echo -e "Ankunft: \x1b[37;44m$arrival_time\e[0m"                                                                                                                                                                 
    echo "Dauer: $duration, Umsteigen: $transfers"     
}

function print_section {
    station=$(printf "%-15s" "$(echo $1 | jq -r "$2.departure.station.name")")
    if [[ "$os" = Linux ]]; then
        stime=$(date -d @$(echo $1 | jq -r "$2.departure.departureTimestamp") +"%H:%M")
    elif [[ "$os" = "macOS" ]]; then
        stime=$(date -j -f "%s" $(echo $1 | jq -r "$2.departure.departureTimestamp") +"%H:%M")
    else
        echo "Unkown OS"
        exit 1
    fi
    platform=$(echo $1 | jq -r "$2.departure.platform")
    productCategory=$(echo $1 | jq -r "$2.journey.category")
    productNumber=$(echo $1 | jq -r "$2.journey.number")
    product=$(format_product "$productCategory" "$productNumber")
    walk_object=$(echo $1 | jq -r "$2.walk")

    if [ $i_section -ne 0 ] && [ "$walk_object" = "null" ] ; then
        prev_section=".connections[$i_connection].sections[$(($i_section - 1))]"
        prev_walk_object=$(echo $1 | jq -r "$prev_section.walk")
        if [ "$prev_walk_object" = "null" ] ; then
           echo "|  - [Umsteigen]"
        fi
    fi

    if [ "$walk_object" != "null" ] ; then
        echo "|  - [Fussweg]"
    else
        departure_string="$product $station ab $stime"
        departure_string=$(append_if_not_empty "$departure_string" "$platform" ": Gleis $platform")
        departure_string=$(append_if_not_empty "$departure_string" "$product")
        echo "$departure_string"

        station=$(printf "%-15s" "$(echo $1 | jq -r "$2.arrival.station.name")")
        if [[ "$os" = Linux ]]; then
            stime=$(date -d @$(echo $1 | jq -r "$2.arrival.arrivalTimestamp") +"%H:%M")
        elif [[ "$os" = "macOS" ]]; then
            stime=$(date -j -f "%s" $(echo $1 | jq -r "$2.arrival.arrivalTimestamp") +"%H:%M")
        else
            echo "Unkown OS"
            exit 1
        fi

        platform=$(echo $1 | jq -r "$2.arrival.platform")

        arrival_string="+- $station an $stime"
        arrival_string=$(append_if_not_empty "$arrival_string" "$platform" ": Gleis $platform")
        echo "$arrival_string"
    fi
}

os=Linux
[[ $(uname) = "Darwin" ]] && os=macOS

arrival=0
while getopts ":t:d:v:aiV" o; do
    case "${o}" in
        t)
            timestamp_raw=${OPTARG}
            timestamp=$(date -d $timestamp_raw +"%H:%M")
            ;;
        d)
            datestamp_raw=${OPTARG}
            if [[ "$os" = Linux ]]; then
                datestamp=$(date -d "$(echo $datestamp_raw | sed -r 's/([0-9]+)\.([0-9]+)\.([0-9]+)/\3-\2-\1/')" +"%d.%m.%Y")
            elif [[ "$os" = "macOS" ]]; then
                datestamp=$(date -j -f "%Y-%m-%d" "$(echo $datestamp_raw | sed -E 's/([0-9]+)\.([0-9]+)\.([0-9]+)/\3-\2-\1/')" +"%d.%m.%Y")
            else
                echo "Unkown OS"
                exit 1
            fi
            ;;
        v)
            via=${OPTARG}
            ;;
        a)
            arrival=1
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
