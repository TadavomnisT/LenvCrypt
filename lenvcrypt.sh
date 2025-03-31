#!/bin/bash
# lenvcrypt.sh - Manage encrypted sandboxes with cryptsetup
# This script can create, open, close, list, delete sandboxes, and show help.
# Directories used: ./Sandboxes/ to store .img files, and ./Mountpoints/ to mount opened sandboxes.

# -----------------------
# Color definitions
# -----------------------
RED=$'\033[31m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
MAGENTA=$'\033[35m'
NC=$'\033[0m'  # No Color

# Message functions (only the tag is colored)
error()     { echo -e "[${RED}ERROR${NC}]: $1"; }
log_msg()   { echo -e "[${GREEN}LOG${NC}]: $1"; }
help_msg()  { echo -e "[${YELLOW}HELP${NC}]: $1"; }
warn()      { echo -e "[${MAGENTA}WARN${NC}]: $1"; }

# Directories
SANDBOX_DIR="./Sandboxes"
MOUNTPOINT_DIR="./Mountpoints"

# Ensure directories exist
mkdir -p "$SANDBOX_DIR" "$MOUNTPOINT_DIR"

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
    echo -e "#|                   X      ~      X                ###"
    echo -e "#|                   XXXXXXXXXXXXXXX"
    echo -e "#|"
    echo -e "#|                          ###################"
    echo -e "#|##########################/"
    echo -e "\033[0m"  # Reset to default color
    cat <<EOF
${MAGENTA}LenvCrypt:${NC} Encrypted Linux Environment. A secure, password-protected sandbox storage for GNU/Linux.

AUTHOR :            TadavomnisT (Behrad.B)}
Repo :              https://github.com/TadavomnisT/LenvCrypt
REPORTING BUGS :    https://github.com/TadavomnisT/LenvCrypt/issues
COPYRIGHT :
    Copyright (c) 2025   License GPLv3+
    This is free software: you are free to change and redistribute it.
    There is NO WARRANTY, to the extent permitted by law.

[${YELLOW}HELP${NC}]: Usage: $0 <command> [sandbox_name]

Commands:
  ${GREEN}create${NC}    => Create a new sandbox.
                   The script will prompt for a sandbox name and a size.
                   Example: $0 create
  ${GREEN}open${NC}      => Open an existing sandbox.
                   Example: $0 open mysandbox
  ${GREEN}close${NC}     => Close an opened sandbox.
                   Example: $0 close mysandbox
  ${GREEN}list${NC}      => List all existing sandboxes.
                   Example: $0 list
  ${GREEN}delete${NC}    => Delete an existing sandbox.
                   This will remove the .img file and associated mountpoint.
                   Example: $0 delete mysandbox
  ${GREEN}help, -h, --help${NC}
            => Display this help information.
EOF
}

# Create a new sandbox
create_sandbox() {
    read -p "Enter sandbox name: " sandbox_name
    if [[ -z "$sandbox_name" ]]; then
        error "Sandbox name cannot be empty."
        exit 1
    fi

    img_file="${SANDBOX_DIR}/${sandbox_name}.img"
    if [[ -f "$img_file" ]]; then
        error "Sandbox '$sandbox_name' already exists."
        exit 1
    fi

    echo "Choose sandbox size (in MB) from the following options or enter your own value:"
    for size in "${SIZES[@]}"; do
        echo "  - ${size}MB"
    done
    read -p "Size (MB): " sandbox_size

    if ! [[ "$sandbox_size" =~ ^[1-9][0-9]*$ ]]; then
        error "Invalid size. Please enter a positive integer."
        exit 1
    fi

    log_msg "Creating sandbox '$sandbox_name' of size ${sandbox_size}MB..."
    dd if=/dev/zero of="$img_file" bs=1M count="$sandbox_size" status=progress
    if [[ $? -ne 0 ]]; then
        error "Error creating disk image."
        exit 1
    fi

    log_msg "Formatting the disk image with LUKS..."
    sudo cryptsetup luksFormat "$img_file"
    if [[ $? -ne 0 ]]; then
        error "Error during luksFormat."
        exit 1
    fi

    sudo cryptsetup luksOpen "$img_file" "$sandbox_name"
    if [[ $? -ne 0 ]]; then
        error "Error opening the LUKS container."
        exit 1
    fi

    sudo mkfs.ext4 "/dev/mapper/${sandbox_name}" -q
    if [[ $? -ne 0 ]]; then
        error "Error creating ext4 filesystem."
        sudo cryptsetup luksClose "$sandbox_name"
        exit 1
    fi

    mkdir -p "${MOUNTPOINT_DIR}/${sandbox_name}"
    sudo cryptsetup luksClose "$sandbox_name"

    log_msg "Sandbox '$sandbox_name' successfully created."
    help_msg "To open it later, run: $0 open $sandbox_name"
}

