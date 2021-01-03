#!/bin/bash

# setup.sh is used to configure a machine for development.
# This can be used on a macOS or Linux machine, the script
# will automatically detect its environment and configure
# the system appropriately.

# Detect the machine type.
uname=`uname -s`
case "${uname}" in
    Linux*)  machine=linux;;
    Darwin*) machine=macos;;
    *)       echo "Unsupported machine."; exit;;
esac
echo "Detected machine type: $machine."

# If we are on macOS, we need to make sure developer tools
# and Homebrew are installed, as this will be required for
# the rest of the script to work properly.
if [[ $machine == "macos" ]] && [[ $(command -v brew) == "" ]]; then
    echo "Detected missing Homebrew, installing..."
    
    # If we are missing command line tools, install it.
    if type xcode-select >&- && xpath=$( xcode-select --print-path ) && test -d "${xpath}" && test -x "${xpath}" ; then
        echo "Apple command line tools already installed, skipping."
    else
        echo "Missing command line tools, installing..."
        xcode-select --install
    fi

    # Now we can instal Homebrew.
    ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

else
    # Just do a basic update if we've already installed Homebrew.
    echo "Updating Homebrew..."
    brew update
fi

# Install the core tooling.
if [[ $machine == "macos" ]]; then
    
    # Smart brew install / upgrade.
    smart_brew () {
        HOMEBREW_NO_AUTO_UPDATE=1 brew `brew ls --versions "$1" | wc -l | xargs expr | sed 's/0/install/' | sed 's/1/upgrade/'` "$1"
    }

    smart_brew vim
    smart_brew grep
    smart_brew git
    smart_brew git-lfs
    smart_brew tree
    smart_brew hexyl
    smart_brew ssh-copy-id
    smart_brew go
    smart_brew cloudflare/cloudflare/cloudflared
    smart_brew sqlc
    smart_brew protobuf
    smart_brew clang-format
    brew cleanup
else
    sudo yum install vim -y
    sudo yum install git -y
    sudo yum install git-lfs -y
    sudo yum install tree -y
    sudo yum install golang -y
fi
echo "Finished core tooling installation."

# If we are on macOS, we need to do some additional setup for Go.
if [[ $machine == "macos" ]]; then
    echo "export GOROOT=/usr/local/go" >> ~/.zshrc
    echo "export GOPATH=\$HOME/go" >> ~/.zshrc
    echo "export PATH=\$PATH:\$GOROOT/bin:\$GOPATH/bin" >> ~/.zshrc
    source ~/.zshrc
fi

# If we are on linux and we are root, check if the `mg` user exists.
# If it doesn't, create the user and switch to it.
if [[ $machine == "linux" ]] && [[ "$EUID" ==  "0" ]]; then
    # Make sure the `mg` user exists.
    if id -u "mg" >/dev/null 2>&1; then
        echo "User mg already exists."
    else
        echo "Missing user mg, creating..."
        adduser mg
        passwd mg
        usermod -aG wheel mg
        echo "Created user mg successfully."
    fi

    # Switch to the user.
    su - mg
fi

# From this point on, we are assuming that both linux and macOS machines
# are running in non-root mode. This was already true for macOS, but it
# is also now true for linux since if we we're root, we switched to the
# `mg` user. One thing to note that we are not necessarily on the `mg` user
# when we are on macOS.

# If we are on linux, we need to do some additional setup to allow for SSH.
if [[ $machine == "linux" ]]; then
    echo "Configuring SSH..."
    
    # Generate a new SSH key for this machine, if missing.
    count=`ls -1 ~/.ssh/*.pub 2>/dev/null | wc -l`
    if [[ "$count" == "0" ]]; then
        echo "Detected missing ssh key, making a new one..."
        ssh-keygen -t ed25519 -C "morgan@morgangallant.com"
        eval "$(ssh-agent -s)"
        ssh-add ~/.ssh/id_ed25519
    fi

    # Configure the set of authorized keys.
    mkdir -p ~/.ssh
    cp authorized_keys ~/.ssh/authorized_keys
    echo "Copied over authorized keys"
fi

# Generic dotfile copies.
cp vimrc ~/.vimrc
echo "Finished copying over dotfiles."


# If we are on linux, before the script ends, print out our public key.
# This is useful when configuring GitHub or something.
if [[ $machine == "linux" ]]; then
    echo "Printing public key..."
    cat ~/.ssh/id_ed25519.pub
fi
