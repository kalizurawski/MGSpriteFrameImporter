#!/usr/bin/env bash

ASE_PATH=$1
BASEPATH=$(dirname ${ASE_PATH})
FILE=$(basename ${ASE_PATH})
FILENAME="${FILE%.*}"
DEBUG=0

if [ -z "$1" ]
  then
    echo "No argument supplied"
    exit 1
fi

# FILE VARIABLES
tags=$(mktemp)
hierarchy=$(mktemp)

setup_file() {
    aseprite -b --all-layers "$ASE_PATH"
    aseprite -b --ignore-layer background "$ASE_PATH"
}

get_tags() {
    # Get tags
    aseprite -b --list-tags "$ASE_PATH" > $tags
    mapfile -t TAGS < $tags
    TAGS=("${TAGS[@]%%[[:space:]]*}")
}

iterate_tags() {
    local layer=$1
    local group=$2
    local pt
    local tag

    if [[ -n "$group" ]]; then
        pt="$group/$layer"
    else
        pt="$layer"
    fi

    pt=$(echo "$pt" | tr -d '\r')

    for tag in "${TAGS[@]}"; do
        if [ $DEBUG -eq 0 ]; then
            aseprite -b \
                --layer "$pt" \
                --tag "$tag" \
                $ASE_PATH \
                --merge-duplicates \
                --sheet-columns 999 \
                --data "$BASEPATH/$FILENAME/$pt/${tag}-meta.json"

            aseprite -b \
                --layer "$pt" \
                --tag "$tag" \
                $ASE_PATH \
                --merge-duplicates \
                --sheet-columns 999 \
                --sheet "$BASEPATH/$FILENAME/$pt/${tag}.png"
        else
            echo "$BASEPATH/$FILENAME/$pt/${tag}.png"
        fi
    done
}

get_json_data() {
    aseprite -b $ASE_PATH --merge-duplicates --list-tags --list-layer-hierarchy --data $BASEPATH/$FILENAME.json
    python3 -m json.tool $BASEPATH/$FILENAME.json

    LAYERS_JSON=$(jq -c '
        .meta.layers as $layers

        | (
            reduce $layers[] as $l (
            {};
            if $l.group then
                .[$l.group] += [$l.name]
            else
                .
            end
            )
        ) as $groups

        | [
            $layers[]
            | select(has("group") | not)
            | if $groups[.name] then
                { (.name): $groups[.name] }
            else
                .name
            end
        ]
        ' $BASEPATH/$FILENAME.json)
}

export_animations() {
    echo "Exporting animations..."

    echo "$LAYERS_JSON" | jq -c '.[]' | while read -r entry; do

        TYPE=$(echo "$entry" | jq -r 'type')

        if [[ "$TYPE" == "object" ]]; then

            GROUP=$(echo "$entry" | jq -r 'keys[0]')

            echo "GROUP: $GROUP"

            echo "$entry" | jq -r '.[keys[0]][]' | while read -r sub; do
                echo "  SUB: $sub"

                iterate_tags "$sub" "$GROUP"

            done

        else

            NAME=$(echo "$entry" | jq -r '.')

            echo "ENTRY: $NAME"

            iterate_tags "$NAME"

        fi

    done
}

cleanup() {
    # move json file into top of folder
    mv $BASEPATH/$FILENAME.json $BASEPATH/$FILENAME/$FILENAME.mg_json
}

# BEGIN SCRIPT
echo "Exporting $FILE"
setup_file
get_tags
get_json_data

export_animations

cleanup