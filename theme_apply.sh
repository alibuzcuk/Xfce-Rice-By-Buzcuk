#!/bin/bash

# =========================================================
# XFCE THEME AND ICON INSTALLATION SCRIPT
# This script sets up the theme, icons, and dock configuration in the Xfce desktop environment.
# =========================================================

# --- Configuration Variables ---
THEME_DIR="./General Theme"
ICON_DIR="./Icons"
PLANK_THEME_DIR="./Plank_Theme/Catalinas_Style_Taru"
WALLPAPER_FILE="./Wallpapers/custom-wallpaper.jpg"

GTK_THEME="Sweet-Ambar-Blue-Dark-v40"
ICON_THEME="candy-icons"
PLANK_THEME_NAME="Catalinas_Style_Taru"

# Fastfetch Config Variables
FASTFETCH_CONFIG_DIR="$HOME/.config/fastfetch"
FASTFETCH_CONFIG_1="./config.jsonc"
FASTFETCH_CONFIG_2="./buzcuk.txt"

# Icon Theme Paths (This path is where icons are installed in step 4)
ICON_THEME_APPS_PATH="$HOME/.icons/$ICON_THEME/apps/scalable"

# Starship configuration file path
STARSHIP_CONFIG_PATH="$HOME/.config/starship.toml"


# Function for colored output
cecho() {
    local color=$1
    local text=$2
    case "$color" in
        "red")    echo -e "\033[31m$text\033[0m";;
        "green")  echo -e "\033[32m$text\033[0m";;
        "yellow") echo -e "\033[33m$text\033[0m";;
        *)        echo "$text";;
    esac
}

# Function to determine the icon name based on distro ID
get_distro_icon_name() {
    local distro_id=$1
    # Standardize IDs based on icon pack conventions (distributor-logo-xxx.png)
    case "$distro_id" in
        linuxmint)
            # Linux Mint often uses 'linuxmint' ID
            echo "distributor-logo-linuxmint.png"
            ;;
        kali|antix|archlabs|artix|arch|manjaro|debian|ubuntu|pop)
            # These IDs directly match the common file naming convention: distributor-logo-ID.png
            echo "distributor-logo-$distro_id.png"
            ;;
        *)
            # Fallback for other distributions
            echo "distributor-logo-$distro_id.png"
            ;;
    esac
}

# Check if xfconf-query tool is installed
if ! command -v xfconf-query &> /dev/null; then
    cecho "red" "ERROR: xfconf-query tool not found. This tool is required for Xfce settings."
    exit 1
fi

# --- 1. Distribution Check ---
cecho "yellow" "### 1. Checking Distribution..."
PKG_MGR=""
DISTRO=""
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
    case "$DISTRO" in
        debian|ubuntu|pop|mint|kali|antix)
            PKG_MGR="apt"
            cecho "green" "Distribution Detected: $NAME ($PKG_MGR)"
            ;;
        fedora|centos|rhel)
            PKG_MGR="dnf"
            cecho "green" "Distribution Detected: $NAME ($PKG_MGR)"
            ;;
        arch|manjaro|archlabs|artix)
            PKG_MGR="pacman"
            cecho "green" "Distribution Detected: $NAME ($PKG_MGR)"
            ;;
        *)
            cecho "yellow" "Distribution Detected: $NAME. Unsupported package manager. Plank may need to be installed manually."
            ;;
    esac
else
    cecho "red" "WARNING: Distribution could not be determined. Automatic package manager cannot be used for Plank installation."
fi

