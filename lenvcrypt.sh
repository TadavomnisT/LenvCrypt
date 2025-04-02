#!/bin/bash

# LenvCrypt: Encrypted Linux Environment. A secure, password-protected safebox storage for GNU/Linux.

# VERSION :           2.0.0
# AUTHOR :            TadavomnisT (Behrad.B)
# Repo :              https://github.com/TadavomnisT/LenvCrypt
# REPORTING BUGS :    https://github.com/TadavomnisT/LenvCrypt/issues
# COPYRIGHT :
#     Copyright (c) 2025   License GPLv3+
#     This is free software: you are free to change and redistribute it.
#     There is NO WARRANTY, to the extent permitted by law.  

VERSION="2.0.0"

# Colors for Terminal
RED=$'\033[31m'
GREEN=$'\033[32m'
BLUE=$'\033[34m'
YELLOW=$'\033[33m'
MAGENTA=$'\033[35m'
NC=$'\033[0m'  # No Color

# Message functions (only the tag is colored)
error()     { echo -e "[${RED}ERROR${NC}]: $1"; }
log_msg()   { echo -e "[${GREEN}LOG${NC}]: $1"; }
help_msg()  { echo -e "[${YELLOW}HELP${NC}]: $1"; }
warn()      { echo -e "[${MAGENTA}WARN${NC}]: $1"; }

# Directories
SAFEBOX_DIR="./Safeboxes"
MOUNTPOINT_DIR="./Mountpoints"

# Ensure directories exist
mkdir -p "$SAFEBOX_DIR" "$MOUNTPOINT_DIR"

# Default sizes (in MB)
SIZES=(100 200 500 1024)

# Check if cryptsetup exists (cross-platform tip: trying to detect package managers)
check_cryptsetup() {
    if ! command -v cryptsetup >/dev/null 2>&1 ; then
        error "cryptsetup is not installed on this system."
        help_msg "Please install cryptsetup with your package manager."
        if command -v apt-get >/dev/null 2>&1; then
            echo "On Debian/Ubuntu, run: sudo apt-get install cryptsetup"
        elif command -v dnf >/dev/null 2>&1; then
            echo "On Fedora, run: sudo dnf install cryptsetup"
        elif command -v pacman >/dev/null 2>&1; then
            echo "On Arch Linux, run: sudo pacman -S cryptsetup"
        else
            echo "Please consult your distribution's documentation."
        fi
        exit 1
    fi
}

