#!/bin/bash
# this script :
# * dowload rss.xml file
# * read rss.xml file
# * build simple urls.txt file with  all or filtered podcasts title/media_url/img_url (# separated)
# * TODO: implemnt copy files with title into specific folder and store md5sum to avoid future replacements or force rename files
export LANG=C # avoid Invalid collation character / Illegal byte sequence

FILTER=""
REBUILD=0
RELOAD=0
RSS_FILE_NAME="rss.xml"
URLS_FILE_NAME="urls.txt"
OUTPUT_DIR="podcasts"
MEDIA_OUTPUT_DIR="$OUTPUT_DIR/media"
RSS_URL=""
ITEM_TITLE_PATH="title/text()"

export RSS_FILE="$OUTPUT_DIR/$RSS_FILE_NAME"
export URLS_FILE="$OUTPUT_DIR/$URLS_FILE_NAME"
export FORCE_YES=0
export DEBUG=0

#########################
#   F U N C T I O N S   #
#########################

# {{{ function print_usage_options
#
print_usage_options() {
    local file="$1"

    [[ -z "$file" ]] \
        && echo "WARN:print_usage_options, no file given" \
        && return 1
    [[ ! -e $file ]] \
        && echo "WARN:print_usage_options, '${file}' file not found" \
        && return 2

    sed -n '/^[[:blank:]]*case/,/^[[:blank:]]*esac/p' ${file} \
        | sed 's/^[[:blank:]]*//g;s/).*#/) #/;' \
        | awk -F# '$1 ~ /)/ {printf "\t%-25s:%s\n", $1, $2}' \
        | grep -vE "^[[:blank:]]*\*\)|;;"
}
export -f print_usage_options
# }}}

# {{{ function quit
#
quit() {
    echo "ERROR: $1"
    exit 1
}
export -f quit
# }}}

# {{{ function debug
#
debug() {
    if [[ $DEBUG -eq 1 ]] ; then
        if [ -z "$1" ] ; then
            echo ""
        else
            echo "debug: #$1#"
        fi
    fi
}
export -f debug
# }}}

# {{{ function yes_no
#
yes_no() {
    if [[ ${FORCE_YES} -ne 1 ]] ; then
        local mess="$@"
        local resp
        while true ; do
            echo -n "$mess (y/n) ? "
            read resp
            case ${resp} in
                [yY]|[yY][eE][sS]) return 0 ;;
                [nN]|[nN][oO]) return 1 ;;
                *) echo "WARNING: '$resp' : bad resp ! please answer with 'yes' or 'no' ('y' or 'n')." ;;
            esac
        done
    fi
    return 0
}
export -f yes_no
# }}}

# {{{ function xpather
#
xpather() {
    local expr="$1"
    xpath $RSS_FILE "$expr" 2>&1 | grep -v Found | sed 's/-- NODE --//g' | awk NF
}
export -f xpather
# }}}

# {{{ function usage
#
usage() {
    echo
    echo "$0 : a rss.xml {downloader / reader / syncer} for podcasts media files (title, audio, image)"
    echo
    echo "USAGE : ./sync-podcast.sh [OPTIONS]"
    echo
    echo "WHERE OPTIONS are :"
    echo
    print_usage_options $0
    echo
}
export -f usage
# }}}

# {{{ function cka (checkArgs)
#
cka() {
    local option="$1"
    local arg="$2"
    [ -z "$2" ] && quit "'$option' option need an argument"
    [[ "$2" =~ ^- ]] && quit "'$option' argument must not start with hyphen '-'"
    return 0
}
export -f cka
# }}}

#############################
#   G E T   O P T I O N S   #
#############################