# --- 2. Copying GTK Theme to Xfce Theme Folder ---
cecho "yellow" "### 2. Copying GTK Theme..."
if [ -d "$THEME_DIR" ]; then
    mkdir -p "$HOME/.themes"
    cp -r "$THEME_DIR"/* "$HOME/.themes/"
    cecho "green" "GTK themes copied to ($HOME/.themes) folder."
else
    cecho "red" "ERROR: GTK theme directory '$THEME_DIR' not found. Theme copying skipped."
fi

# --- 3. Applying General Theme ---
cecho "yellow" "### 3. Applying General GTK Theme: $GTK_THEME"
xfconf-query -c xsettings -p /Net/ThemeName -s "$GTK_THEME" --create -t string 
xfconf-query -c xfwm4 -p /general/theme -s "$GTK_THEME" --create -t string
cecho "green" "GTK Theme set successfully."

# --- 4. Copying Icons to Xfce Icon Folder ---
cecho "yellow" "### 4. Copying Icon Theme..."
if [ -d "$ICON_DIR" ]; then
    mkdir -p "$HOME/.icons"
    cp -r "$ICON_DIR"/* "$HOME/.icons/"
    cecho "green" "Icon themes copied to ($HOME/.icons) folder."
else
    cecho "red" "ERROR: Icon theme directory '$ICON_DIR' not found. Icon copying skipped."
fi

# --- 5. Applying Icon Theme ---
cecho "yellow" "### 5. Applying Icon Theme: $ICON_THEME"
xfconf-query -c xsettings -p /Net/IconThemeName -s "$ICON_THEME" --create -t string
cecho "green" "Icon Theme set successfully."

# --- 6. Applying Distribution Icon to Start Menu (Whisker Menu) ---
cecho "yellow" "### 6. Checking and Applying Distribution Icon (Whisker Menu)..."

DISTRO_ICON_FILENAME=$(get_distro_icon_name "$DISTRO")
ICON_FULL_PATH="$ICON_THEME_APPS_PATH/$DISTRO_ICON_FILENAME"

# Check if the icon file exists *inside* the installed icon theme directory
if [ -f "$ICON_FULL_PATH" ]; then
    
    # Find Whisker Menu plugin ID
    WHISKER_MENU_ID=$(xfconf-query -c xfce4-panel -p /plugins -l | grep 'whiskermenu' | head -n 1 | sed 's/.*\///')
    
    if [ ! -z "$WHISKER_MENU_ID" ]; then
        # Apply icon using its full path inside the installed icon theme
        xfconf-query -c xfce4-panel -p "/plugins/$WHISKER_MENU_ID/button-icon" -s "$ICON_FULL_PATH" --create -t string
        cecho "green" "Whisker Menu icon set successfully using theme file: $DISTRO_ICON_FILENAME"
    else
        cecho "yellow" "WARNING: Whisker Menu plugin not found in configuration. You may need to set the icon manually."
    fi
else
    cecho "red" "ERROR: Distribution icon file ('$DISTRO_ICON_FILENAME') not found in the icon theme's 'apps/scalable' folder. Skipping."
fi


# --- 8. Plank Dock Installation/Theme Settings ---
cecho "yellow" "### 8. Plank Dock Installation/Theme Settings..."

PLANK_SETUP() {
    cecho "yellow" "### Applying Plank Dock Settings..."
    if [ -d "$PLANK_THEME_DIR" ]; then
        # Copy Plank theme
        PLANK_DEST="$HOME/.local/share/plank/themes"
        mkdir -p "$PLANK_DEST"
        cp -r "$PLANK_THEME_DIR" "$PLANK_DEST/"
        
        # Apply Plank theme (uses gsettings)
        if command -v gsettings &> /dev/null; then
            gsettings set net.launchpad.plank.dock.settings:/net/launchpad/plank/docks/dock1/ theme "$PLANK_THEME_NAME"
            cecho "green" "Plank theme applied as '$PLANK_THEME_NAME'."
        else
            cecho "red" "ERROR: 'gsettings' not found. You may need to set the Plank theme manually."
        fi
    else
        cecho "red" "ERROR: Plank theme file '$PLANK_THEME_DIR' not found. Skipping theme application."
    fi
}

# Ask user about Plank setup
read -r -p "Do you want to install Plank Dock (or apply its theme)? (y/n): " DO_PLANK_SETUP

if [[ "$DO_PLANK_SETUP" =~ ^[Yy]$ ]]; then
    
    if command -v plank &> /dev/null; then
        cecho "green" "Plank found installed. Applying theme..."
        PLANK_SETUP
    else
        # If Plank is not installed, try to install it
        cecho "yellow" "Plank is not installed."
        if [[ "$PKG_MGR" != "" ]]; then
            cecho "yellow" "Installing Plank. Please enter your password..."
            
            INSTALL_COMMAND=""
            if [ "$PKG_MGR" == "pacman" ]; then
                INSTALL_COMMAND="sudo pacman -S plank --noconfirm" # Using --noconfirm for Arch
            elif [ "$PKG_MGR" == "apt" ] || [ "$PKG_MGR" == "dnf" ]; then
                INSTALL_COMMAND="sudo $PKG_MGR install plank -y" # For Debian/Ubuntu/Fedora
            fi
            
            if [ -n "$INSTALL_COMMAND" ]; then
                if $INSTALL_COMMAND; then
                    cecho "green" "Plank installed successfully. Applying theme..."
                    PLANK_SETUP
                else
                    cecho "red" "ERROR: Plank installation failed. Theme cannot be applied."
                fi
            else
                cecho "red" "ERROR: Unsupported package manager. Skipping Plank installation."
            fi
        else
            cecho "red" "WARNING: Automatic package manager not found. Skipping Plank installation and theme."
        fi
    fi
else
    cecho "yellow" "Plank installation and theme settings skipped."
fi

# --- 9. Setting Desktop Background ---
cecho "yellow" "### 9. Setting Desktop Background..."

if [ -f "$WALLPAPER_FILE" ]; then
    WALLPAPER_DEST="$HOME/.local/share/backgrounds/custom_wallpaper.jpg"
    
    # Copy wallpaper file
    mkdir -p "$(dirname "$WALLPAPER_DEST")"
    
    # Ask for sudo permission for copying as requested
    read -r -p "Do you want to copy the wallpaper file system-wide (with sudo)? (y/n - 'n' is usually sufficient): " SUDO_REQ
    if [[ "$SUDO_REQ" =~ ^[Yy]$ ]]; then
        cecho "yellow" "Copying using sudo privileges..."
        sudo cp "$WALLPAPER_FILE" "$WALLPAPER_DEST"
    else
        cp "$WALLPAPER_FILE" "$WALLPAPER_DEST"
    fi
    
    # Set Xfce background setting
    # last-image: Path to the wallpaper image
    xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/last-image -s "$WALLPAPER_DEST" --create -t string
    # image-style: 5 = Zoom
    xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/image-style -s 5 --create -t int
    
    cecho "green" "Background set to '$WALLPAPER_DEST'."
else
    cecho "red" "ERROR: Wallpaper file ('$WALLPAPER_FILE') not found. Skipping."
fi

# --- 10. Fastfetch Installation and Configuration ---
cecho "yellow" "### 10. Fastfetch Installation and Configuration..."

FASTFETCH_CONFIG_SETUP() {
    cecho "yellow" "### Copying Fastfetch Configuration Files..."
    
    # Check if config files exist in the script's directory
    if [ -f "$FASTFETCH_CONFIG_1" ] && [ -f "$FASTFETCH_CONFIG_2" ]; then
        mkdir -p "$FASTFETCH_CONFIG_DIR"
        cp "$FASTFETCH_CONFIG_1" "$FASTFETCH_CONFIG_DIR/"
        cp "$FASTFETCH_CONFIG_2" "$FASTFETCH_CONFIG_DIR/"
        cecho "green" "Fastfetch configuration files copied to '$FASTFETCH_CONFIG_DIR'."
    else
        cecho "red" "ERROR: One or both Fastfetch config files ('$FASTFETCH_CONFIG_1', '$FASTFETCH_CONFIG_2') not found. Skipping config copying."
    fi
}

# Ask user about Fastfetch setup
read -r -p "Do you want to install Fastfetch and copy configuration files? (y/n): " DO_FASTFETCH_SETUP

if [[ "$DO_FASTFETCH_SETUP" =~ ^[Yy]$ ]]; then
    
    if command -v fastfetch &> /dev/null; then
        cecho "green" "Fastfetch found installed. Skipping installation and proceeding to configuration..."
        FASTFETCH_CONFIG_SETUP
    else
        # If Fastfetch is not installed, try to install it
        cecho "yellow" "Fastfetch is not installed."
        if [[ "$PKG_MGR" != "" ]]; then
            cecho "yellow" "Installing Fastfetch. Please enter your password if prompted..."
            
            INSTALL_COMMAND=""
            if [ "$PKG_MGR" == "pacman" ]; then
                INSTALL_COMMAND="sudo pacman -S fastfetch --noconfirm"
            elif [ "$PKG_MGR" == "apt" ] || [ "$PKG_MGR" == "dnf" ]; then
                INSTALL_COMMAND="sudo $PKG_MGR install fastfetch -y"
            fi
            
            if [ -n "$INSTALL_COMMAND" ]; then
                if $INSTALL_COMMAND; then
                    cecho "green" "Fastfetch installed successfully. Applying configuration..."
                    FASTFETCH_CONFIG_SETUP
                else
                    cecho "red" "ERROR: Fastfetch installation failed. Skipping configuration."
                fi
            else
                cecho "red" "ERROR: Unsupported package manager. Skipping Fastfetch installation and configuration."
            fi
        else
            cecho "red" "WARNING: Automatic package manager not found. Skipping Fastfetch installation and configuration."
        fi
    fi
else
    cecho "yellow" "Fastfetch installation and configuration skipped."
fi

# --- 11. Starship Installation and Configuration ---
cecho "yellow" "### 11. Starship Installation and Configuration (Terminal Prompt)..."

STARSHIP_CONFIG_SETUP() {
    cecho "yellow" "### Configuring Starship for Bash..."
    
    # Check if the starship init command already exists in .bashrc
    if grep -q 'starship init bash' "$HOME/.bashrc"; then
        cecho "yellow" "Starship initialization command already exists in .bashrc. Skipping."
    else
        # Append Starship initialization to .bashrc
        echo '' >> "$HOME/.bashrc"
        echo '# --- Starship Prompt Initialization ---' >> "$HOME/.bashrc"
        echo 'eval "$(starship init bash)"' >> "$HOME/.bashrc"
        cecho "green" "Starship initialization added to $HOME/.bashrc. Please source it or restart your terminal."
    fi
    
    # Create an empty starship.toml file if it doesn't exist (user can customize later)
    if [ ! -f "$STARSHIP_CONFIG_PATH" ]; then
        touch "$STARSHIP_CONFIG_PATH"
        cecho "green" "Empty starship configuration file created at $STARSHIP_CONFIG_PATH."
    fi
}

# Ask user about Starship setup
read -r -p "Do you want to install Starship (Terminal Prompt)? (y/n): " DO_STARSHIP_SETUP

if [[ "$DO_STARSHIP_SETUP" =~ ^[Yy]$ ]]; then
    
    if command -v starship &> /dev/null; then
        cecho "green" "Starship found installed. Skipping installation and proceeding to configuration..."
        STARSHIP_CONFIG_SETUP
    else
        # If Starship is not installed, try to install it using curl (common cross-distro method)
        cecho "yellow" "Starship is not installed. Attempting installation via recommended method (curl)..."
        
        if command -v curl &> /dev/null; then
            if curl -sS https://starship.rs/install.sh | sh; then
                cecho "green" "Starship installed successfully. Applying configuration..."
                STARSHIP_CONFIG_SETUP
            else
                cecho "red" "ERROR: Starship installation via curl failed. Skipping configuration."
            fi
        else
            cecho "red" "ERROR: curl is not installed. Cannot proceed with Starship installation. Skipping configuration."
        fi
    fi
else
    cecho "yellow" "Starship installation and configuration skipped."
fi

# --- End Message ---
cecho "green" "\n==============================================="
cecho "green" "Installation Complete!"
cecho "green" "It is recommended to log out and log back into your Xfce session for settings to take full effect."
cecho "green" "If you installed Starship, run 'source ~/.bashrc' in your terminal or restart it."
cecho "green" "==============================================="
