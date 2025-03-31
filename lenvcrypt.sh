#!/bin/bash
# lenvcrypt.sh - Manage encrypted sandboxes with cryptsetup
# This script can create, open, close, list, delete sandboxes, and show help.
# Directories used: ./Sandboxes/ to store .img files, and ./Mountpoints/ to mount opened sandboxes.

# Directories
SANDBOX_DIR="./Sandboxes"
MOUNTPOINT_DIR="./Mountpoints"

# Ensure directories exist
mkdir -p "$SANDBOX_DIR" "$MOUNTPOINT_DIR"

# Default sizes (in MB)
SIZES=(100 200 500 1024)

# Check if cryptsetup exists (cross-platform tip: we try to detect package managers)
check_cryptsetup() {
    if ! command -v cryptsetup >/dev/null 2>&1 ; then
        echo "Error: cryptsetup is not installed on this system."
        echo "Please install cryptsetup with your package manager."
        # Try to give hints based on known package managers
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
    cat <<EOF
Usage: $0 <command> [sandbox_name]

Commands:
  create    => Create a new sandbox.
              The script will prompt for a sandbox name and a size.
              Example: $0 create
  open      => Open an existing sandbox.
              Example: $0 open mysandbox
  close     => Close an opened sandbox.
              Example: $0 close mysandbox
  list      => List all existing sandboxes.
              Example: $0 list
  delete    => Delete an existing sandbox.
              This will remove the .img file and associated mountpoint.
              Example: $0 delete mysandbox
  help, -h, --help
              => Display this help information.

EOF
}

# Create a new sandbox
create_sandbox() {
    # Prompt for sandbox name
    read -p "Enter sandbox name: " sandbox_name
    if [[ -z "$sandbox_name" ]]; then
        echo "Sandbox name cannot be empty."
        exit 1
    fi

    img_file="${SANDBOX_DIR}/${sandbox_name}.img"
    if [[ -f "$img_file" ]]; then
        echo "Error: Sandbox '$sandbox_name' already exists."
        exit 1
    fi

    echo "Choose sandbox size (in MB) from the following options or enter your own value:"
    for size in "${SIZES[@]}"; do
        echo "  - ${size}MB"
    done
    echo "Enter sandbox size in MB (must be a positive integer):"
    read -p "Size (MB): " sandbox_size

    # Validate input: must be a positive integer greater or equal to 1.
    if ! [[ "$sandbox_size" =~ ^[1-9][0-9]*$ ]]; then
        echo "Invalid size. Please enter a positive integer."
        exit 1
    fi

    echo "Creating sandbox '$sandbox_name' of size ${sandbox_size}MB..."
    # Create file using dd
    dd if=/dev/zero of="$img_file" bs=1M count="$sandbox_size" status=progress
    if [[ $? -ne 0 ]]; then
        echo "Error creating disk image."
        exit 1
    fi

    # Format with LUKS
    echo "Formatting the disk image with LUKS..."
    # Note: This will ask for a passphrase interactively.
    sudo cryptsetup luksFormat "$img_file"
    if [[ $? -ne 0 ]]; then
        echo "Error during luksFormat."
        exit 1
    fi

    # Open LUKS container
    sudo cryptsetup luksOpen "$img_file" "$sandbox_name"
    if [[ $? -ne 0 ]]; then
        echo "Error opening the luks container."
        exit 1
    fi

    # Create filesystem
    sudo mkfs.ext4 "/dev/mapper/${sandbox_name}" -q
    if [[ $? -ne 0 ]]; then
        echo "Error creating ext4 filesystem."
        sudo cryptsetup luksClose "$sandbox_name"
        exit 1
    fi

    # Create mountpoint directory for potential future use
    mkdir -p "${MOUNTPOINT_DIR}/${sandbox_name}"

    # Close the LUKS container
    sudo cryptsetup luksClose "$sandbox_name"

    echo "Sandbox '$sandbox_name' successfully created."
    echo "To open it later, run: $0 open $sandbox_name"
}