# {{{ get options
i=1
for arg in $@ ; do
    next=""
    j=$(($i+1))
    # init DEBUG=1 to show this debug part
    debug "i:'$i'"
    debug "j:'$j'"
    [ $j -le ${#@} ] && next=${@:$j:1}
    debug "arg:'$arg'"
    debug "next:'$next'"
    if [[ "$arg" =~ ^-c|--config-file$ ]] ; then
        cka $arg $next && CONFIG_FILE=$next
    elif [[ "$arg" =~ ^-o|--output-dir$ ]] ; then
        cka $arg $next && OUTPUT_DIR="$next"
    fi
    let i++
done
[ -z "$CONFIG_FILE" ] && CONFIG_FILE="$OUTPUT_DIR/config"
debug "CONFIG_FILE='$CONFIG_FILE'"
# {{{ CHECK OUTPUT_DIR & MEDIA_OUTPUT_DIR
    [ -z "$OUTPUT_DIR" ] && quit "output-dir not set"
    MEDIA_OUTPUT_DIR="$OUTPUT_DIR/media"
    [ -d "$MEDIA_OUTPUT_DIR" ] || mkdir -p $MEDIA_OUTPUT_DIR
    [ -d "$MEDIA_OUTPUT_DIR" ] || quit "cannot create '$MEDIA_OUTPUT_DIR'"
# }}}
[[ -e "$CONFIG_FILE" ]] || touch "$CONFIG_FILE"
source "$CONFIG_FILE"

while [[ ! -z "$1" ]] ; do
    case $1 in
        -o|--output-dir) shift ;; # define output directory (default is 'podcasts' in current folder)
        -h|--help) usage ; exit ;; # print this message and exit without error
        -f|--filter) # this option allow to build only podcatst with title matching given {filter} regex (else, all rss urls will be build)
            cka $1 $2
            if [[ -z "$FILTER" ]] ; then
                FILTER="$2"
            else
                FILTER="$FILTER|$2"
            fi
            shift ;;
        -c|--config-file) shift ;; # specify CONFIG_FILE path instead default one (if found, this file may set default options like RSS_URL ...)\ndefault path is {output-dir}/config
        -y|--force-yes) export FORCE_YES=1 ;; # run script without interactions/confirmations
        -d|--debug) export DEBUG=1 ;; # option display information about building process
        -u|--url) cka $1 $2 && RSS_URL=$2 ; shift ;; # specify url which to dowload rss.xml (use --reload-xml to refresh an existing rss.xml file)
        -B|--rebuild-urls) REBUILD=1 ;; # this option allow to replace existing urls.txt previously built with new rss.xml file or new filter
        -R|--reload-xml) RELOAD=1 ;; # this option allow to replace existing rss.xml previously downloaded
        *) quit "'$1' : WTF !!!" ;;
    esac
    shift
done
# }}}
debug "filter:'$FILTER'"

#################################
#   R U N I N G   S C R I P T   #
#################################

export RSS_FILE="$OUTPUT_DIR/$RSS_FILE_NAME"
export URLS_FILE="$OUTPUT_DIR/$URLS_FILE_NAME"

#{{{ RELOAD rss.xml
if [ $RELOAD -eq 1 -a -e $RSS_FILE ] ; then
    if (yes_no "removing '$RSS_FILE'") ; then
         rm -v $RSS_FILE
    fi
fi
# }}}

#{{{ REBUILD urls.txt
if [ $REBUILD -eq 1 -a -e $URLS_FILE ] ; then
    if (yes_no "removing '$URLS_FILE'") ; then
         rm -v $URLS_FILE
    fi
fi
# }}}

# {{{ DOWNLOAD rss.xml (if necessary)
if [ ! -e $RSS_FILE -a ! -e $URLS_FILE ] ; then
    [ -z "$RSS_URL" ] && quit "'$RSS_FILE' & '$URLS_FILE' not found : you must provide --url or set RSS_URL into your config file to download it"
    grep -q RSS_URL $CONFIG_FILE 2>&1 >/dev/null || echo "RSS_URL='$RSS_URL'" >> $CONFIG_FILE
    wget -O $RSS_FILE $RSS_URL
fi
# }}}

