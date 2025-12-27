# License: same terms as Bash / Bourne-Again SHell
# Minimal /system/etc/bash.bashrc for Tengrux

# Disable nohup-like behavior
set +o huponexit 2>/dev/null

# Set prompt symbol depending on user ID
if [[ $EUID -ne 0 ]]; then
    PS_SYMBOL="$"
else
    PS_SYMBOL="#"
fi

# PS4: show timestamp for debugging (bash-compatible)
export PS4='[${EPOCHREALTIME}] '

# Dynamic PS1: show last exit code only if non-zero
__bash_prompt() {
    local ec=$?
    local out=""
    if [[ $ec -ne 0 ]]; then
        out="${ec}|"
    fi
    printf "%s%s:%s %s " "$out" "$HOSTNAME" "${PWD:-?}" "$PS_SYMBOL"
}

export PS1="$(__bash_prompt)"