# Open an existing sandbox
open_sandbox() {
    sandbox_name="$1"
    if [[ -z "$sandbox_name" ]]; then
        echo "Error: No sandbox name provided for open command."
        exit 1
    fi

    img_file="${SANDBOX_DIR}/${sandbox_name}.img"
    if [[ ! -f "$img_file" ]]; then
        echo "Error: Sandbox image '$img_file' does not exist."
        echo "You should create it first with: $0 create"
        exit 1
    fi

    echo "Opening sandbox '$sandbox_name'..."
    # Open LUKS container and mount
    sudo cryptsetup luksOpen "$img_file" "$sandbox_name"
    if [[ $? -ne 0 ]]; then
        echo "Error opening the luks container."
        exit 1
    fi

    mountpoint="${MOUNTPOINT_DIR}/${sandbox_name}"
    mkdir -p "$mountpoint"
    sudo mount "/dev/mapper/${sandbox_name}" "$mountpoint"
    if [[ $? -ne 0 ]]; then
        echo "Error mounting the filesystem."
        sudo cryptsetup luksClose "$sandbox_name"
        exit 1
    fi

    echo "Sandbox '$sandbox_name' successfully opened and mounted at:"
    echo "  $mountpoint"
    echo "You can now access your sandbox files."
}

# Close an opened sandbox
close_sandbox() {
    sandbox_name="$1"
    if [[ -z "$sandbox_name" ]]; then
        echo "Error: No sandbox name provided for close command."
        exit 1
    fi

    mountpoint="${MOUNTPOINT_DIR}/${sandbox_name}"
    if mountpoint -q "$mountpoint"; then
        sudo umount "$mountpoint"
        if [[ $? -ne 0 ]]; then
            echo "Error: Could not unmount '$mountpoint'."
            exit 1
        fi
    else
        echo "Warning: '$mountpoint' is not mounted."
    fi

    sudo cryptsetup luksClose "$sandbox_name"
    if [[ $? -ne 0 ]]; then
        echo "Error: Could not close the LUKS container '$sandbox_name'."
        exit 1
    fi

    echo "Sandbox '$sandbox_name' has been closed."
}

# List all sandboxes (by listing .img files)
list_sandboxes() {
    echo "Listing available sandboxes in ${SANDBOX_DIR}:"
    shopt -s nullglob
    sandbox_found=0
    for file in "$SANDBOX_DIR"/*.img; do
        sandbox_found=1
        sandbox=$(basename "$file" .img)
        echo " - $sandbox"
    done
    if [[ $sandbox_found -eq 0 ]]; then
        echo "No sandboxes found."
    fi
}

# Delete a sandbox: prompt confirmation, unmount/close if needed, and remove files.
delete_sandbox() {
    sandbox_name="$1"
    if [[ -z "$sandbox_name" ]]; then
        echo "Error: No sandbox name provided for delete command."
        exit 1
    fi

    img_file="${SANDBOX_DIR}/${sandbox_name}.img"
    mountpoint="${MOUNTPOINT_DIR}/${sandbox_name}"

    if [[ ! -f "$img_file" ]]; then
        echo "Error: Sandbox image '${img_file}' does not exist."
        exit 1
    fi

    echo "Are you sure you want to permanently delete sandbox '$sandbox_name'?"
    read -p "Type 'yes' to confirm: " confirm
    if [[ "$confirm" != "yes" ]]; then
        echo "Deletion cancelled."
        exit 0
    fi

    # Check if sandbox is mounted, and if so, attempt to unmount and close.
    if mountpoint -q "$mountpoint"; then
        echo "Unmounting sandbox from '$mountpoint'..."
        sudo umount "$mountpoint"
        if [[ $? -ne 0 ]]; then
            echo "Error: Could not unmount '$mountpoint'. Aborting deletion."
            exit 1
        fi
    fi

    # Close LUKS container if open.
    if sudo cryptsetup status "$sandbox_name" >/dev/null 2>&1; then
        echo "Closing open LUKS container for '$sandbox_name'..."
        sudo cryptsetup luksClose "$sandbox_name"
        if [[ $? -ne 0 ]]; then
            echo "Error: Could not close the LUKS container '$sandbox_name'. Aborting deletion."
            exit 1
        fi
    fi

    # Remove sandbox image file
    echo "Deleting sandbox image '$img_file'..."
    rm -f "$img_file"
    if [[ $? -ne 0 ]]; then
        echo "Error deleting '$img_file'."
        exit 1
    fi

    # Remove mountpoint directory if it exists and is empty
    if [[ -d "$mountpoint" ]]; then
        echo "Removing mountpoint directory '$mountpoint'..."
        rmdir "$mountpoint" 2>/dev/null
        if [[ $? -ne 0 ]]; then
            echo "Warning: Could not remove mountpoint directory. It may not be empty."
        fi
    fi

    echo "Sandbox '$sandbox_name' has been permanently deleted."
}

######################################################################
# Main script execution
######################################################################
# Check cryptsetup first
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
        echo "Unknown command: $cmd"
        show_help
        exit 1
        ;;
esac

exit 0