# {{{ BUILDING URLS_FILE
if [ ! -e $URLS_FILE ] ; then
    echo "Building titles & '$URLS_FILE' from $RSS_FILE"
    URLS=""
    GUIDS="`xpather "//item/guid/text()"`"
    echo -n "Building "
    debug
    for guid in $GUIDS ; do
        title="` \
            xpather "//item[./guid/text()='$guid']/$ITEM_TITLE_PATH" \
            | tr [[:upper:]] [[:lower:]] \
            | sed 's/[" ?]/_/g;s/[!?:,'"'"']//g;s/ $//;s/[\(\)\/]/_/g;s/ /_/g;s/^_\{1,\}//g;s/_\{2,\}/_/g;' \
            | tr -cd '[:print:]' \
        `"
        url="`xpather "//item[./guid/text()='$guid']/enclosure/@url"`"
        img="`xpather "//item[./guid/text()='$guid']/itunes:image/@href"`"
        debug
        debug "url='$url'"
        debug "img='$img'"
        debug "guid='$guid'"
        debug "title='$title'"
        [ "x$img" == "xNo nodes found" ] && img=""
        [ "x$url" == "xNo nodes found" ] && url=""
        [ "x$title" == "xno nodes found" ] && title=""
        url="`echo ${url//url=/} | sed 's/[ "]//g;s/?.*//g'`"
        img="`echo ${img//href=/} | sed 's/[ "]//g;s/?.*//g'`"
        debug "url='$url'"
        debug "img='$img'"
        debug "guid='$guid'"
        debug "title='$title'"
        if [[ ! -z "$title" && ! -z "$url" ]] ; then
            if [[ ! -z "$FILTER" ]] ; then
                if [[ "$title" =~ ($FILTER) ]] ; then
                    URLS="$URLS $title#$url#$img"
                    echo -n o
                    continue
                fi
            else
                URLS="$URLS $title#$url#$img"
                echo -n o
                continue
            fi
        fi
        echo -n .
    done
    echo
    [ ! -z "$URLS" ] && echo "$URLS" > $URLS_FILE
fi
[ -z $URLS_FILE ] && quit "'$URLS_FILE' not found"
diff -q <(echo -n ) $URLS_FILE 2>&1 >/dev/null && quit "'$URLS_FILE' is empty"
# }}}

#####################################################
#   D O W N L O A D I N G   M E D I A   F I L E S   #
#####################################################

# {{{ Downloading Media Files
echo "Downloading Media Files"
for title_url in `cat $URLS_FILE` ; do
    title="${title_url%%#*}"
    if [[ ! -z "$FILTER" ]] ; then
        if [[ "$title" =~ ($FILTER) ]] ; then
            yes_no "Working on $title" || continue
        else
            continue
        fi
    else
        yes_no "Working on $title" || continue
    fi
    echo $title_url | {
    IFS="#" read title media_url img_url
        [ -z "$media_url" ] && quit "media_url not set for $title"
        remote_media_file="${media_url##*/}"
        media_ext="${remote_media_file##*.}"
        media_file="$MEDIA_OUTPUT_DIR/$title.$media_ext"

        if [[ -e $media_file ]] ; then
            echo "$title media already downloaded"
        else
            echo "downloading $title media files"
            wget -O $media_file $media_url
        fi

        if [ ! -z "$img_url" ] ; then
            remote_img_file="${img_url##*/}"
            img_ext="${remote_img_file##*.}"
            img_file="$MEDIA_OUTPUT_DIR/$title.$img_ext"
            if [[ -e $img_file ]] ; then
                echo "$title img already downloaded"
            else
                echo "downloading $title img file"
                wget -O $img_file $img_url
            fi
        fi
        #md5="`md5sum $file | awk '{print $1}'`"
        ##md5sum ../*${ext} | grep $md5
        #md5sum ../*mp3 ../*m4a | grep $md5
        #if [[ $? -eq 0 ]] ; then
        #    echo "$title already present in ../ directory (nothing to copy)"
        #else
        #    echo "copying $title in ../$title.$ext"
        #    cp -v $file ../$title.$ext
        #fi
    }
done
# }}}
