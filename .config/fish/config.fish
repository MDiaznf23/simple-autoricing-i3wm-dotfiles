fastfetch
if status is-interactive
    # Commands to run in interactive sessions can go here
end

# Restore pywal colors untuk Alacritty
if command -v wal > /dev/null 2>&1; and test "$TERM" = "alacritty"
   wal -Rqe
end

set fish_greeting
set -x LANG en_US.UTF-8
set -x LC_ALL en_US.UTF-8
set -gx PATH $HOME/.local/bin $PATH
set -gx MOZ_DISABLE_RDD_SANDBOX 1
fish_add_path ~/.local/bin
fish_add_path ~/.local/bin
cat ~/.cache/wal/sequences &