# Usage/help info
show_help() {
    # Print a logo
    echo -e "\033[31m        #/##################| mm"
    echo -e "      #/*                  #| ##"
    echo -e "    #/  #                  #| ##         m####m   ##m####m  ##m  m##"
    echo -e "  #/    #                  #| ##        ##mmmm##  ##\"   ##   ##  ##"
    echo -e "#|#######                  #| ##        ##\"\"\"\"\"\"  ##    ##   \"#mm#\""
    echo -e "#|                         #| ##mmmmmm  \"##mmmm#  ##    ##    ####"
    echo -e "#|  #     /#\\    #         #| \"\"\"\"\"\"\"    \"\"\"\"\"   \"\"    \"\"     \"\""
    echo -e "#|  #    @   @   #         #|          mmmm"
    echo -e "#|  #    @   @   #       .%%%%%%.    ##\"\"\"#                            ##"
    echo -e "#|  #     \\#/    #     .%        %. ##\"        ##m####      ##m###m   #######"
    echo -e "#|                    %           % ##         ##\"          ##\"  \"##    ##"
    echo -e "#|   /#\\    #         %           % ##m        ##  \"##  ### ##    ##    ##"
    echo -e "#|  @   @   #        XXXXXXXXXXXXXXX ##mmmm#   ##   ##m ##  ###mm##\"    ##mmm"
    echo -e "#|  @   @   #        X      _      X   \"\"\"\"    \"\"    ####\"  ## \"\"\"       \"\"\""
    echo -e "#|   \\#/    #        X    (   )    X                  ###   ##"
    echo -e "#|                   X     | |     X                  ##"
    echo -e "#|                   X      ~      X      #############"
    echo -e "#|                   XXXXXXXXXXXXXXX"
    echo -e "#|"
    echo -e "#|                          ###################"
    echo -e "#|##########################/"
    echo -e "\033[0m"  # Reset to default color
    cat <<EOF
${MAGENTA}LenvCrypt:${NC} Encrypted Linux Environment. A secure, password-protected safebox storage for GNU/Linux.

VERSION :           ${VERSION}
AUTHOR :            TadavomnisT (Behrad.B)
Repo :              https://github.com/TadavomnisT/LenvCrypt
REPORTING BUGS :    https://github.com/TadavomnisT/LenvCrypt/issues
COPYRIGHT :
    Copyright (c) 2025   License GPLv3+
    This is free software: you are free to change and redistribute it.
    There is NO WARRANTY, to the extent permitted by law.

[${YELLOW}HELP${NC}]: Usage: $0 <command> [options/safebox_name] [extra_option]

Commands:
  ${GREEN}create (-c, --create)${NC} => Create a new safebox.
                   The script will prompt for a safebox name and a size.
                   Example: $0 create
                            $0 -c mysafebox

  ${GREEN}open (-o, --open)${NC}   => Open an existing safebox.
                   Example: $0 open mysafebox
                            $0 --open mysafebox

  ${GREEN}close (-c, --close)${NC}  => Close an opened safebox.
                   Example: $0 close mysafebox
                            $0 -c mysafebox

  ${GREEN}list (-l, --list)${NC}   => List all existing safeboxes.
                   Example: $0 list
                            $0 --list

  ${GREEN}delete (-d, --delete)${NC} => Delete an existing safebox.
                   This removes the .img file and associated mountpoint.
                   Example: $0 delete mysafebox
                            $0 -d mysafebox

  ${GREEN}export (-e, --export)${NC} => Export a safebox image to a specified file.
                   Example: $0 export mysafebox /path/to/export.img
                            $0 --export mysafebox /path/to/export.img

  ${GREEN}import (-i, --import)${NC} => Import a safebox image from a file.
                   The safebox will be stored as <safebox_name>.img.
                   Example: $0 import mysafebox /path/to/import.img
                            $0 -i mysafebox /path/to/import.img

  ${GREEN}version (-v, --version)${NC} => Display LenvCrypt version.
                   Example: $0 version
                            $0 --version

  ${GREEN}help (-h, --help)${NC}    => Display this help information.
                   Example: $0 help
                            $0 -h
EOF
}

# Display version information
show_version() {
    echo "LenvCrypt version ${VERSION}"
}

# Create a new safebox
create_safebox() {
    # Check if a name is passed as a parameter
    safebox_name="$1"
    if [[ -z "$safebox_name" ]]; then
        read -p "Enter safebox name: " safebox_name
    fi

    if [[ -z "$safebox_name" ]]; then
        error "Safebox name cannot be empty."
        exit 1
    fi

    img_file="${SAFEBOX_DIR}/${safebox_name}.img"
    if [[ -f "$img_file" ]]; then
        error "Safebox '$safebox_name' already exists."
        exit 1
    fi

    echo "Choose safebox size (in MB) from the following options or enter your own value:"
    echo "${GREEN}Recommended sizes:${NC}"
    for size in "${SIZES[@]}"; do
        echo "  - ${size}MB"
    done
    echo ""
    read -p "Size (MB): " safebox_size

    if ! [[ "$safebox_size" =~ ^[1-9][0-9]*$ ]]; then
        error "Invalid size. Please enter a positive integer."
        exit 1
    fi

    log_msg "Creating safebox '$safebox_name' of size ${safebox_size}MB..."
    dd if=/dev/zero of="$img_file" bs=1M count="$safebox_size" status=progress
    if [[ $? -ne 0 ]]; then
        error "Error creating disk image."
        exit 1
    fi

    log_msg "Formatting the disk image with LUKS..."
    sudo cryptsetup luksFormat "$img_file"
    if [[ $? -ne 0 ]]; then
        error "Error during luksFormat."
        log_msg "Deleting safebox image '$img_file'..."
        rm -f "$img_file"
        if [[ $? -ne 0 ]]; then
            error "Error deleting '$img_file'."
            exit 1
        fi
        exit 1
    fi

    log_msg "Device successfully formatted with LUKS, Enter the password again to continue."

    sudo cryptsetup luksOpen "$img_file" "$safebox_name"
    if [[ $? -ne 0 ]]; then
        error "Error opening the LUKS container."
        exit 1
    fi

    sudo mkfs.ext4 "/dev/mapper/${safebox_name}" -q
    if [[ $? -ne 0 ]]; then
        error "Error creating ext4 filesystem."
        sudo cryptsetup luksClose "$safebox_name"
        exit 1
    fi

    mkdir -p "${MOUNTPOINT_DIR}/${safebox_name}"
    sudo cryptsetup luksClose "$safebox_name"

    log_msg "Safebox '$safebox_name' successfully created."
    help_msg "To open it later, run: $0 open $safebox_name"
}

