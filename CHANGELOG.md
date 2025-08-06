# CHANGELOG.md

This file tracks important changes and decisions made to the QemuMac codebase.

## 2025-01-06 - Interactive Boot Option Selection System
Added user-selectable boot options to Mac Library system with smart defaults based on software category. Operating Systems default to CD boot for installation, Games default to Mac boot with CD available on desktop. Users can override defaults with clear explanations. Implemented in both interactive menu and command line modes to give users control over installation vs application usage scenarios.

## 2025-01-06 - Enhanced Install Dependencies Support
Expanded install-dependencies.sh to support additional Linux distributions (SUSE/openSUSE, Arch Linux, Alpine Linux) and macOS package managers (MacPorts, Fink). Added missing QEMU build dependencies (libffi, gettext, meson) identified from official documentation. Enhanced macOS support with compiler detection and HVF acceleration recommendations.