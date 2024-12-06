#!/bin/bash

# Source and destination directories
SRC_DIR=$1
DEST_DIR=$2

# Create the destination directory if it doesn't exist
mkdir -p "$DEST_DIR"

# Find all directories and create them in the destination
find "$SRC_DIR" -type d -exec mkdir -p "$DEST_DIR/{}" \;

# Find and copy *_output.log and run_in.* files
find "$SRC_DIR" -type f \( -name "*_output_T.log" -o -name "run*in.*" \) -exec rsync -R {} "$DEST_DIR" \;

Find and compress .data files, then copy them
find "$SRC_DIR" -type f -name "*.data" | while read -r file; do
    tar -cJf "$file.tar.xz" -C "$(dirname "$file")" "$(basename "$file")"
    rsync -R "$file.tar.xz" "$DEST_DIR"
done