# Open an existing safebox
open_safebox() {
    safebox_name="$1"
    if [[ -z "$safebox_name" ]]; then
        error "No safebox name provided for open command."
        exit 1
    fi

    img_file="${SAFEBOX_DIR}/${safebox_name}.img"
    if [[ ! -f "$img_file" ]]; then
        error "Safebox image '$img_file' does not exist."
        help_msg "You should create it first with: $0 create"
        exit 1
    fi

    log_msg "Opening safebox '$safebox_name'..."
    sudo cryptsetup luksOpen "$img_file" "$safebox_name"
    if [[ $? -ne 0 ]]; then
        error "Error opening the LUKS container."
        exit 1
    fi

    mountpoint="${MOUNTPOINT_DIR}/${safebox_name}"
    mkdir -p "$mountpoint"
    sudo mount "/dev/mapper/${safebox_name}" "$mountpoint"
    if [[ $? -ne 0 ]]; then
        error "Error mounting the filesystem."
        sudo cryptsetup luksClose "$safebox_name"
        exit 1
    fi

    log_msg "Safebox '$safebox_name' successfully opened and mounted at:"
    echo "  ${GREEN}$mountpoint${NC}"
    echo ""
    help_msg "You can now access your safebox files."
    help_msg "You may need to run ${RED}'sudo su'${NC} over there to get permission to work with files."
    warn "${RED}BE WARNED${NC} ${BLUE}that the safebox '$safebox_name' is open and any user may access it,${NC} ${RED}DON'T FORGET${NC} ${BLUE}to close it after you're done!${NC}"
}

# Close an opened safebox
close_safebox() {
    safebox_name="$1"
    if [[ -z "$safebox_name" ]]; then
        error "No safebox name provided for close command."
        exit 1
    fi

    mountpoint="${MOUNTPOINT_DIR}/${safebox_name}"
    if mountpoint -q "$mountpoint"; then
        sudo umount "$mountpoint"
        if [[ $? -ne 0 ]]; then
            error "Could not unmount '$mountpoint'."
            exit 1
        fi
    else
        warn "'$mountpoint' is not mounted."
    fi

    sudo cryptsetup luksClose "$safebox_name"
    if [[ $? -ne 0 ]]; then
        error "Could not close the LUKS container '$safebox_name'."
        exit 1
    fi

    log_msg "Safebox '$safebox_name' has been closed."
}