# Open an existing sandbox
open_sandbox() {
    sandbox_name="$1"
    if [[ -z "$sandbox_name" ]]; then
        error "No sandbox name provided for open command."
        exit 1
    fi

    img_file="${SANDBOX_DIR}/${sandbox_name}.img"
    if [[ ! -f "$img_file" ]]; then
        error "Sandbox image '$img_file' does not exist."
        help_msg "You should create it first with: $0 create"
        exit 1
    fi

    log_msg "Opening sandbox '$sandbox_name'..."
    sudo cryptsetup luksOpen "$img_file" "$sandbox_name"
    if [[ $? -ne 0 ]]; then
        error "Error opening the LUKS container."
        exit 1
    fi

    mountpoint="${MOUNTPOINT_DIR}/${sandbox_name}"
    mkdir -p "$mountpoint"
    sudo mount "/dev/mapper/${sandbox_name}" "$mountpoint"
    if [[ $? -ne 0 ]]; then
        error "Error mounting the filesystem."
        sudo cryptsetup luksClose "$sandbox_name"
        exit 1
    fi

    log_msg "Sandbox '$sandbox_name' successfully opened and mounted at:"
    echo "  $mountpoint"
    help_msg "You can now access your sandbox files."
}

# Close an opened sandbox
close_sandbox() {
    sandbox_name="$1"
    if [[ -z "$sandbox_name" ]]; then
        error "No sandbox name provided for close command."
        exit 1
    fi

    mountpoint="${MOUNTPOINT_DIR}/${sandbox_name}"
    if mountpoint -q "$mountpoint"; then
        sudo umount "$mountpoint"
        if [[ $? -ne 0 ]]; then
            error "Could not unmount '$mountpoint'."
            exit 1
        fi
    else
        warn "'$mountpoint' is not mounted."
    fi

    sudo cryptsetup luksClose "$sandbox_name"
    if [[ $? -ne 0 ]]; then
        error "Could not close the LUKS container '$sandbox_name'."
        exit 1
    fi

    log_msg "Sandbox '$sandbox_name' has been closed."
}

# List all sandboxes (by listing .img files)
list_sandboxes() {
    echo "*** Listing available sandboxes in ${SANDBOX_DIR}:"
    shopt -s nullglob
    sandbox_found=0
    for file in "$SANDBOX_DIR"/*.img; do
        sandbox_found=1
        sandbox=$(basename "$file" .img)
        echo " - ${GREEN}$sandbox${NC}"
    done
    if [[ $sandbox_found -eq 0 ]]; then
        warn "No sandboxes found."
    fi
}

# Delete a sandbox: prompt confirmation, unmount/close if needed, and remove files.
delete_sandbox() {
    sandbox_name="$1"
    if [[ -z "$sandbox_name" ]]; then
        error "No sandbox name provided for delete command."
        exit 1
    fi

    img_file="${SANDBOX_DIR}/${sandbox_name}.img"
    mountpoint="${MOUNTPOINT_DIR}/${sandbox_name}"

    if [[ ! -f "$img_file" ]]; then
        error "Sandbox image '${img_file}' does not exist."
        exit 1
    fi

    warn "Are you sure you want to permanently delete sandbox '$sandbox_name'?"
    read -p "Type 'yes' to confirm: " confirm
    if [[ "$confirm" != "yes" ]]; then
        log_msg "Deletion cancelled."
        exit 0
    fi

    if mountpoint -q "$mountpoint"; then
        log_msg "Unmounting sandbox from '$mountpoint'..."
        sudo umount "$mountpoint"
        if [[ $? -ne 0 ]]; then
            error "Could not unmount '$mountpoint'. Aborting deletion."
            exit 1
        fi
    fi

    if sudo cryptsetup status "$sandbox_name" >/dev/null 2>&1; then
        log_msg "Closing open LUKS container for '$sandbox_name'..."
        sudo cryptsetup luksClose "$sandbox_name"
        if [[ $? -ne 0 ]]; then
            error "Could not close the LUKS container '$sandbox_name'. Aborting deletion."
            exit 1
        fi
    fi

    log_msg "Deleting sandbox image '$img_file'..."
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

    log_msg "Sandbox '$sandbox_name' has been permanently deleted."
}

######################################################################
# Main script execution
######################################################################
check_cryptsetup

cmd="$1"
sandbox_param="$2"

case "$cmd" in
    create)
        create_sandbox
        ;;
    open)
        open_sandbox "$sandbox_param"
        ;;
    close)
        close_sandbox "$sandbox_param"
        ;;
    list)
        list_sandboxes
        ;;
    delete)
        delete_sandbox "$sandbox_param"
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
