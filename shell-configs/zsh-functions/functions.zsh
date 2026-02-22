# Portable ZSH functions
# Sourced from claude-plugins/shell-configs/zsh-functions/

function ss() {
    local f="/tmp/ss-${RANDOM}${RANDOM}.png"
    pngpaste "$f" && {
      echo -n "$f" | pbcopy
      echo "Saved & copied: $f"
    }
}
