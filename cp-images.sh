#!/bin/bash
# 
# USAGE: $0 {target_dir} {src_dir}
#
# You can use this script when images downloaded from rss are not relevant.
# Just make another directory and populate it with images named like images downloaded.
# Then launch the script with 2 pathes as parameters and let it replace old images by yours.
# 
# This script changes images content (keeping file name, without extension)
#   * Into {target_dir}  ($1)
#   * From {src_img_dir} ($2)
#   * Based on the `approximative name` of files (lowercased, without chars $EXCLUDED_CHARS_REGEX)
#
# Notes:
#   * Allowed image extensions are: "$FIND_EXT_REGEX"
#   * This script does not accept spaces in file or dir name
#
# TODO:
#   * Add debug / dry-run feature / option
#   * Add "from audio file" feature
#
usage_last_line=$(($LINENO-1))

FIND_EXT_REGEX=$'(jpeg|jpg|png|JPEG|JPG|PNG)'
SED_EXT_REGEX=$'\(jpeg\|jpg\|png\|JPEG\|JPG\|PNG\)'
EXCLUDED_CHARS_REGEX=$'[ea-_,\.]'
SED_EXCLUDED_CHARS_REGEX=$'\(-\|[ea_,\.]\)'

#
#
#
quit() {
    echo
    echo -e "  ERROR: $@"
    usage
    exit 1
}

#
#
#
usage() {
    head -n$usage_last_line $0 \
        | tail -n$(($usage_last_line-1)) \
        | sed 's/^# \{0,1\}/  /g; s#$0#'$0'#g;' \
        | sed 's#$FIND_EXT_REGEX#'$FIND_EXT_REGEX'#g;' \
        | sed 's#$EXCLUDED_CHARS_REGEX#'$EXCLUDED_CHARS_REGEX'#g;'
}

#
# assume file exists
#
unique_id() {
    [[ -z "$1" ]] && echo && return
    basename "$1" \
        | tr '[[:upper:]]' '[[:lower:]]' \
        | gsed 's/'$SED_EXT_REGEX'$//g' \
        | gsed 's/'$SED_EXCLUDED_CHARS_REGEX'//g'
    #echo "| sed 's/'$SED_EXT_REGEX'$//g'  | sed 's/'$SED_EXCLUDED_CHARS_REGEX'//g'"
}

target_dir="$1"
src_img_dir="$2"

[[ -z "$target_dir" ]]  && quit "target_dir (\$1) not defined"
[[ -d "$target_dir" ]]  || quit "target_dir ($target_dir) not found"
[[ -z "$src_img_dir" ]] && quit "src_img_dir (\$2) not defined"
[[ -d "$src_img_dir" ]] || quit "src_img_dir ($src_img_dir) not found"

count=0
found=0
copied=0
not_found=0

last_found=0
for target in `find -E $target_dir -regex ".*\.$FIND_EXT_REGEX" | sort` ; do
    unique_target_id="`unique_id $target`"
    #echo `basename $target` : $unique_target_id
    let count++
    for src in `find -E $src_img_dir -regex ".*\.$FIND_EXT_REGEX"` ; do
        unique_src_id="`unique_id $src`"
        #echo `basename $src` : $unique_src_id
        if [[ $unique_target_id =~ ^$unique_src_id ]] ; then
            let found++
            new_target=${target%%.*}.${src##*.}
            if ( cp $src $new_target ) ; then
                printf "%52s  =>  %s (copied)\n" `basename $src` `basename $new_target`
                let copied++
                if [ "x$new_target" != "x$target" ] ; then
                    rm $target
                fi
            else
                printf "%52s !=>  COPY FAILED (%s)\n" `basename $src` `basename $new_target`
            fi
        else
            # printf "%52s !=~ ^%s\n" $unique_target_id $unique_src_id
            : DEBUG OR DO NOTHING
        fi
    done
    if [[ $(($last_found+1)) -ne $found ]] ; then
        printf "%52s  !!  %s\n" `basename $target` "NOT FOUND ($unique_target_id)"
        let not_found++
    fi
    last_found=$found
done

echo "count:     '$count',"
echo "found:     '$found',"
echo "copied:    '$copied',"
echo "not_found: '$not_found'"
