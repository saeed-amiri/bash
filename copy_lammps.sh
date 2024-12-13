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


echo "Copying files from $SRC_DIR to $DEST_DIR"
# Find and compress .data files, then copy them
find "$SRC_DIR" -type f -name "system_after_eq3_npt.data" | while read -r file; do
    echo "Processing $file"
    tar -cJf "$file.tar.xz" -C "$(dirname "$file")" "$(basename "$file")"
    echo "Compressed $file to $file.tar.xz"
    echo "Copying $file.tar.xz to $DEST_DIR"
    rsync -R "$file.tar.xz" "$DEST_DIR"
    echo "Done with $file"
    echo "############################################"
done