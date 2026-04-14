# Makefile

# Define the packages to install
PACKAGES := neovim zsh git stow helix wofi fontawesome-fonts-all

# Function to detect the Linux distribution
detect_distro = $(shell \
	if [ -f /etc/os-release ]; then \
		. /etc/os-release; echo $$ID; \
	elif [ -f /etc/lsb-release ]; then \
		. /etc/lsb-release; echo $$DISTRIB_ID; \
	elif [ -f /etc/debian_version ]; then \
		echo "debian"; \
	elif [ -f /etc/redhat-release ]; then \
		echo "rhel"; \
	else \
		echo "unknown"; \
	fi)

# Assign package manager based on detected distro
DISTRO := $(call detect_distro)

ifeq ($(DISTRO),ubuntu)
	PACKAGE_MANAGER := apt
endif
ifeq ($(DISTRO),debian)
	PACKAGE_MANAGER := apt
endif
ifeq ($(DISTRO),fedora)
	PACKAGE_MANAGER := dnf
endif
ifeq ($(DISTRO),rhel)
	PACKAGE_MANAGER := yum
endif
ifeq ($(DISTRO),centos)
	PACKAGE_MANAGER := yum
endif
ifeq ($(DISTRO),arch)
	PACKAGE_MANAGER := pacman -S
endif
ifeq ($(DISTRO),opensuse)
	PACKAGE_MANAGER := zypper
endif

# Fallback for unknown distributions
PACKAGE_MANAGER ?= echo "Unsupported distribution: $(DISTRO)"; exit 1

INSTALL_CMD := sudo $(PACKAGE_MANAGER) install -y
UPDATE_CMD := sudo $(PACKAGE_MANAGER) update
UPGRADE_CMD := sudo $(PACKAGE_MANAGER) upgrade -y

.PHONY: all update upgrade install

# Default target to update, upgrade and install packages
all: update upgrade install

# Update package list
update:
	$(UPDATE_CMD)

# Upgrade all packages
upgrade:
	$(UPGRADE_CMD)

# Install the specified packages
install:
	$(INSTALL_CMD) $(PACKAGES)

clean-nvim:
	rm -rf ~/.local/share/nvim ~/.local/state/nvim ~/.cache/nvim

install-fonts:
	sudo mkdir -p /usr/local/share/fonts/
	sudo cp -r ./assets/fonts/* /usr/local/share/fonts/
	sudo fc-cache -v

swaylist:
	swaymsg -t get_tree | jq -c '.nodes[].nodes[].nodes[] | {id, app_id, name}'\n