# List all safeboxes (by listing .img files)
list_safeboxes() {
    echo "*** Listing available safeboxes in ${SAFEBOX_DIR}:"
    shopt -s nullglob
    safebox_found=0
    for file in "$SAFEBOX_DIR"/*.img; do
        safebox_found=1
        safebox=$(basename "$file" .img)
        echo " - ${GREEN}$safebox${NC}"
    done
    if [[ $safebox_found -eq 0 ]]; then
        warn "No safeboxes found."
    fi
}

# Delete a safebox: prompt confirmation, unmount/close if needed, and remove files.
delete_safebox() {
    safebox_name="$1"
    if [[ -z "$safebox_name" ]]; then
        error "No safebox name provided for delete command."
        exit 1
    fi

    img_file="${SAFEBOX_DIR}/${safebox_name}.img"
    mountpoint="${MOUNTPOINT_DIR}/${safebox_name}"

    if [[ ! -f "$img_file" ]]; then
        error "Safebox image '${img_file}' does not exist."
        exit 1
    fi

    warn "Are you sure you want to permanently delete safebox '$safebox_name'?"
    read -p "Type 'yes' to confirm: " confirm
    if [[ "$confirm" != "yes" ]]; then
        log_msg "Deletion cancelled."
        exit 0
    fi

    if mountpoint -q "$mountpoint"; then
        log_msg "Unmounting safebox from '$mountpoint'..."
        sudo umount "$mountpoint"
        if [[ $? -ne 0 ]]; then
            error "Could not unmount '$mountpoint'. Aborting deletion."
            exit 1
        fi
    fi

    if sudo cryptsetup status "$safebox_name" >/dev/null 2>&1; then
        log_msg "Closing open LUKS container for '$safebox_name'..."
        sudo cryptsetup luksClose "$safebox_name"
        if [[ $? -ne 0 ]]; then
            error "Could not close the LUKS container '$safebox_name'. Aborting deletion."
            exit 1
        fi
    fi

    log_msg "Deleting safebox image '$img_file'..."
    rm -f "$img_file"
    if [[ $? -ne 0 ]]; then
        error "Error deleting '$img_file'."
        exit 1
    fi

    if [[ -d "$mountpoint" ]]; then
        log_msg "Removing mountpoint directory '$mountpoint'..."
        rmdir "$mountpoint" 2>/dev/null
        if [[ $? -ne 0 ]]; then
            warn "Could not remove mountpoint directory. It may not be empty."
        fi
    fi

    log_msg "Safebox '$safebox_name' has been permanently deleted."
}

# Export a safebox image to a given file
export_safebox() {
    safebox_name="$1"
    export_dest="$2"

    if [[ -z "$safebox_name" ]]; then
        error "No safebox name provided for export command."
        exit 1
    fi

    if [[ -z "$export_dest" ]]; then
        read -p "Enter destination path for export (e.g., /path/to/export.img): " export_dest
    fi

    if [[ -z "$export_dest" ]]; then
        error "Export destination cannot be empty."
        exit 1
    fi

    img_file="${SAFEBOX_DIR}/${safebox_name}.img"
    if [[ ! -f "$img_file" ]]; then
        error "Safebox image '$img_file' does not exist."
        exit 1
    fi

    log_msg "Exporting safebox '$safebox_name' to '$export_dest'..."
    cp "$img_file" "$export_dest"
    if [[ $? -ne 0 ]]; then
        error "Error exporting safebox."
        exit 1
    fi
    log_msg "Safebox '$safebox_name' exported successfully."
}

# Import a safebox image from a given file
import_safebox() {
    safebox_name="$1"
    import_src="$2"

    if [[ -z "$safebox_name" ]]; then
        error "No safebox name provided for import command."
        exit 1
    fi

    if [[ -z "$import_src" ]]; then
        read -p "Enter source file path to import (e.g., /path/to/import.img): " import_src
    fi

    if [[ -z "$import_src" ]]; then
        error "Import source cannot be empty."
        exit 1
    fi

    if [[ ! -f "$import_src" ]]; then
        error "Source file '$import_src' does not exist."
        exit 1
    fi

    dest_file="${SAFEBOX_DIR}/${safebox_name}.img"
    if [[ -f "$dest_file" ]]; then
        error "A safebox with the name '$safebox_name' already exists."
        exit 1
    fi

    log_msg "Importing safebox image from '$import_src' as '$safebox_name'..."
    cp "$import_src" "$dest_file"
    if [[ $? -ne 0 ]]; then
        error "Error importing safebox."
        exit 1
    fi
    log_msg "Safebox '$safebox_name' imported successfully."
}

######################################################################
# Main script
######################################################################
check_cryptsetup

cmd="$1"
safebox_param="$2"
file_param="$3"

case "$cmd" in
    create|-c|--create)
        create_safebox "$safebox_param"
        ;;
    open|-o|--open)
        open_safebox "$safebox_param"
        ;;
    close|-c|--close)
        close_safebox "$safebox_param"
        ;;
    list|-l|--list)
        list_safeboxes
        ;;
    delete|-d|--delete)
        delete_safebox "$safebox_param"
        ;;
    export|-e|--export)
        export_safebox "$safebox_param" "$file_param"
        ;;
    import|-i|--import)
        import_safebox "$safebox_param" "$file_param"
        ;;
    version|-v|--version)
        show_version
        ;;
    help|-h|--help|"")
        show_help
        ;;
    *)
        error "Unknown command: $cmd"
        show_help
        exit 1
        ;;
esac

exit 0
