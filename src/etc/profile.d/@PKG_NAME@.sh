


# Ensure base distro defaults xdg path are set if nothing filed up some
# defaults yet.
if [ -z "$XDG_DATA_DIRS" ]; then
    export XDG_DATA_DIRS="/usr/local/share:/usr/share"
fi

# Desktop files (used by desktop environments within both X11 and Wayland) are
# looked for in XDG_DATA_DIRS; make sure it includes the relevant directory for ACE
ACE_path="/opt/apps/@PKG_NAME@/files/ace-env/amber-ce-tools/data-dir/"
if [ -n "${XDG_DATA_DIRS##*${ACE_path}}" ] && [ -n "${XDG_DATA_DIRS##*${ACE_path}:*}" ]; then
    export XDG_DATA_DIRS="${XDG_DATA_DIRS}:${ACE_path}"
fi

