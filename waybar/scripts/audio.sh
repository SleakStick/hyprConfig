#!/usr/bin/env bash
LANG="en_US.utf8"
IFS=$'\n'

# Notification wrapper
if command -v notify-send >/dev/null 2>&1; then
    SEND="notify-send"
elif command -v dunstify >/dev/null 2>&1; then
    SEND="dunstify"
else
    SEND="/bin/false"
fi

if [[ "$1" == "--current" ]]; then
    wpctl status | awk '
        /Sinks:/ {insinks=1; next}
        insinks && /^\s*\*/ {
            sub(/^[[:space:]]*\*[[:space:]]*[0-9]+\.\s*/, "", $0)
            print $0
            exit
        }
    '
    exit 0
fi
# --- Helper: find sink ID by description ---
get_sink_id() {
    wpctl status |
        awk -v desc="$1" '
            BEGIN { IGNORECASE=1 }
            /^\s*\*\s*|^\s*[0-9]+\. / {
                if ($0 ~ /Sinks:/) { in_sinks=1; next }
                if (in_sinks && $0 ~ /^[[:space:]]*[0-9]+\./) {
                    # Line like " 41. Built-in Audio Analog Stereo"
                    id=$1; gsub(/\./, "", id)
                    sub(/^[0-9]+\.\s*/, "", $0)
                    name=$0
                    if (name ~ desc) {
                        print id
                        exit
                    }
                }
            }
        '
}

# --- ROP: Selection was passed ---
if [[ -n "$1" ]]; then
    selection="$*"

    if [[ "$selection" == "Laptop Speakers" ]]; then
        # Grab first "raptor lake" device
        sink_id=$(get_sink_id "Raptor Lake")
    else
        sink_id=$(get_sink_id "$selection")
    fi

    if [[ -n "$sink_id" ]]; then
        wpctl set-default "$sink_id"
        $SEND -t 2000 -r 2 -u low "Activated: $selection"
    else
        $SEND -t 2000 -r 2 -u critical "Error: Cannot find sink for $selection"
    fi
    exit 0
fi

# --- ROP: Display menu entries ---
echo -en "\x00prompt\x1fSelect Output\n"

declare -A shown

# Extract sink descriptions
wpctl status |
    awk '
        BEGIN { IGNORECASE=1 }
        /Sinks:/ { in_sinks=1; next }
        in_sinks && /^[[:space:]]*[0-9]+\./ {
            line=$0
            sub(/^[[:space:]]*[0-9]+\.\s*/, "", line)
            print line
        }
    ' | while read -r desc; do
        if echo "$desc" | grep -iq "raptor lake"; then
            if [[ -z "${shown[laptop]}" ]]; then
                echo "Laptop Speakers"
                shown[laptop]=1
            fi
        else
            echo "$desc"
        fi
    done

