# Personal interactive preferences; Home Manager supplies plugins and tool hooks.
setopt INTERACTIVE_COMMENTS

# Select completion candidates from a menu and match names regardless of case.
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
