#!/bin/bash

BASE_DIR="$(dirname "$(realpath "$0")")"
cd "$BASE_DIR/src" || exit 1
rm -f ./*.rs

# Generate Rust code for each D-Bus path under net.connman.iwd
for path in $(busctl tree --list net.connman.iwd); do
    temp_path="/tmp/${path//\//_}"
    mkdir -p "$temp_path"
    cd "$temp_path" || exit 1
    rm -f ./*.rs
    zbus-xmlgen system net.connman.iwd "$path"
    for file in *.rs; do
        [ -s "$file" ] || continue
        interface=$(grep -oP 'interface = "net\.connman\.iwd\.\K[^"]+' "$file" 2>/dev/null | head -1)
        [ -z "$interface" ] && continue
        pascal_case=$(echo "$interface" | sed 's@^\(.\)@\U\1@; s@\.\(.\)@\U\1@g')
        snake_case=$(echo "$interface" | sed 's@\.@_@g; s@\([^_]\)\([A-Z]\)@\1_\2@g' | tr '[:upper:]' '[:lower:]')
        new_file="$BASE_DIR/src/$snake_case.rs"
        [ -s "$new_file" ] && continue
        # Rename trait to match interface name (avoid name clashes)
        sed -i "s|pub trait [A-Za-z_][A-Za-z0-9_]*|pub trait $pascal_case|" "$file"
        # Remove default_path if it doesn't match the current path (we don't want specific paths)
        sed -i '\|default_path = "/net/connman/iwd"$|!{\|default_path =|d;}' "$file"
        # Move file to src directory with appropriate name
        mv "$file" "$new_file"
        # Add module declaration to lib.rs
        echo -e "pub mod $snake_case;\npub use $snake_case::*;\n" >> "$BASE_DIR/src/lib.rs"
    done
done

cd "$BASE_DIR" || exit 1

cargo fmt