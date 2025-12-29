#!/bin/sh

# ./header.sh -t "[string of text]"
# reset
OPTIND=1
WIDTH=$(tput cols)
HEADER_TEXT=""

# flags
usage () {
    printf "Usage: %s [-t] [string]\n" "$0"
    printf "\t-t            (required) string text for header\n"
    exit 1
}

while getopts "t:" opt; do
    case $opt in
        t)
            HEADER_TEXT=$OPTARG
            ;;
        *)
            printf "input not recognized\n"
            usage
            ;;
    esac
done
 
if [ -z "$HEADER_TEXT" ]; then
    printf "Text input missing...\n"
    usage
fi

TITLE_LENGTH=${#HEADER_TEXT}
PADDING_SIZE=$(( (WIDTH - TITLE_LENGTH) / 2 ))
REM_SIZE=$(( (WIDTH - TITLE_LENGTH) % 2 ))
HEADER_LINE=$(printf "%${WIDTH}s" | tr ' ' '=')

printf -v LINE '%*s' "$WIDTH" ''
printf -v PADDING '%*s' "$PADDING_SIZE" ''

printf "%s\n" "$HEADER_LINE"
printf "%${PADDING_SIZE}s%s%${PADDING_SIZE}s" " " "$HEADER_TEXT" " "
[[ $REM_SIZE -eq 1 ]] && printf " "
printf "%s\n" "$HEADER_LINE"
