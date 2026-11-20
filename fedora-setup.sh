#!/usr/bin/env bash
# =============================================================================
#  fedora-setup.sh — Entorno de desarrollo + configuración visual para Fedora
#  Generado el 2026-11-20 desde Fedora Linux 45 (KDE Plasma Desktop Edition), plasmashell 6.8.2, GNOME Shell 51.1
#
#  Incluye: apps de desarrollo, kitty, zsh/oh-my-zsh/p10k/starship, VS Code,
#           LaTeX (TeX Live medium), apariencia de KDE Plasma (temas,
#           widgets, paneles, atajos) y de GNOME (extensiones, dconf).
#  NO incluye: identidad de git, drivers (NVIDIA/firmware), herramientas de
#           seguridad, fondos ni archivos personales.
#
#  Uso:
#    ./fedora-setup.sh                   # todo
#    ./fedora-setup.sh --dry-run         # muestra lo que haría
#    ./fedora-setup.sh --only dotfiles   # solo una sección
#    ./fedora-setup.sh --skip gnome,dev
#    ./fedora-setup.sh --with latexfull  # añade LaTeX completo (~5 GB)
#
#  Secciones: system repos packages flatpak shell dotfiles dev vscode latex kde gnome
#  Opcionales: latexfull
#  KDE: temas, iconos y widgets se leen de kde-assets.tar.gz (junto al script).
#  No ejecutar como root: usa sudo cuando hace falta.
# =============================================================================
set -uo pipefail

SECTIONS=(system repos packages flatpak shell dotfiles dev vscode latex kde gnome latexfull)
OPTIONAL=",latexfull,"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ONLY="" SKIP="" WITH="" DRY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --only) ONLY="$2"; shift 2 ;;
    --skip) SKIP="$2"; shift 2 ;;
    --with) WITH="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) sed -n '2,23p' "$0"; exit 0 ;;
    *) echo "Opción desconocida: $1"; exit 1 ;;
  esac
done

[[ $EUID -eq 0 ]] && { echo "No ejecutes este script como root."; exit 1; }

C_B=$'\e[1;34m' C_G=$'\e[1;32m' C_Y=$'\e[1;33m' C_0=$'\e[0m'
log()     { echo "${C_G}==>${C_0} $*"; }
warn()    { echo "${C_Y}[!]${C_0} $*"; }
section() { echo; echo "${C_B}########## $* ##########${C_0}"; }
run()     { if (( DRY )); then echo "  [dry] $*"; else "$@" || warn "Falló: $*"; fi; }
have()    { command -v "$1" &>/dev/null; }
enabled() {
  local s="$1"
  if [[ -n "$ONLY" ]]; then [[ ",$ONLY," == *",$s,"* ]]; return; fi
  [[ "$OPTIONAL" == *",$s,"* && ",$WITH," != *",$s,"* ]] && return 1
  [[ -n "$SKIP" && ",$SKIP," == *",$s,"* ]] && return 1
  return 0
}

# write_file <ruta> < contenido  — respalda el archivo existente
write_file() {
  local dest="${1/\$HOME_PLACEHOLDER/$HOME}" content
  content="$(cat)"
  content="${content//\$HOME_PLACEHOLDER/$HOME}"
  if (( DRY )); then echo "  [dry] escribir $dest"; return; fi
  mkdir -p "$(dirname "$dest")"
  [[ -f "$dest" ]] && cp -a "$dest" "$dest.bak.$(date +%s)"
  printf '%s\n' "$content" > "$dest"
  log "Escrito $dest"
}

# -----------------------------------------------------------------------------
sec_system() {
  section "Sistema"
  run sudo dnf -y upgrade --refresh
  run sudo dnf -y install dnf-plugins-core curl git wget unzip python3 python3-pip
}

sec_repos() {
  section "Repositorios (Google Chrome, VS Code)"
  run sudo dnf -y install fedora-workstation-repositories
  run sudo dnf config-manager setopt google-chrome.enabled=1
  run sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
  if (( ! DRY )); then
    printf '%s\n' "[code]" "name=Visual Studio Code" "baseurl=https://packages.microsoft.com/yumrepos/vscode" \
      "enabled=1" "gpgcheck=1" "gpgkey=https://packages.microsoft.com/keys/microsoft.asc" \
      | sudo tee /etc/yum.repos.d/vscode.repo >/dev/null
  fi
  run sudo dnf -y makecache
}

DNF_PACKAGES=(
  kitty zsh contour-terminal ptyxis fzf eza bat btop fastfetch tree vim-enhanced git git-lfs gh curl 
  wget2-wget unzip zip rsync make gcc gcc-c++ just strace lsof python3-pip python3-devel python3.12 
  python3-tkinter jdk-21 ruby ruby-devel podman podman-compose toolbox moby-engine docker-compose 
  docker-buildx platformio gtk3-devel webkit2gtk4.1-devel librsvg2-devel libappindicator-gtk3-devel 
  libsoup3-devel ncurses-devel valkey-compat-redis code google-chrome-stable gnome-tweaks 
  gnome-extensions-app gnome-browser-connector hydrapaper jetbrains-mono-fonts-all fira-code-fonts
)

sec_packages() {
  section "Paquetes DNF (${#DNF_PACKAGES[@]})"
  run sudo dnf -y install --skip-unavailable "${DNF_PACKAGES[@]}"
  run git lfs install
  if have docker; then
    run sudo systemctl enable --now docker
    run sudo usermod -aG docker "$USER"
  fi
}

FLATPAKS=( cc.arduino.arduinoide com.getpostman.Postman com.jetbrains.IntelliJ-IDEA-Ultimate io.github.shiftey.Desktop md.obsidian.Obsidian org.gaphor.Gaphor org.gnome.Extensions org.telegram.desktop )

sec_flatpak() {
  section "Flatpak"
  run sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  for app in "${FLATPAKS[@]}"; do
    flatpak info "$app" &>/dev/null && { log "$app ya instalado"; continue; }
    run flatpak install -y --noninteractive flathub "$app"
  done
}

sec_shell() {
  section "Shell: zsh + oh-my-zsh + powerlevel10k + starship"
  have zsh || run sudo dnf -y install zsh
  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    run env RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  fi
  local C="$HOME/.oh-my-zsh/custom"
  [[ -d "$C/themes/powerlevel10k" ]]        || run git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$C/themes/powerlevel10k"
  [[ -d "$C/plugins/fzf-tab" ]]             || run git clone --depth=1 https://github.com/Aloxaf/fzf-tab "$C/plugins/fzf-tab"
  [[ -d "$C/plugins/zsh-autosuggestions" ]] || run git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$C/plugins/zsh-autosuggestions"
  have starship || run sh -c "curl -sS https://starship.rs/install.sh | sh -s -- -y"
  [[ "$(getent passwd "$USER" | cut -d: -f7)" == *zsh ]] || run sudo chsh -s "$(command -v zsh)" "$USER"
}

sec_dotfiles() {
  section "Dotfiles visuales (kitty, zsh, p10k, starship)"
  write_file '$HOME_PLACEHOLDER/.config/kitty/kitty.conf' <<'__EOF_CFG__'
font_family JetBrains Mono
font_size 14.0

background_opacity 0.63

window_padding_width 10
window_border_width 1.0pt

cursor #7aa2f7
cursor_text_color #1a1b26

selection_foreground #1a1b26
selection_background #7aa2f7

tab_bar_edge top
tab_bar_style powerline

active_tab_foreground #ffffff
active_tab_background #7aa2f7
inactive_tab_foreground #888888
inactive_tab_background #1a1b26

enable_audio_bell no
visual_bell_duration 0

scrollback_lines 10000
__EOF_CFG__

  write_file '$HOME_PLACEHOLDER/.config/kitty/current-theme.conf' <<'__EOF_CFG__'
background            #1e1c44
foreground            #f8dbc0
cursor                #eebf37
selection_background  #6f6a4e
color0                #050404
color8                #4e7bbf
color1                #bc0013
color9                #fc5e59
color2                #49b117
color10               #9dff6e
color3                #e6741d
color11               #efc11a
color4                #0f49c6
color12               #1896c6
color5                #665992
color13               #9a5952
color6                #6fa497
color14               #c8f9f3
color7                #f8dbc0
color15               #f5f4fb
selection_foreground #1e1c44

# START_AUTOGENERATED_TAB_STYLE
# Feel free to update these colors manually and remove these comments.
active_tab_foreground   #eeeeee
active_tab_background   #6f6a4e
inactive_tab_foreground #f8dbc0
inactive_tab_background #181636
# END_AUTOGENERATED_TAB_STYLE
__EOF_CFG__

  write_file '$HOME_PLACEHOLDER/.zshrc' <<'__EOF_CFG__'
export PATH="$HOME_PLACEHOLDER/.nvm/versions/node/v24.17.0/bin:$PATH"
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="powerlevel10k/powerlevel10k"
# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git fzf-tab)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='nvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
export GEM_HOME="$HOME/.gem"
export PATH="$HOME/.gem/bin:$HOME/bin:$PATH"

bindkey '^H' clear-screen
export PATH="$HOME/.npm-global/bin:$PATH"


# Added by Antigravity CLI installer
export PATH="$HOME_PLACEHOLDER/.local/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"

# fzf-tab configuration
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza --tree --level=2 --color=always $realpath'

zstyle ':fzf-tab:complete:*:*' fzf-preview '
  if [[ -d "$realpath" ]]; then
    eza --tree --level=2 --color=always "$realpath"
  elif [[ -f "$realpath" ]]; then
    bat --color=always --style=numbers --line-range=:200 "$realpath"
  fi
'
eval "$(starship init zsh)"
__EOF_CFG__

  write_file '$HOME_PLACEHOLDER/.p10k.zsh' <<'__EOF_CFG__'
# Generated by Powerlevel10k configuration wizard on 2026-06-22 at 12:40 -05.
# Based on romkatv/powerlevel10k/config/p10k-classic.zsh, checksum 57870.
# Wizard options: awesome-fontconfig + powerline, large icons, classic, unicode,
# darkest, vertical separators, sharp heads, sharp tails, 2 lines, disconnected,
# full frame, sparse, few icons, concise, instant_prompt=verbose.
# Type `p10k configure` to generate another config.
#
# Config for Powerlevel10k with classic powerline prompt style. Type `p10k configure` to generate
# your own config based on it.
#
# Tip: Looking for a nice color? Here's a one-liner to print colormap.
#
#   for i in {0..255}; do print -Pn "%K{$i}  %k%F{$i}${(l:3::0:)i}%f " ${${(M)$((i%6)):#3}:+$'\n'}; done

# Temporarily change options.
'builtin' 'local' '-a' 'p10k_config_opts'
[[ ! -o 'aliases'         ]] || p10k_config_opts+=('aliases')
[[ ! -o 'sh_glob'         ]] || p10k_config_opts+=('sh_glob')
[[ ! -o 'no_brace_expand' ]] || p10k_config_opts+=('no_brace_expand')
'builtin' 'setopt' 'no_aliases' 'no_sh_glob' 'brace_expand'

() {
  emulate -L zsh -o extended_glob

  # Unset all configuration options. This allows you to apply configuration changes without
  # restarting zsh. Edit ~/.p10k.zsh and type `source ~/.p10k.zsh`.
  unset -m '(POWERLEVEL9K_*|DEFAULT_USER)~POWERLEVEL9K_GITSTATUS_DIR'

  # Zsh >= 5.1 is required.
  [[ $ZSH_VERSION == (5.<1->*|<6->.*) ]] || return

  # The list of segments shown on the left. Fill it with the most important segments.
  typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
    # =========================[ Line #1 ]=========================
    # os_icon               # os identifier
    dir                     # current directory
    vcs                     # git status
    # =========================[ Line #2 ]=========================
    newline                 # \n
    # prompt_char           # prompt symbol
  )

  # The list of segments shown on the right. Fill it with less important segments.
  # Right prompt on the last prompt line (where you are typing your commands) gets
  # automatically hidden when the input line reaches it. Right prompt above the
  # last prompt line gets hidden if it would overlap with left prompt.
  typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(
    # =========================[ Line #1 ]=========================
    status                  # exit code of the last command
    command_execution_time  # duration of the last command
    background_jobs         # presence of background jobs
    direnv                  # direnv status (https://direnv.net/)
    asdf                    # asdf version manager (https://github.com/asdf-vm/asdf)
    virtualenv              # python virtual environment (https://docs.python.org/3/library/venv.html)
    anaconda                # conda environment (https://conda.io/)
    pyenv                   # python environment (https://github.com/pyenv/pyenv)
    goenv                   # go environment (https://github.com/syndbg/goenv)
    nodenv                  # node.js version from nodenv (https://github.com/nodenv/nodenv)
    nvm                     # node.js version from nvm (https://github.com/nvm-sh/nvm)
    nodeenv                 # node.js environment (https://github.com/ekalinin/nodeenv)
    # node_version          # node.js version
    # go_version            # go version (https://golang.org)
    # rust_version          # rustc version (https://www.rust-lang.org)
    # dotnet_version        # .NET version (https://dotnet.microsoft.com)
    # php_version           # php version (https://www.php.net/)
    # laravel_version       # laravel php framework version (https://laravel.com/)
    # java_version          # java version (https://www.java.com/)
    # package               # name@version from package.json (https://docs.npmjs.com/files/package.json)
    rbenv                   # ruby version from rbenv (https://github.com/rbenv/rbenv)
    rvm                     # ruby version from rvm (https://rvm.io)
    fvm                     # flutter version management (https://github.com/leoafarias/fvm)
    luaenv                  # lua version from luaenv (https://github.com/cehoffman/luaenv)
    jenv                    # java version from jenv (https://github.com/jenv/jenv)
    plenv                   # perl version from plenv (https://github.com/tokuhirom/plenv)
    perlbrew                # perl version from perlbrew (https://github.com/gugod/App-perlbrew)
    phpenv                  # php version from phpenv (https://github.com/phpenv/phpenv)
    scalaenv                # scala version from scalaenv (https://github.com/scalaenv/scalaenv)
    haskell_stack           # haskell version from stack (https://haskellstack.org/)
    kubecontext             # current kubernetes context (https://kubernetes.io/)
    terraform               # terraform workspace (https://www.terraform.io)
    # terraform_version     # terraform version (https://www.terraform.io)
    aws                     # aws profile (https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-profiles.html)
    aws_eb_env              # aws elastic beanstalk environment (https://aws.amazon.com/elasticbeanstalk/)
    azure                   # azure account name (https://docs.microsoft.com/en-us/cli/azure)
    gcloud                  # google cloud cli account and project (https://cloud.google.com/)
    google_app_cred         # google application credentials (https://cloud.google.com/docs/authentication/production)
    toolbox                 # toolbox name (https://github.com/containers/toolbox)
    context                 # user@hostname
    nordvpn                 # nordvpn connection status, linux only (https://nordvpn.com/)
    ranger                  # ranger shell (https://github.com/ranger/ranger)
    yazi                    # yazi shell (https://github.com/sxyazi/yazi)
    nnn                     # nnn shell (https://github.com/jarun/nnn)
    lf                      # lf shell (https://github.com/gokcehan/lf)
    xplr                    # xplr shell (https://github.com/sayanarijit/xplr)
    vim_shell               # vim shell indicator (:sh)
    midnight_commander      # midnight commander shell (https://midnight-commander.org/)
    nix_shell               # nix shell (https://nixos.org/nixos/nix-pills/developing-with-nix-shell.html)
    chezmoi_shell           # chezmoi shell (https://www.chezmoi.io/)
    vi_mode                 # vi mode (you don't need this if you've enabled prompt_char)
    # vpn_ip                # virtual private network indicator
    # load                  # CPU load
    # disk_usage            # disk usage
    # ram                   # free RAM
    # swap                  # used swap
    todo                    # todo items (https://github.com/todotxt/todo.txt-cli)
    timewarrior             # timewarrior tracking status (https://timewarrior.net/)
    taskwarrior             # taskwarrior task count (https://taskwarrior.org/)
    per_directory_history   # Oh My Zsh per-directory-history local/global indicator
    # cpu_arch              # CPU architecture
    # time                  # current time
    # =========================[ Line #2 ]=========================
    newline                 # \n
    # ip                    # ip address and bandwidth usage for a specified network interface
    # public_ip             # public IP address
    # proxy                 # system-wide http/https/ftp proxy
    # battery               # internal battery
    # wifi                  # wifi speed
    # example               # example user-defined segment (see prompt_example function below)
  )

  # Defines character set used by powerlevel10k. It's best to let `p10k configure` set it for you.
  typeset -g POWERLEVEL9K_MODE=awesome-fontconfig
  # When set to `moderate`, some icons will have an extra space after them. This is meant to avoid
  # icon overlap when using non-monospace fonts. When set to `none`, spaces are not added.
  typeset -g POWERLEVEL9K_ICON_PADDING=moderate

  # When set to true, icons appear before content on both sides of the prompt. When set
  # to false, icons go after content. If empty or not set, icons go before content in the left
  # prompt and after content in the right prompt.
  #
  # You can also override it for a specific segment:
  #
  #   POWERLEVEL9K_STATUS_ICON_BEFORE_CONTENT=false
  #
  # Or for a specific segment in specific state:
  #
  #   POWERLEVEL9K_DIR_NOT_WRITABLE_ICON_BEFORE_CONTENT=false
  typeset -g POWERLEVEL9K_ICON_BEFORE_CONTENT=

  # Add an empty line before each prompt.
  typeset -g POWERLEVEL9K_PROMPT_ADD_NEWLINE=true

  # Connect left prompt lines with these symbols. You'll probably want to use the same color
  # as POWERLEVEL9K_MULTILINE_FIRST_PROMPT_GAP_FOREGROUND below.
  typeset -g POWERLEVEL9K_MULTILINE_FIRST_PROMPT_PREFIX='%238F╭─'
  typeset -g POWERLEVEL9K_MULTILINE_NEWLINE_PROMPT_PREFIX='%238F├─'
  typeset -g POWERLEVEL9K_MULTILINE_LAST_PROMPT_PREFIX='%238F╰─'
  # Connect right prompt lines with these symbols.
  typeset -g POWERLEVEL9K_MULTILINE_FIRST_PROMPT_SUFFIX='%238F─╮'
  typeset -g POWERLEVEL9K_MULTILINE_NEWLINE_PROMPT_SUFFIX='%238F─┤'
  typeset -g POWERLEVEL9K_MULTILINE_LAST_PROMPT_SUFFIX='%238F─╯'

  # Filler between left and right prompt on the first prompt line. You can set it to ' ', '·' or
  # '─'. The last two make it easier to see the alignment between left and right prompt and to
  # separate prompt from command output. You might want to set POWERLEVEL9K_PROMPT_ADD_NEWLINE=false
  # for more compact prompt if using this option.
  typeset -g POWERLEVEL9K_MULTILINE_FIRST_PROMPT_GAP_CHAR=' '
  typeset -g POWERLEVEL9K_MULTILINE_FIRST_PROMPT_GAP_BACKGROUND=
  typeset -g POWERLEVEL9K_MULTILINE_NEWLINE_PROMPT_GAP_BACKGROUND=
  if [[ $POWERLEVEL9K_MULTILINE_FIRST_PROMPT_GAP_CHAR != ' ' ]]; then
    # The color of the filler. You'll probably want to match the color of POWERLEVEL9K_MULTILINE
    # ornaments defined above.
    typeset -g POWERLEVEL9K_MULTILINE_FIRST_PROMPT_GAP_FOREGROUND=238
    # Start filler from the edge of the screen if there are no left segments on the first line.
    typeset -g POWERLEVEL9K_EMPTY_LINE_LEFT_PROMPT_FIRST_SEGMENT_END_SYMBOL='%{%}'
    # End filler on the edge of the screen if there are no right segments on the first line.
    typeset -g POWERLEVEL9K_EMPTY_LINE_RIGHT_PROMPT_FIRST_SEGMENT_START_SYMBOL='%{%}'
  fi

  # Default background color.
  typeset -g POWERLEVEL9K_BACKGROUND=234

  # Separator between same-color segments on the left.
  typeset -g POWERLEVEL9K_LEFT_SUBSEGMENT_SEPARATOR='%242F\u2502'
  # Separator between same-color segments on the right.
  typeset -g POWERLEVEL9K_RIGHT_SUBSEGMENT_SEPARATOR='%242F\u2502'
  # Separator between different-color segments on the left.
  typeset -g POWERLEVEL9K_LEFT_SEGMENT_SEPARATOR=''
  # Separator between different-color segments on the right.
  typeset -g POWERLEVEL9K_RIGHT_SEGMENT_SEPARATOR=''
  # To remove a separator between two segments, add "_joined" to the second segment name.
  # For example: POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(os_icon context_joined)

  # The right end of left prompt.
  typeset -g POWERLEVEL9K_LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL='\uE0B0'
  # The left end of right prompt.
  typeset -g POWERLEVEL9K_RIGHT_PROMPT_FIRST_SEGMENT_START_SYMBOL='\uE0B2'
  # The left end of left prompt.
  typeset -g POWERLEVEL9K_LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL='\uE0B2'
  # The right end of right prompt.
  typeset -g POWERLEVEL9K_RIGHT_PROMPT_LAST_SEGMENT_END_SYMBOL='\uE0B0'
  # Left prompt terminator for lines without any segments.
  typeset -g POWERLEVEL9K_EMPTY_LINE_LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL=

  #################################[ os_icon: os identifier ]##################################
  # OS identifier color.
  typeset -g POWERLEVEL9K_OS_ICON_FOREGROUND=255
  # Custom icon.
  # typeset -g POWERLEVEL9K_OS_ICON_CONTENT_EXPANSION='⭐'

  ################################[ prompt_char: prompt symbol ]################################
  # Transparent background.
  typeset -g POWERLEVEL9K_PROMPT_CHAR_BACKGROUND=
  # Green prompt symbol if the last command succeeded.
  typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND=76
  # Red prompt symbol if the last command failed.
  typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND=196
  # Default prompt symbol.
  typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VIINS_CONTENT_EXPANSION='❯'
  # Prompt symbol in command vi mode.
  typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VICMD_CONTENT_EXPANSION='❮'
  # Prompt symbol in visual vi mode.
  typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VIVIS_CONTENT_EXPANSION='V'
  # Prompt symbol in overwrite vi mode.
  typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VIOWR_CONTENT_EXPANSION='▶'
  typeset -g POWERLEVEL9K_PROMPT_CHAR_OVERWRITE_STATE=true
  # No line terminator if prompt_char is the last segment.
  typeset -g POWERLEVEL9K_PROMPT_CHAR_LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL=
  # No line introducer if prompt_char is the first segment.
  typeset -g POWERLEVEL9K_PROMPT_CHAR_LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL=
  # No surrounding whitespace.
  typeset -g POWERLEVEL9K_PROMPT_CHAR_LEFT_{LEFT,RIGHT}_WHITESPACE=

  ##################################[ dir: current directory ]##################################
  # Default current directory color.
  typeset -g POWERLEVEL9K_DIR_FOREGROUND=31
  # If directory is too long, shorten some of its segments to the shortest possible unique
  # prefix. The shortened directory can be tab-completed to the original.
  typeset -g POWERLEVEL9K_SHORTEN_STRATEGY=truncate_to_unique
  # Replace removed segment suffixes with this symbol.
  typeset -g POWERLEVEL9K_SHORTEN_DELIMITER=
  # Color of the shortened directory segments.
  typeset -g POWERLEVEL9K_DIR_SHORTENED_FOREGROUND=103
  # Color of the anchor directory segments. Anchor segments are never shortened. The first
  # segment is always an anchor.
  typeset -g POWERLEVEL9K_DIR_ANCHOR_FOREGROUND=39
  # Display anchor directory segments in bold.
  typeset -g POWERLEVEL9K_DIR_ANCHOR_BOLD=true
  # Don't shorten directories that contain any of these files. They are anchors.
  local anchor_files=(
    .bzr
    .citc
    .git
    .hg
    .node-version
    .python-version
    .go-version
    .ruby-version
    .lua-version
    .java-version
    .perl-version
    .php-version
    .tool-versions
    .mise.toml
    .shorten_folder_marker
    .svn
    .terraform
    CVS
    Cargo.toml
    composer.json
    go.mod
    package.json
    stack.yaml
  )
  typeset -g POWERLEVEL9K_SHORTEN_FOLDER_MARKER="(${(j:|:)anchor_files})"
  # If set to "first" ("last"), remove everything before the first (last) subdirectory that contains
  # files matching $POWERLEVEL9K_SHORTEN_FOLDER_MARKER. For example, when the current directory is
  # /foo/bar/git_repo/nested_git_repo/baz, prompt will display git_repo/nested_git_repo/baz (first)
  # or nested_git_repo/baz (last). This assumes that git_repo and nested_git_repo contain markers
  # and other directories don't.
  #
  # Optionally, "first" and "last" can be followed by ":<offset>" where <offset> is an integer.
  # This moves the truncation point to the right (positive offset) or to the left (negative offset)
  # relative to the marker. Plain "first" and "last" are equivalent to "first:0" and "last:0"
  # respectively.
  typeset -g POWERLEVEL9K_DIR_TRUNCATE_BEFORE_MARKER=false
  # Don't shorten this many last directory segments. They are anchors.
  typeset -g POWERLEVEL9K_SHORTEN_DIR_LENGTH=1
  # Shorten directory if it's longer than this even if there is space for it. The value can
  # be either absolute (e.g., '80') or a percentage of terminal width (e.g, '50%'). If empty,
  # directory will be shortened only when prompt doesn't fit or when other parameters demand it
  # (see POWERLEVEL9K_DIR_MIN_COMMAND_COLUMNS and POWERLEVEL9K_DIR_MIN_COMMAND_COLUMNS_PCT below).
  # If set to `0`, directory will always be shortened to its minimum length.
  typeset -g POWERLEVEL9K_DIR_MAX_LENGTH=80
  # When `dir` segment is on the last prompt line, try to shorten it enough to leave at least this
  # many columns for typing commands.
  typeset -g POWERLEVEL9K_DIR_MIN_COMMAND_COLUMNS=40
  # When `dir` segment is on the last prompt line, try to shorten it enough to leave at least
  # COLUMNS * POWERLEVEL9K_DIR_MIN_COMMAND_COLUMNS_PCT * 0.01 columns for typing commands.
  typeset -g POWERLEVEL9K_DIR_MIN_COMMAND_COLUMNS_PCT=50
  # If set to true, embed a hyperlink into the directory. Useful for quickly
  # opening a directory in the file manager simply by clicking the link.
  # Can also be handy when the directory is shortened, as it allows you to see
  # the full directory that was used in previous commands.
  typeset -g POWERLEVEL9K_DIR_HYPERLINK=false

  # Enable special styling for non-writable and non-existent directories. See POWERLEVEL9K_LOCK_ICON
  # and POWERLEVEL9K_DIR_CLASSES below.
  typeset -g POWERLEVEL9K_DIR_SHOW_WRITABLE=v3

  # The default icon shown next to non-writable and non-existent directories when
  # POWERLEVEL9K_DIR_SHOW_WRITABLE is set to v3.
  # typeset -g POWERLEVEL9K_LOCK_ICON='⭐'

  # POWERLEVEL9K_DIR_CLASSES allows you to specify custom icons and colors for different
  # directories. It must be an array with 3 * N elements. Each triplet consists of:
  #
  #   1. A pattern against which the current directory ($PWD) is matched. Matching is done with
  #      extended_glob option enabled.
  #   2. Directory class for the purpose of styling.
  #   3. An empty string.
  #
  # Triplets are tried in order. The first triplet whose pattern matches $PWD wins.
  #
  # If POWERLEVEL9K_DIR_SHOW_WRITABLE is set to v3, non-writable and non-existent directories
  # acquire class suffix _NOT_WRITABLE and NON_EXISTENT respectively.
  #
  # For example, given these settings:
  #
  #   typeset -g POWERLEVEL9K_DIR_CLASSES=(
  #     '~/work(|/*)'  WORK     ''
  #     '~(|/*)'       HOME     ''
  #     '*'            DEFAULT  '')
  #
  # Whenever the current directory is ~/work or a subdirectory of ~/work, it gets styled with one
  # of the following classes depending on its writability and existence: WORK, WORK_NOT_WRITABLE or
  # WORK_NON_EXISTENT.
  #
  # Simply assigning classes to directories doesn't have any visible effects. It merely gives you an
  # option to define custom colors and icons for different directory classes.
  #
  #   # Styling for WORK.
  #   typeset -g POWERLEVEL9K_DIR_WORK_VISUAL_IDENTIFIER_EXPANSION='⭐'
  #   typeset -g POWERLEVEL9K_DIR_WORK_FOREGROUND=31
  #   typeset -g POWERLEVEL9K_DIR_WORK_SHORTENED_FOREGROUND=103
  #   typeset -g POWERLEVEL9K_DIR_WORK_ANCHOR_FOREGROUND=39
  #
  #   # Styling for WORK_NOT_WRITABLE.
  #   typeset -g POWERLEVEL9K_DIR_WORK_NOT_WRITABLE_VISUAL_IDENTIFIER_EXPANSION='⭐'
  #   typeset -g POWERLEVEL9K_DIR_WORK_NOT_WRITABLE_FOREGROUND=31
  #   typeset -g POWERLEVEL9K_DIR_WORK_NOT_WRITABLE_SHORTENED_FOREGROUND=103
  #   typeset -g POWERLEVEL9K_DIR_WORK_NOT_WRITABLE_ANCHOR_FOREGROUND=39
  #
  #   # Styling for WORK_NON_EXISTENT.
  #   typeset -g POWERLEVEL9K_DIR_WORK_NON_EXISTENT_VISUAL_IDENTIFIER_EXPANSION='⭐'
  #   typeset -g POWERLEVEL9K_DIR_WORK_NON_EXISTENT_FOREGROUND=31
  #   typeset -g POWERLEVEL9K_DIR_WORK_NON_EXISTENT_SHORTENED_FOREGROUND=103
  #   typeset -g POWERLEVEL9K_DIR_WORK_NON_EXISTENT_ANCHOR_FOREGROUND=39
  #
  # If a styling parameter isn't explicitly defined for some class, it falls back to the classless
  # parameter. For example, if POWERLEVEL9K_DIR_WORK_NOT_WRITABLE_FOREGROUND is not set, it falls
  # back to POWERLEVEL9K_DIR_FOREGROUND.
  #
  typeset -g POWERLEVEL9K_DIR_CLASSES=()

  # Custom prefix.
  # typeset -g POWERLEVEL9K_DIR_PREFIX='%244Fin '

  #####################################[ vcs: git status ]######################################
  # Branch icon. Set this parameter to '\UE0A0 ' for the popular Powerline branch icon.
  typeset -g POWERLEVEL9K_VCS_BRANCH_ICON=

  # Untracked files icon. It's really a question mark, your font isn't broken.
  # Change the value of this parameter to show a different icon.
  typeset -g POWERLEVEL9K_VCS_UNTRACKED_ICON='?'

  # Formatter for Git status.
  #
  # Example output: master wip ⇣42⇡42 *42 merge ~42 +42 !42 ?42.
  #
  # You can edit the function to customize how Git status looks.
  #
  # VCS_STATUS_* parameters are set by gitstatus plugin. See reference:
  # https://github.com/romkatv/gitstatus/blob/master/gitstatus.plugin.zsh.
  function my_git_formatter() {
    emulate -L zsh

    if [[ -n $P9K_CONTENT ]]; then
      # If P9K_CONTENT is not empty, use it. It's either "loading" or from vcs_info (not from
      # gitstatus plugin). VCS_STATUS_* parameters are not available in this case.
      typeset -g my_git_format=$P9K_CONTENT
      return
    fi

    if (( $1 )); then
      # Styling for up-to-date Git status.
      local       meta='%244F'  # grey foreground
      local      clean='%76F'   # green foreground
      local   modified='%178F'  # yellow foreground
      local  untracked='%39F'   # blue foreground
      local conflicted='%196F'  # red foreground
    else
      # Styling for incomplete and stale Git status.
      local       meta='%244F'  # grey foreground
      local      clean='%244F'  # grey foreground
      local   modified='%244F'  # grey foreground
      local  untracked='%244F'  # grey foreground
      local conflicted='%244F'  # grey foreground
    fi

    local res

    if [[ -n $VCS_STATUS_LOCAL_BRANCH ]]; then
      local branch=${(V)VCS_STATUS_LOCAL_BRANCH}
      # If local branch name is at most 32 characters long, show it in full.
      # Otherwise show the first 12 … the last 12.
      # Tip: To always show local branch name in full without truncation, delete the next line.
      (( $#branch > 32 )) && branch[13,-13]="…"  # <-- this line
      res+="${clean}${(g::)POWERLEVEL9K_VCS_BRANCH_ICON}${branch//\%/%%}"
    fi

    if [[ -n $VCS_STATUS_TAG
          # Show tag only if not on a branch.
          # Tip: To always show tag, delete the next line.
          && -z $VCS_STATUS_LOCAL_BRANCH  # <-- this line
        ]]; then
      local tag=${(V)VCS_STATUS_TAG}
      # If tag name is at most 32 characters long, show it in full.
      # Otherwise show the first 12 … the last 12.
      # Tip: To always show tag name in full without truncation, delete the next line.
      (( $#tag > 32 )) && tag[13,-13]="…"  # <-- this line
      res+="${meta}#${clean}${tag//\%/%%}"
    fi

    # Display the current Git commit if there is no branch and no tag.
    # Tip: To always display the current Git commit, delete the next line.
    [[ -z $VCS_STATUS_LOCAL_BRANCH && -z $VCS_STATUS_TAG ]] &&  # <-- this line
      res+="${meta}@${clean}${VCS_STATUS_COMMIT[1,8]}"

    # Show tracking branch name if it differs from local branch.
    if [[ -n ${VCS_STATUS_REMOTE_BRANCH:#$VCS_STATUS_LOCAL_BRANCH} ]]; then
      res+="${meta}:${clean}${(V)VCS_STATUS_REMOTE_BRANCH//\%/%%}"
    fi

    # Display "wip" if the latest commit's summary contains "wip" or "WIP".
    if [[ $VCS_STATUS_COMMIT_SUMMARY == (|*[^[:alnum:]])(wip|WIP)(|[^[:alnum:]]*) ]]; then
      res+=" ${modified}wip"
    fi

    if (( VCS_STATUS_COMMITS_AHEAD || VCS_STATUS_COMMITS_BEHIND )); then
      # ⇣42 if behind the remote.
      (( VCS_STATUS_COMMITS_BEHIND )) && res+=" ${clean}⇣${VCS_STATUS_COMMITS_BEHIND}"
      # ⇡42 if ahead of the remote; no leading space if also behind the remote: ⇣42⇡42.
      (( VCS_STATUS_COMMITS_AHEAD && !VCS_STATUS_COMMITS_BEHIND )) && res+=" "
      (( VCS_STATUS_COMMITS_AHEAD  )) && res+="${clean}⇡${VCS_STATUS_COMMITS_AHEAD}"
    elif [[ -n $VCS_STATUS_REMOTE_BRANCH ]]; then
      # Tip: Uncomment the next line to display '=' if up to date with the remote.
      # res+=" ${clean}="
    fi

    # ⇠42 if behind the push remote.
    (( VCS_STATUS_PUSH_COMMITS_BEHIND )) && res+=" ${clean}⇠${VCS_STATUS_PUSH_COMMITS_BEHIND}"
    (( VCS_STATUS_PUSH_COMMITS_AHEAD && !VCS_STATUS_PUSH_COMMITS_BEHIND )) && res+=" "
    # ⇢42 if ahead of the push remote; no leading space if also behind: ⇠42⇢42.
    (( VCS_STATUS_PUSH_COMMITS_AHEAD  )) && res+="${clean}⇢${VCS_STATUS_PUSH_COMMITS_AHEAD}"
    # *42 if have stashes.
    (( VCS_STATUS_STASHES        )) && res+=" ${clean}*${VCS_STATUS_STASHES}"
    # 'merge' if the repo is in an unusual state.
    [[ -n $VCS_STATUS_ACTION     ]] && res+=" ${conflicted}${VCS_STATUS_ACTION}"
    # ~42 if have merge conflicts.
    (( VCS_STATUS_NUM_CONFLICTED )) && res+=" ${conflicted}~${VCS_STATUS_NUM_CONFLICTED}"
    # +42 if have staged changes.
    (( VCS_STATUS_NUM_STAGED     )) && res+=" ${modified}+${VCS_STATUS_NUM_STAGED}"
    # !42 if have unstaged changes.
    (( VCS_STATUS_NUM_UNSTAGED   )) && res+=" ${modified}!${VCS_STATUS_NUM_UNSTAGED}"
    # ?42 if have untracked files. It's really a question mark, your font isn't broken.
    # See POWERLEVEL9K_VCS_UNTRACKED_ICON above if you want to use a different icon.
    # Remove the next line if you don't want to see untracked files at all.
    (( VCS_STATUS_NUM_UNTRACKED  )) && res+=" ${untracked}${(g::)POWERLEVEL9K_VCS_UNTRACKED_ICON}${VCS_STATUS_NUM_UNTRACKED}"
    # "─" if the number of unstaged files is unknown. This can happen due to
    # POWERLEVEL9K_VCS_MAX_INDEX_SIZE_DIRTY (see below) being set to a non-negative number lower
    # than the number of files in the Git index, or due to bash.showDirtyState being set to false
    # in the repository config. The number of staged and untracked files may also be unknown
    # in this case.
    (( VCS_STATUS_HAS_UNSTAGED == -1 )) && res+=" ${modified}─"

    typeset -g my_git_format=$res
  }
  functions -M my_git_formatter 2>/dev/null

  # Don't count the number of unstaged, untracked and conflicted files in Git repositories with
  # more than this many files in the index. Negative value means infinity.
  #
  # If you are working in Git repositories with tens of millions of files and seeing performance
  # sagging, try setting POWERLEVEL9K_VCS_MAX_INDEX_SIZE_DIRTY to a number lower than the output
  # of `git ls-files | wc -l`. Alternatively, add `bash.showDirtyState = false` to the repository's
  # config: `git config bash.showDirtyState false`.
  typeset -g POWERLEVEL9K_VCS_MAX_INDEX_SIZE_DIRTY=-1

  # Don't show Git status in prompt for repositories whose workdir matches this pattern.
  # For example, if set to '~', the Git repository at $HOME/.git will be ignored.
  # Multiple patterns can be combined with '|': '~(|/foo)|/bar/baz/*'.
  typeset -g POWERLEVEL9K_VCS_DISABLED_WORKDIR_PATTERN='~'

  # Disable the default Git status formatting.
  typeset -g POWERLEVEL9K_VCS_DISABLE_GITSTATUS_FORMATTING=true
  # Install our own Git status formatter.
  typeset -g POWERLEVEL9K_VCS_CONTENT_EXPANSION='${$((my_git_formatter(1)))+${my_git_format}}'
  typeset -g POWERLEVEL9K_VCS_LOADING_CONTENT_EXPANSION='${$((my_git_formatter(0)))+${my_git_format}}'
  # Enable counters for staged, unstaged, etc.
  typeset -g POWERLEVEL9K_VCS_{STAGED,UNSTAGED,UNTRACKED,CONFLICTED,COMMITS_AHEAD,COMMITS_BEHIND}_MAX_NUM=-1

  # Icon color.
  typeset -g POWERLEVEL9K_VCS_VISUAL_IDENTIFIER_COLOR=76
  typeset -g POWERLEVEL9K_VCS_LOADING_VISUAL_IDENTIFIER_COLOR=244
  # Custom icon.
  typeset -g POWERLEVEL9K_VCS_VISUAL_IDENTIFIER_EXPANSION=
  # Custom prefix.
  # typeset -g POWERLEVEL9K_VCS_PREFIX='%244Fon '

  # Show status of repositories of these types. You can add svn and/or hg if you are
  # using them. If you do, your prompt may become slow even when your current directory
  # isn't in an svn or hg reposotiry.
  typeset -g POWERLEVEL9K_VCS_BACKENDS=(git)

  # These settings are used for repositories other than Git or when gitstatusd fails and
  # Powerlevel10k has to fall back to using vcs_info.
  typeset -g POWERLEVEL9K_VCS_CLEAN_FOREGROUND=76
  typeset -g POWERLEVEL9K_VCS_UNTRACKED_FOREGROUND=76
  typeset -g POWERLEVEL9K_VCS_MODIFIED_FOREGROUND=178

  ##########################[ status: exit code of the last command ]###########################
  # Enable OK_PIPE, ERROR_PIPE and ERROR_SIGNAL status states to allow us to enable, disable and
  # style them independently from the regular OK and ERROR state.
  typeset -g POWERLEVEL9K_STATUS_EXTENDED_STATES=true

  # Status on success. No content, just an icon. No need to show it if prompt_char is enabled as
  # it will signify success by turning green.
  typeset -g POWERLEVEL9K_STATUS_OK=true
  typeset -g POWERLEVEL9K_STATUS_OK_FOREGROUND=70
  typeset -g POWERLEVEL9K_STATUS_OK_VISUAL_IDENTIFIER_EXPANSION='✔'

  # Status when some part of a pipe command fails but the overall exit status is zero. It may look
  # like this: 1|0.
  typeset -g POWERLEVEL9K_STATUS_OK_PIPE=true
  typeset -g POWERLEVEL9K_STATUS_OK_PIPE_FOREGROUND=70
  typeset -g POWERLEVEL9K_STATUS_OK_PIPE_VISUAL_IDENTIFIER_EXPANSION='✔'

  # Status when it's just an error code (e.g., '1'). No need to show it if prompt_char is enabled as
  # it will signify error by turning red.
  typeset -g POWERLEVEL9K_STATUS_ERROR=true
  typeset -g POWERLEVEL9K_STATUS_ERROR_FOREGROUND=160
  typeset -g POWERLEVEL9K_STATUS_ERROR_VISUAL_IDENTIFIER_EXPANSION='✘'

  # Status when the last command was terminated by a signal.
  typeset -g POWERLEVEL9K_STATUS_ERROR_SIGNAL=true
  typeset -g POWERLEVEL9K_STATUS_ERROR_SIGNAL_FOREGROUND=160
  # Use terse signal names: "INT" instead of "SIGINT(2)".
  typeset -g POWERLEVEL9K_STATUS_VERBOSE_SIGNAME=false
  typeset -g POWERLEVEL9K_STATUS_ERROR_SIGNAL_VISUAL_IDENTIFIER_EXPANSION='✘'

  # Status when some part of a pipe command fails and the overall exit status is also non-zero.
  # It may look like this: 1|0.
  typeset -g POWERLEVEL9K_STATUS_ERROR_PIPE=true
  typeset -g POWERLEVEL9K_STATUS_ERROR_PIPE_FOREGROUND=160
  typeset -g POWERLEVEL9K_STATUS_ERROR_PIPE_VISUAL_IDENTIFIER_EXPANSION='✘'

  ###################[ command_execution_time: duration of the last command ]###################
  # Show duration of the last command if takes at least this many seconds.
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_THRESHOLD=3
  # Show this many fractional digits. Zero means round to seconds.
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_PRECISION=0
  # Execution time color.
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_FOREGROUND=248
  # Duration format: 1d 2h 3m 4s.
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_FORMAT='d h m s'
  # Custom icon.
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_VISUAL_IDENTIFIER_EXPANSION=
  # Custom prefix.
  # typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_PREFIX='%244Ftook '

  #######################[ background_jobs: presence of background jobs ]#######################
  # Don't show the number of background jobs.
  typeset -g POWERLEVEL9K_BACKGROUND_JOBS_VERBOSE=false
  # Background jobs color.
  typeset -g POWERLEVEL9K_BACKGROUND_JOBS_FOREGROUND=37
  # Custom icon.
  # typeset -g POWERLEVEL9K_BACKGROUND_JOBS_VISUAL_IDENTIFIER_EXPANSION='⭐'

  #######################[ direnv: direnv status (https://direnv.net/) ]########################
  # Direnv color.
  typeset -g POWERLEVEL9K_DIRENV_FOREGROUND=178
  # Custom icon.
  # typeset -g POWERLEVEL9K_DIRENV_VISUAL_IDENTIFIER_EXPANSION='⭐'

  ###############[ asdf: asdf version manager (https://github.com/asdf-vm/asdf) ]###############
  # Default asdf color. Only used to display tools for which there is no color override (see below).
  # Tip:  Override this parameter for ${TOOL} with POWERLEVEL9K_ASDF_${TOOL}_FOREGROUND.
  typeset -g POWERLEVEL9K_ASDF_FOREGROUND=66

  # There are four parameters that can be used to hide asdf tools. Each parameter describes
  # conditions under which a tool gets hidden. Parameters can hide tools but not unhide them. If at
  # least one parameter decides to hide a tool, that tool gets hidden. If no parameter decides to
  # hide a tool, it gets shown.
  #
  # Special note on the difference between POWERLEVEL9K_ASDF_SOURCES and
  # POWERLEVEL9K_ASDF_PROMPT_ALWAYS_SHOW. Consider the effect of the following commands:
  #
  #   asdf local  python 3.8.1
  #   asdf global python 3.8.1
  #
  # After running both commands the current python version is 3.8.1 and its source is "local" as
  # it takes precedence over "global". If POWERLEVEL9K_ASDF_PROMPT_ALWAYS_SHOW is set to false,
  # it'll hide python version in this case because 3.8.1 is the same as the global version.
  # POWERLEVEL9K_ASDF_SOURCES will hide python version only if the value of this parameter doesn't
  # contain "local".

  # Hide tool versions that don't come from one of these sources.
  #
  # Available sources:
  #
  # - shell   `asdf current` says "set by ASDF_${TOOL}_VERSION environment variable"
  # - local   `asdf current` says "set by /some/not/home/directory/file"
  # - global  `asdf current` says "set by /home/username/file"
  #
  # Note: If this parameter is set to (shell local global), it won't hide tools.
  # Tip:  Override this parameter for ${TOOL} with POWERLEVEL9K_ASDF_${TOOL}_SOURCES.
  typeset -g POWERLEVEL9K_ASDF_SOURCES=(shell local global)

  # If set to false, hide tool versions that are the same as global.
  #
  # Note: The name of this parameter doesn't reflect its meaning at all.
  # Note: If this parameter is set to true, it won't hide tools.
  # Tip:  Override this parameter for ${TOOL} with POWERLEVEL9K_ASDF_${TOOL}_PROMPT_ALWAYS_SHOW.
  typeset -g POWERLEVEL9K_ASDF_PROMPT_ALWAYS_SHOW=false

  # If set to false, hide tool versions that are equal to "system".
  #
  # Note: If this parameter is set to true, it won't hide tools.
  # Tip: Override this parameter for ${TOOL} with POWERLEVEL9K_ASDF_${TOOL}_SHOW_SYSTEM.
  typeset -g POWERLEVEL9K_ASDF_SHOW_SYSTEM=true

  # If set to non-empty value, hide tools unless there is a file matching the specified file pattern
  # in the current directory, or its parent directory, or its grandparent directory, and so on.
  #
  # Note: If this parameter is set to empty value, it won't hide tools.
  # Note: SHOW_ON_UPGLOB isn't specific to asdf. It works with all prompt segments.
  # Tip: Override this parameter for ${TOOL} with POWERLEVEL9K_ASDF_${TOOL}_SHOW_ON_UPGLOB.
  #
  # Example: Hide nodejs version when there is no package.json and no *.js files in the current
  # directory, in `..`, in `../..` and so on.
  #
  #   typeset -g POWERLEVEL9K_ASDF_NODEJS_SHOW_ON_UPGLOB='*.js|package.json'
  typeset -g POWERLEVEL9K_ASDF_SHOW_ON_UPGLOB=

  # Ruby version from asdf.
  typeset -g POWERLEVEL9K_ASDF_RUBY_FOREGROUND=168
  # typeset -g POWERLEVEL9K_ASDF_RUBY_VISUAL_IDENTIFIER_EXPANSION='⭐'
  # typeset -g POWERLEVEL9K_ASDF_RUBY_SHOW_ON_UPGLOB='*.foo|*.bar'

  # Python version from asdf.
  typeset -g POWERLEVEL9K_ASDF_PYTHON_FOREGROUND=37
  # typeset -g POWERLEVEL9K_ASDF_PYTHON_VISUAL_IDENTIFIER_EXPANSION='⭐'
  # typeset -g POWERLEVEL9K_ASDF_PYTHON_SHOW_ON_UPGLOB='*.foo|*.bar'

  # Go version from asdf.
  typeset -g POWERLEVEL9K_ASDF_GOLANG_FOREGROUND=37
  # typeset -g POWERLEVEL9K_ASDF_GOLANG_VISUAL_IDENTIFIER_EXPANSION='⭐'
  # typeset -g POWERLEVEL9K_ASDF_GOLANG_SHOW_ON_UPGLOB='*.foo|*.bar'

  # Node.js version from asdf.
  typeset -g POWERLEVEL9K_ASDF_NODEJS_FOREGROUND=70
  # typeset -g POWERLEVEL9K_ASDF_NODEJS_VISUAL_IDENTIFIER_EXPANSION='⭐'
  # typeset -g POWERLEVEL9K_ASDF_NODEJS_SHOW_ON_UPGLOB='*.foo|*.bar'

  # Rust version from asdf.
  typeset -g POWERLEVEL9K_ASDF_RUST_FOREGROUND=37
  # typeset -g POWERLEVEL9K_ASDF_RUST_VISUAL_IDENTIFIER_EXPANSION='⭐'
  # typeset -g POWERLEVEL9K_ASDF_RUST_SHOW_ON_UPGLOB='*.foo|*.bar'

  # .NET Core version from asdf.
  typeset -g POWERLEVEL9K_ASDF_DOTNET_CORE_FOREGROUND=134
  # typeset -g POWERLEVEL9K_ASDF_DOTNET_CORE_VISUAL_IDENTIFIER_EXPANSION='⭐'
  # typeset -g POWERLEVEL9K_ASDF_DOTNET_CORE_SHOW_ON_UPGLOB='*.foo|*.bar'

  # Flutter version from asdf.
  typeset -g POWERLEVEL9K_ASDF_FLUTTER_FOREGROUND=38
  # typeset -g POWERLEVEL9K_ASDF_FLUTTER_VISUAL_IDENTIFIER_EXPANSION='⭐'
  # typeset -g POWERLEVEL9K_ASDF_FLUTTER_SHOW_ON_UPGLOB='*.foo|*.bar'

  # Lua version from asdf.
  typeset -g POWERLEVEL9K_ASDF_LUA_FOREGROUND=32
  # typeset -g POWERLEVEL9K_ASDF_LUA_VISUAL_IDENTIFIER_EXPANSION='⭐'
  # typeset -g POWERLEVEL9K_ASDF_LUA_SHOW_ON_UPGLOB='*.foo|*.bar'

  # Java version from asdf.
  typeset -g POWERLEVEL9K_ASDF_JAVA_FOREGROUND=32
  # typeset -g POWERLEVEL9K_ASDF_JAVA_VISUAL_IDENTIFIER_EXPANSION='⭐'
  # typeset -g POWERLEVEL9K_ASDF_JAVA_SHOW_ON_UPGLOB='*.foo|*.bar'

  # Perl version from asdf.
  typeset -g POWERLEVEL9K_ASDF_PERL_FOREGROUND=67
  # typeset -g POWERLEVEL9K_ASDF_PERL_VISUAL_IDENTIFIER_EXPANSION='⭐'
  # typeset -g POWERLEVEL9K_ASDF_PERL_SHOW_ON_UPGLOB='*.foo|*.bar'

  # Erlang version from asdf.
  typeset -g POWERLEVEL9K_ASDF_ERLANG_FOREGROUND=125
  # typeset -g POWERLEVEL9K_ASDF_ERLANG_VISUAL_IDENTIFIER_EXPANSION='⭐'
  # typeset -g POWERLEVEL9K_ASDF_ERLANG_SHOW_ON_UPGLOB='*.foo|*.bar'

  # Elixir version from asdf.
  typeset -g POWERLEVEL9K_ASDF_ELIXIR_FOREGROUND=129
  # typeset -g POWERLEVEL9K_ASDF_ELIXIR_VISUAL_IDENTIFIER_EXPANSION='⭐'
  # typeset -g POWERLEVEL9K_ASDF_ELIXIR_SHOW_ON_UPGLOB='*.foo|*.bar'

  # Postgres version from asdf.
  typeset -g POWERLEVEL9K_ASDF_POSTGRES_FOREGROUND=31
  # typeset -g POWERLEVEL9K_ASDF_POSTGRES_VISUAL_IDENTIFIER_EXPANSION='⭐'
  # typeset -g POWERLEVEL9K_ASDF_POSTGRES_SHOW_ON_UPGLOB='*.foo|*.bar'

  # PHP version from asdf.
  typeset -g POWERLEVEL9K_ASDF_PHP_FOREGROUND=99
  # typeset -g POWERLEVEL9K_ASDF_PHP_VISUAL_IDENTIFIER_EXPANSION='⭐'
  # typeset -g POWERLEVEL9K_ASDF_PHP_SHOW_ON_UPGLOB='*.foo|*.bar'

  # Haskell version from asdf.
  typeset -g POWERLEVEL9K_ASDF_HASKELL_FOREGROUND=172
  # typeset -g POWERLEVEL9K_ASDF_HASKELL_VISUAL_IDENTIFIER_EXPANSION='⭐'
  # typeset -g POWERLEVEL9K_ASDF_HASKELL_SHOW_ON_UPGLOB='*.foo|*.bar'

  # Julia version from asdf.
  typeset -g POWERLEVEL9K_ASDF_JULIA_FOREGROUND=70
  # typeset -g POWERLEVEL9K_ASDF_JULIA_VISUAL_IDENTIFIER_EXPANSION='⭐'
  # typeset -g POWERLEVEL9K_ASDF_JULIA_SHOW_ON_UPGLOB='*.foo|*.bar'

  ##########[ nordvpn: nordvpn connection status, linux only (https://nordvpn.com/) ]###########
  # NordVPN connection indicator color.
  typeset -g POWERLEVEL9K_NORDVPN_FOREGROUND=39
  # Hide NordVPN connection indicator when not connected.
  typeset -g POWERLEVEL9K_NORDVPN_{DISCONNECTED,CONNECTING,DISCONNECTING}_CONTENT_EXPANSION=
  typeset -g POWERLEVEL9K_NORDVPN_{DISCONNECTED,CONNECTING,DISCONNECTING}_VISUAL_IDENTIFIER_EXPANSION=
  # Custom icon.
  # typeset -g POWERLEVEL9K_NORDVPN_VISUAL_IDENTIFIER_EXPANSION='⭐'

  #################[ ranger: ranger shell (https://github.com/ranger/ranger) ]##################
  # Ranger shell color.
  typeset -g POWERLEVEL9K_RANGER_FOREGROUND=178
  # Custom icon.
  # typeset -g POWERLEVEL9K_RANGER_VISUAL_IDENTIFIER_EXPANSION='⭐'
  
  ####################[ yazi: yazi shell (https://github.com/sxyazi/yazi) ]#####################
  # Yazi shell color.
  typeset -g POWERLEVEL9K_YAZI_FOREGROUND=178
  # Custom icon.
  # typeset -g POWERLEVEL9K_YAZI_VISUAL_IDENTIFIER_EXPANSION='⭐'

  ######################[ nnn: nnn shell (https://github.com/jarun/nnn) ]#######################
  # Nnn shell color.
  typeset -g POWERLEVEL9K_NNN_FOREGROUND=72
  # Custom icon.
  # typeset -g POWERLEVEL9K_NNN_VISUAL_IDENTIFIER_EXPANSION='⭐'

  ######################[ lf: lf shell (https://github.com/gokcehan/lf) ]#######################
  # lf shell color.
  typeset -g POWERLEVEL9K_LF_FOREGROUND=72
  # Custom icon.
  # typeset -g POWERLEVEL9K_LF_VISUAL_IDENTIFIER_EXPANSION='⭐'

  ##################[ xplr: xplr shell (https://github.com/sayanarijit/xplr) ]##################
  # xplr shell color.
  typeset -g POWERLEVEL9K_XPLR_FOREGROUND=72
  # Custom icon.
  # typeset -g POWERLEVEL9K_XPLR_VISUAL_IDENTIFIER_EXPANSION='⭐'

  ###########################[ vim_shell: vim shell indicator (:sh) ]###########################
  # Vim shell indicator color.
  typeset -g POWERLEVEL9K_VIM_SHELL_FOREGROUND=34
  # Custom icon.
  # typeset -g POWERLEVEL9K_VIM_SHELL_VISUAL_IDENTIFIER_EXPANSION='⭐'

  ######[ midnight_commander: midnight commander shell (https://midnight-commander.org/) ]######
  # Midnight Commander shell color.
  typeset -g POWERLEVEL9K_MIDNIGHT_COMMANDER_FOREGROUND=178
  # Custom icon.
  # typeset -g POWERLEVEL9K_MIDNIGHT_COMMANDER_VISUAL_IDENTIFIER_EXPANSION='⭐'

  #[ nix_shell: nix shell (https://nixos.org/nixos/nix-pills/developing-with-nix-shell.html) ]##
  # Nix shell color.
  typeset -g POWERLEVEL9K_NIX_SHELL_FOREGROUND=74

  # Display the icon of nix_shell if PATH contains a subdirectory of /nix/store.
  # typeset -g POWERLEVEL9K_NIX_SHELL_INFER_FROM_PATH=false

  # Tip: If you want to see just the icon without "pure" and "impure", uncomment the next line.
  # typeset -g POWERLEVEL9K_NIX_SHELL_CONTENT_EXPANSION=

  # Custom icon.
  # typeset -g POWERLEVEL9K_NIX_SHELL_VISUAL_IDENTIFIER_EXPANSION='⭐'

  ##################[ chezmoi_shell: chezmoi shell (https://www.chezmoi.io/) ]##################
  # chezmoi shell color.
  typeset -g POWERLEVEL9K_CHEZMOI_SHELL_FOREGROUND=33
  # Custom icon.
  # typeset -g POWERLEVEL9K_CHEZMOI_SHELL_VISUAL_IDENTIFIER_EXPANSION='⭐'

  ##################################[ disk_usage: disk usage ]##################################
  # Colors for different levels of disk usage.
  typeset -g POWERLEVEL9K_DISK_USAGE_NORMAL_FOREGROUND=35
  typeset -g POWERLEVEL9K_DISK_USAGE_WARNING_FOREGROUND=220
  typeset -g POWERLEVEL9K_DISK_USAGE_CRITICAL_FOREGROUND=160
  # Thresholds for different levels of disk usage (percentage points).
  typeset -g POWERLEVEL9K_DISK_USAGE_WARNING_LEVEL=90
  typeset -g POWERLEVEL9K_DISK_USAGE_CRITICAL_LEVEL=95
  # If set to true, hide disk usage when below $POWERLEVEL9K_DISK_USAGE_WARNING_LEVEL percent.
  typeset -g POWERLEVEL9K_DISK_USAGE_ONLY_WARNING=false
  # Custom icon.
  # typeset -g POWERLEVEL9K_DISK_USAGE_VISUAL_IDENTIFIER_EXPANSION='⭐'

  ###########[ vi_mode: vi mode (you don't need this if you've enabled prompt_char) ]###########
  # Text and color for normal (a.k.a. command) vi mode.
  typeset -g POWERLEVEL9K_VI_COMMAND_MODE_STRING=NORMAL
  typeset -g POWERLEVEL9K_VI_MODE_NORMAL_FOREGROUND=106
  # Text and color for visual vi mode.
  typeset -g POWERLEVEL9K_VI_VISUAL_MODE_STRING=VISUAL
  typeset -g POWERLEVEL9K_VI_MODE_VISUAL_FOREGROUND=68
  # Text and color for overtype (a.k.a. overwrite and replace) vi mode.
  typeset -g POWERLEVEL9K_VI_OVERWRITE_MODE_STRING=OVERTYPE
  typeset -g POWERLEVEL9K_VI_MODE_OVERWRITE_FOREGROUND=172
  # Text and color for insert vi mode.
  typeset -g POWERLEVEL9K_VI_INSERT_MODE_STRING=
  typeset -g POWERLEVEL9K_VI_MODE_INSERT_FOREGROUND=66
  # Custom icon.
  # typeset -g POWERLEVEL9K_VI_MODE_VISUAL_IDENTIFIER_EXPANSION='⭐'

  ######################################[ ram: free RAM ]#######################################
  # RAM color.
  typeset -g POWERLEVEL9K_RAM_FOREGROUND=66
  # Custom icon.
  # typeset -g POWERLEVEL9K_RAM_VISUAL_IDENTIFIER_EXPANSION='⭐'

  #####################################[ swap: used swap ]######################################
  # Swap color.
  typeset -g POWERLEVEL9K_SWAP_FOREGROUND=96
  # Custom icon.
  # typeset -g POWERLEVEL9K_SWAP_VISUAL_IDENTIFIER_EXPANSION='⭐'

  ######################################[ load: CPU load ]######################################
  # Show average CPU load over this many last minutes. Valid values are 1, 5 and 15.
  typeset -g POWERLEVEL9K_LOAD_WHICH=5
  # Load color when load is under 50%.
  typeset -g POWERLEVEL9K_LOAD_NORMAL_FOREGROUND=66
  # Load color when load is between 50% and 70%.
  typeset -g POWERLEVEL9K_LOAD_WARNING_FOREGROUND=178
  # Load color when load is over 70%.
  typeset -g POWERLEVEL9K_LOAD_CRITICAL_FOREGROUND=166
  # Custom icon.
  # typeset -g POWERLEVEL9K_LOAD_VISUAL_IDENTIFIER_EXPANSION='⭐'

  ################[ todo: todo items (https://github.com/todotxt/todo.txt-cli) ]################
  # Todo color.
  typeset -g POWERLEVEL9K_TODO_FOREGROUND=110
  # Hide todo when the total number of tasks is zero.
  typeset -g POWERLEVEL9K_TODO_HIDE_ZERO_TOTAL=true
  # Hide todo when the number of tasks after filtering is zero.
  typeset -g POWERLEVEL9K_TODO_HIDE_ZERO_FILTERED=false

  # Todo format. The following parameters are available within the expansion.
  #
  # - P9K_TODO_TOTAL_TASK_COUNT     The total number of tasks.
  # - P9K_TODO_FILTERED_TASK_COUNT  The number of tasks after filtering.
  #
  # These variables correspond to the last line of the output of `todo.sh -p ls`:
  #
  #   TODO: 24 of 42 tasks shown
  #
  # Here 24 is P9K_TODO_FILTERED_TASK_COUNT and 42 is P9K_TODO_TOTAL_TASK_COUNT.
  #
  # typeset -g POWERLEVEL9K_TODO_CONTENT_EXPANSION='$P9K_TODO_FILTERED_TASK_COUNT'

  # Custom icon.
  # typeset -g POWERLEVEL9K_TODO_VISUAL_IDENTIFIER_EXPANSION='⭐'

  ###########[ timewarrior: timewarrior tracking status (https://timewarrior.net/) ]############
  # Timewarrior color.
  typeset -g POWERLEVEL9K_TIMEWARRIOR_FOREGROUND=110
  # If the tracked task is longer than 24 characters, truncate and append "…".
  # Tip: To always display tasks without truncation, delete the following parameter.
  # Tip: To hide task names and display just the icon when time tracking is enabled, set the
  # value of the following parameter to "".
  typeset -g POWERLEVEL9K_TIMEWARRIOR_CONTENT_EXPANSION='${P9K_CONTENT:0:24}${${P9K_CONTENT:24}:+…}'

  # Custom icon.
  # typeset -g POWERLEVEL9K_TIMEWARRIOR_VISUAL_IDENTIFIER_EXPANSION='⭐'

  ##############[ taskwarrior: taskwarrior task count (https://taskwarrior.org/) ]##############
  # Taskwarrior color.
  typeset -g POWERLEVEL9K_TASKWARRIOR_FOREGROUND=74

  # Taskwarrior segment format. The following parameters are available within the expansion.
  #
  # - P9K_TASKWARRIOR_PENDING_COUNT   The number of pending tasks: `task +PENDING count`.
  # - P9K_TASKWARRIOR_OVERDUE_COUNT   The number of overdue tasks: `task +OVERDUE count`.
  #
  # Zero values are represented as empty parameters.
  #
  # The default format:
  #
  #   '${P9K_TASKWARRIOR_OVERDUE_COUNT:+"!$P9K_TASKWARRIOR_OVERDUE_COUNT/"}$P9K_TASKWARRIOR_PENDING_COUNT'
  #
  # typeset -g POWERLEVEL9K_TASKWARRIOR_CONTENT_EXPANSION='$P9K_TASKWARRIOR_PENDING_COUNT'

  # Custom icon.
  # typeset -g POWERLEVEL9K_TASKWARRIOR_VISUAL_IDENTIFIER_EXPANSION='⭐'

  ######[ per_directory_history: Oh My Zsh per-directory-history local/global indicator ]#######
  # Color when using local/global history.
  typeset -g POWERLEVEL9K_PER_DIRECTORY_HISTORY_LOCAL_FOREGROUND=135
  typeset -g POWERLEVEL9K_PER_DIRECTORY_HISTORY_GLOBAL_FOREGROUND=130

  # Tip: Uncomment the next two lines to hide "local"/"global" text and leave just the icon.
  # typeset -g POWERLEVEL9K_PER_DIRECTORY_HISTORY_LOCAL_CONTENT_EXPANSION=''
  # typeset -g POWERLEVEL9K_PER_DIRECTORY_HISTORY_GLOBAL_CONTENT_EXPANSION=''

  # Custom icon.
  # typeset -g POWERLEVEL9K_PER_DIRECTORY_HISTORY_LOCAL_VISUAL_IDENTIFIER_EXPANSION='⭐'
  # typeset -g POWERLEVEL9K_PER_DIRECTORY_HISTORY_GLOBAL_VISUAL_IDENTIFIER_EXPANSION='⭐'

  ################################[ cpu_arch: CPU architecture ]################################
  # CPU architecture color.
  typeset -g POWERLEVEL9K_CPU_ARCH_FOREGROUND=172

  # Hide the segment when on a specific CPU architecture.
  # typeset -g POWERLEVEL9K_CPU_ARCH_X86_64_CONTENT_EXPANSION=
  # typeset -g POWERLEVEL9K_CPU_ARCH_X86_64_VISUAL_IDENTIFIER_EXPANSION=

  # Custom icon.
  # typeset -g POWERLEVEL9K_CPU_ARCH_VISUAL_IDENTIFIER_EXPANSION='⭐'

  ##################################[ context: user@hostname ]##################################
  # Context color when running with privileges.
  typeset -g POWERLEVEL9K_CONTEXT_ROOT_FOREGROUND=178
  # Context color in SSH without privileges.
  typeset -g POWERLEVEL9K_CONTEXT_{REMOTE,REMOTE_SUDO}_FOREGROUND=180
  # Default context color (no privileges, no SSH).
  typeset -g POWERLEVEL9K_CONTEXT_FOREGROUND=180

  # Context format when running with privileges: bold user@hostname.
  typeset -g POWERLEVEL9K_CONTEXT_ROOT_TEMPLATE='%B%n@%m'
  # Context format when in SSH without privileges: user@hostname.
  typeset -g POWERLEVEL9K_CONTEXT_{REMOTE,REMOTE_SUDO}_TEMPLATE='%n@%m'
  # Default context format (no privileges, no SSH): user@hostname.
  typeset -g POWERLEVEL9K_CONTEXT_TEMPLATE='%n@%m'

  # Don't show context unless running with privileges or in SSH.
  # Tip: Remove the next line to always show context.
  typeset -g POWERLEVEL9K_CONTEXT_{DEFAULT,SUDO}_{CONTENT,VISUAL_IDENTIFIER}_EXPANSION=

  # Custom icon.
  # typeset -g POWERLEVEL9K_CONTEXT_VISUAL_IDENTIFIER_EXPANSION='⭐'
  # Custom prefix.
  # typeset -g POWERLEVEL9K_CONTEXT_PREFIX='%244Fwith '

  ###[ virtualenv: python virtual environment (https://docs.python.org/3/library/venv.html) ]###
  # Python virtual environment color.
  typeset -g POWERLEVEL9K_VIRTUALENV_FOREGROUND=37
  # Don't show Python version next to the virtual environment name.
  typeset -g POWERLEVEL9K_VIRTUALENV_SHOW_PYTHON_VERSION=false
  # If set to "false", won't show virtualenv if pyenv is already shown.
  # If set to "if-different", won't show virtualenv if it's the same as pyenv.
  typeset -g POWERLEVEL9K_VIRTUALENV_SHOW_WITH_PYENV=false
  # Separate environment name from Python version only with a space.
  typeset -g POWERLEVEL9K_VIRTUALENV_{LEFT,RIGHT}_DELIMITER=
  # Custom icon.
  typeset -g POWERLEVEL9K_VIRTUALENV_VISUAL_IDENTIFIER_EXPANSION='🐍'

  #####################[ anaconda: conda environment (https://conda.io/) ]######################
  # Anaconda environment color.
  typeset -g POWERLEVEL9K_ANACONDA_FOREGROUND=37

  # Anaconda segment format. The following parameters are available within the expansion.
  #
  # - CONDA_PREFIX                 Absolute path to the active Anaconda/Miniconda environment.
  # - CONDA_DEFAULT_ENV            Name of the active Anaconda/Miniconda environment.
  # - CONDA_PROMPT_MODIFIER        Configurable prompt modifier (see below).
  # - P9K_ANACONDA_PYTHON_VERSION  Current python version (python --version).
  #
  # CONDA_PROMPT_MODIFIER can be configured with the following command:
  #
  #   conda config --set env_prompt '({default_env}) '
  #
  # The last argument is a Python format string that can use the following variables:
  #
  # - prefix       The same as CONDA_PREFIX.
  # - default_env  The same as CONDA_DEFAULT_ENV.
  # - name         The last segment of CONDA_PREFIX.
  # - stacked_env  Comma-separated list of names in the environment stack. The first element is
  #                always the same as default_env.
  #
  # Note: '({default_env}) ' is the default value of env_prompt.
  #
  # The default value of POWERLEVEL9K_ANACONDA_CONTENT_EXPANSION expands to $CONDA_PROMPT_MODIFIER
  # without the surrounding parentheses, or to the last path component of CONDA_PREFIX if the former
  # is empty.
  typeset -g POWERLEVEL9K_ANACONDA_CONTENT_EXPANSION='${${${${CONDA_PROMPT_MODIFIER#\(}% }%\)}:-${CONDA_PREFIX:t}}'

  # Custom icon.
  typeset -g POWERLEVEL9K_ANACONDA_VISUAL_IDENTIFIER_EXPANSION='🐍'

  ################[ pyenv: python environment (https://github.com/pyenv/pyenv) ]################
  # Pyenv color.
  typeset -g POWERLEVEL9K_PYENV_FOREGROUND=37
  # Hide python version if it doesn't come from one of these sources.
  typeset -g POWERLEVEL9K_PYENV_SOURCES=(shell local global)
  # If set to false, hide python version if it's the same as global:
  # $(pyenv version-name) == $(pyenv global).
  typeset -g POWERLEVEL9K_PYENV_PROMPT_ALWAYS_SHOW=false
  # If set to false, hide python version if it's equal to "system".
  typeset -g POWERLEVEL9K_PYENV_SHOW_SYSTEM=true

  # Pyenv segment format. The following parameters are available within the expansion.
  #
  # - P9K_CONTENT                Current pyenv environment (pyenv version-name).
  # - P9K_PYENV_PYTHON_VERSION   Current python version (python --version).
  #
  # The default format has the following logic:
  #
  # 1. Display just "$P9K_CONTENT" if it's equal to "$P9K_PYENV_PYTHON_VERSION" or
  #    starts with "$P9K_PYENV_PYTHON_VERSION/".
  # 2. Otherwise display "$P9K_CONTENT $P9K_PYENV_PYTHON_VERSION".
  typeset -g POWERLEVEL9K_PYENV_CONTENT_EXPANSION='${P9K_CONTENT}${${P9K_CONTENT:#$P9K_PYENV_PYTHON_VERSION(|/*)}:+ $P9K_PYENV_PYTHON_VERSION}'

  # Custom icon.
  typeset -g POWERLEVEL9K_PYENV_VISUAL_IDENTIFIER_EXPANSION='🐍'

  ################[ goenv: go environment (https://github.com/syndbg/goenv) ]################
  # Goenv color.
  typeset -g POWERLEVEL9K_GOENV_FOREGROUND=37
  # Hide go version if it doesn't come from one of these sources.
  typeset -g POWERLEVEL9K_GOENV_SOURCES=(shell local global)
  # If set to false, hide go version if it's the same as global:
  # $(goenv version-name) == $(goenv global).
  typeset -g POWERLEVEL9K_GOENV_PROMPT_ALWAYS_SHOW=false
  # If set to false, hide go version if it's equal to "system".
  typeset -g POWERLEVEL9K_GOENV_SHOW_SYSTEM=true
  # Custom icon.
  # typeset -g POWERLEVEL9K_GOENV_VISUAL_IDENTIFIER_EXPANSION='⭐'

  ##########[ nodenv: node.js version from nodenv (https://github.com/nodenv/nodenv) ]##########
  # Nodenv color.
  typeset -g POWERLEVEL9K_NODENV_FOREGROUND=70
  # Hide node version if it doesn't come from one of these sources.
  typeset -g POWERLEVEL9K_NODENV_SOURCES=(shell local global)
  # If set to false, hide node version if it's the same as global:
  # $(nodenv version-name) == $(nodenv global).
  typeset -g POWERLEVEL9K_NODENV_PROMPT_ALWAYS_SHOW=false
  # If set to false, hide node version if it's equal to "system".
  typeset -g POWERLEVEL9K_NODENV_SHOW_SYSTEM=true
  # Custom icon.
  # typeset -g POWERLEVEL9K_NODENV_VISUAL_IDENTIFIER_EXPANSION='⭐'

  ##############[ nvm: node.js version from nvm (https://github.com/nvm-sh/nvm) ]###############
  # Nvm color.
  typeset -g POWERLEVEL9K_NVM_FOREGROUND=70
  # If set to false, hide node version if it's the same as default:
  # $(nvm version current) == $(nvm version default).
  typeset -g POWERLEVEL9K_NVM_PROMPT_ALWAYS_SHOW=false
  # If set to false, hide node version if it's equal to "system".
  typeset -g POWERLEVEL9K_NVM_SHOW_SYSTEM=true
  # Custom icon.
  # typeset -g POWERLEVEL9K_NVM_VISUAL_IDENTIFIER_EXPANSION='⭐'

  ############[ nodeenv: node.js environment (https://github.com/ekalinin/nodeenv) ]############
  # Nodeenv color.
  typeset -g POWERLEVEL9K_NODEENV_FOREGROUND=70
  # Don't show Node version next to the environment name.
  typeset -g POWERLEVEL9K_NODEENV_SHOW_NODE_VERSION=false
  # Separate environment name from Node version only with a space.
  typeset -g POWERLEVEL9K_NODEENV_{LEFT,RIGHT}_DELIMITER=
  # Custom icon.
  # typeset -g POWERLEVEL9K_NODEENV_VISUAL_IDENTIFIER_EXPANSION='⭐'

  ##############################[ node_version: node.js version ]###############################
  # Node version color.
  typeset -g POWERLEVEL9K_NODE_VERSION_FOREGROUND=70
  # Show node version only when in a directory tree containing package.json.
  typeset -g POWERLEVEL9K_NODE_VERSION_PROJECT_ONLY=true
  # Custom icon.
  # typeset -g POWERLEVEL9K_NODE_VERSION_VISUAL_IDENTIFIER_EXPANSION='⭐'

  #######################[ go_version: go version (https://golang.org) ]########################
  # Go version color.
  typeset -g POWERLEVEL9K_GO_VERSION_FOREGROUND=37
  # Show go version only when in a go project subdirectory.
  typeset -g POWERLEVEL9K_GO_VERSION_PROJECT_ONLY=true
  # Custom icon.
  # typeset -g POWERLEVEL9K_GO_VERSION_VISUAL_IDENTIFIER_EXPANSION='⭐'

  #################[ rust_version: rustc version (https://www.rust-lang.org) ]##################
  # Rust version color.
  typeset -g POWERLEVEL9K_RUST_VERSION_FOREGROUND=37
  # Show rust version only when in a rust project subdirectory.
  typeset -g POWERLEVEL9K_RUST_VERSION_PROJECT_ONLY=true
  # Custom icon.
  # typeset -g POWERLEVEL9K_RUST_VERSION_VISUAL_IDENTIFIER_EXPANSION='⭐'

  ###############[ dotnet_version: .NET version (https://dotnet.microsoft.com) ]################
  # .NET version color.
  typeset -g POWERLEVEL9K_DOTNET_VERSION_FOREGROUND=134
  # Show .NET version only when in a .NET project subdirectory.
  typeset -g POWERLEVEL9K_DOTNET_VERSION_PROJECT_ONLY=true
  # Custom icon.
  # typeset -g POWERLEVEL9K_DOTNET_VERSION_VISUAL_IDENTIFIER_EXPANSION='⭐'

  #####################[ php_version: php version (https://www.php.net/) ]######################
  # PHP version color.
  typeset -g POWERLEVEL9K_PHP_VERSION_FOREGROUND=99
  # Show PHP version only when in a PHP project subdirectory.
  typeset -g POWERLEVEL9K_PHP_VERSION_PROJECT_ONLY=true
  # Custom icon.
  # typeset -g POWERLEVEL9K_PHP_VERSION_VISUAL_IDENTIFIER_EXPANSION='⭐'

  ##########[ laravel_version: laravel php framework version (https://laravel.com/) ]###########
  # Laravel version color.
  typeset -g POWERLEVEL9K_LARAVEL_VERSION_FOREGROUND=161
  # Custom icon.
  # typeset -g POWERLEVEL9K_LARAVEL_VERSION_VISUAL_IDENTIFIER_EXPANSION='⭐'

  ####################[ java_version: java version (https://www.java.com/) ]####################
  # Java version color.
  typeset -g POWERLEVEL9K_JAVA_VERSION_FOREGROUND=32
  # Show java version only when in a java project subdirectory.
  typeset -g POWERLEVEL9K_JAVA_VERSION_PROJECT_ONLY=true
  # Show brief version.
  typeset -g POWERLEVEL9K_JAVA_VERSION_FULL=false
  # Custom icon.
  # typeset -g POWERLEVEL9K_JAVA_VERSION_VISUAL_IDENTIFIER_EXPANSION='⭐'

  ###[ package: name@version from package.json (https://docs.npmjs.com/files/package.json) ]####
  # Package color.
  typeset -g POWERLEVEL9K_PACKAGE_FOREGROUND=117
  # Package format. The following parameters are available within the expansion.
  #
  # - P9K_PACKAGE_NAME     The value of `name` field in package.json.
  # - P9K_PACKAGE_VERSION  The value of `version` field in package.json.
  #
  # typeset -g POWERLEVEL9K_PACKAGE_CONTENT_EXPANSION='${P9K_PACKAGE_NAME//\%/%%}@${P9K_PACKAGE_VERSION//\%/%%}'
  # Custom icon.
  # typeset -g POWERLEVEL9K_PACKAGE_VISUAL_IDENTIFIER_EXPANSION='⭐'

  #############[ rbenv: ruby version from rbenv (https://github.com/rbenv/rbenv) ]##############
  # Rbenv color.
  typeset -g POWERLEVEL9K_RBENV_FOREGROUND=168
  # Hide ruby version if it doesn't come from one of these sources.
  typeset -g POWERLEVEL9K_RBENV_SOURCES=(shell local global)
  # If set to false, hide ruby version if it's the same as global:
  # $(rbenv version-name) == $(rbenv global).
  typeset -g POWERLEVEL9K_RBENV_PROMPT_ALWAYS_SHOW=false
  # If set to false, hide ruby version if it's equal to "system".
  typeset -g POWERLEVEL9K_RBENV_SHOW_SYSTEM=true
  # Custom icon.
  # typeset -g POWERLEVEL9K_RBENV_VISUAL_IDENTIFIER_EXPANSION='⭐'

  #######################[ rvm: ruby version from rvm (https://rvm.io) ]########################
  # Rvm color.
  typeset -g POWERLEVEL9K_RVM_FOREGROUND=168
  # Don't show @gemset at the end.
  typeset -g POWERLEVEL9K_RVM_SHOW_GEMSET=false
  # Don't show ruby- at the front.
  typeset -g POWERLEVEL9K_RVM_SHOW_PREFIX=false
  # Custom icon.
  # typeset -g POWERLEVEL9K_RVM_VISUAL_IDENTIFIER_EXPANSION='⭐'

  ###########[ fvm: flutter version management (https://github.com/leoafarias/fvm) ]############
  # Fvm color.
  typeset -g POWERLEVEL9K_FVM_FOREGROUND=38
  # Custom icon.
  # typeset -g POWERLEVEL9K_FVM_VISUAL_IDENTIFIER_EXPANSION='⭐'

  ##########[ luaenv: lua version from luaenv (https://github.com/cehoffman/luaenv) ]###########
  # Lua color.
  typeset -g POWERLEVEL9K_LUAENV_FOREGROUND=32
  # Hide lua version if it doesn't come from one of these sources.
  typeset -g POWERLEVEL9K_LUAENV_SOURCES=(shell local global)
  # If set to false, hide lua version if it's the same as global:
  # $(luaenv version-name) == $(luaenv global).
  typeset -g POWERLEVEL9K_LUAENV_PROMPT_ALWAYS_SHOW=false
  # If set to false, hide lua version if it's equal to "system".
  typeset -g POWERLEVEL9K_LUAENV_SHOW_SYSTEM=true
  # Custom icon.
  # typeset -g POWERLEVEL9K_LUAENV_VISUAL_IDENTIFIER_EXPANSION='⭐'

  ###############[ jenv: java version from jenv (https://github.com/jenv/jenv) ]################
  # Java color.
  typeset -g POWERLEVEL9K_JENV_FOREGROUND=32
  # Hide java version if it doesn't come from one of these sources.
  typeset -g POWERLEVEL9K_JENV_SOURCES=(shell local global)
  # If set to false, hide java version if it's the same as global:
  # $(jenv version-name) == $(jenv global).
  typeset -g POWERLEVEL9K_JENV_PROMPT_ALWAYS_SHOW=false
  # If set to false, hide java version if it's equal to "system".
  typeset -g POWERLEVEL9K_JENV_SHOW_SYSTEM=true
  # Custom icon.
  # typeset -g POWERLEVEL9K_JENV_VISUAL_IDENTIFIER_EXPANSION='⭐'

  ###########[ plenv: perl version from plenv (https://github.com/tokuhirom/plenv) ]############
  # Perl color.
  typeset -g POWERLEVEL9K_PLENV_FOREGROUND=67
  # Hide perl version if it doesn't come from one of these sources.
  typeset -g POWERLEVEL9K_PLENV_SOURCES=(shell local global)
  # If set to false, hide perl version if it's the same as global:
  # $(plenv version-name) == $(plenv global).
  typeset -g POWERLEVEL9K_PLENV_PROMPT_ALWAYS_SHOW=false
  # If set to false, hide perl version if it's equal to "system".
  typeset -g POWERLEVEL9K_PLENV_SHOW_SYSTEM=true
  # Custom icon.
  # typeset -g POWERLEVEL9K_PLENV_VISUAL_IDENTIFIER_EXPANSION='⭐'

  ###########[ perlbrew: perl version from perlbrew (https://github.com/gugod/App-perlbrew) ]############
  # Perlbrew color.
  typeset -g POWERLEVEL9K_PERLBREW_FOREGROUND=67
  # Show perlbrew version only when in a perl project subdirectory.
  typeset -g POWERLEVEL9K_PERLBREW_PROJECT_ONLY=true
  # Don't show "perl-" at the front.
  typeset -g POWERLEVEL9K_PERLBREW_SHOW_PREFIX=false
  # Custom icon.
  # typeset -g POWERLEVEL9K_PERLBREW_VISUAL_IDENTIFIER_EXPANSION='⭐'

  ############[ phpenv: php version from phpenv (https://github.com/phpenv/phpenv) ]############
  # PHP color.
  typeset -g POWERLEVEL9K_PHPENV_FOREGROUND=99
  # Hide php version if it doesn't come from one of these sources.
  typeset -g POWERLEVEL9K_PHPENV_SOURCES=(shell local global)
  # If set to false, hide php version if it's the same as global:
  # $(phpenv version-name) == $(phpenv global).
  typeset -g POWERLEVEL9K_PHPENV_PROMPT_ALWAYS_SHOW=false
  # If set to false, hide php version if it's equal to "system".
  typeset -g POWERLEVEL9K_PHPENV_SHOW_SYSTEM=true
  # Custom icon.
  # typeset -g POWERLEVEL9K_PHPENV_VISUAL_IDENTIFIER_EXPANSION='⭐'

  #######[ scalaenv: scala version from scalaenv (https://github.com/scalaenv/scalaenv) ]#######
  # Scala color.
  typeset -g POWERLEVEL9K_SCALAENV_FOREGROUND=160
  # Hide scala version if it doesn't come from one of these sources.
  typeset -g POWERLEVEL9K_SCALAENV_SOURCES=(shell local global)
  # If set to false, hide scala version if it's the same as global:
  # $(scalaenv version-name) == $(scalaenv global).
  typeset -g POWERLEVEL9K_SCALAENV_PROMPT_ALWAYS_SHOW=false
  # If set to false, hide scala version if it's equal to "system".
  typeset -g POWERLEVEL9K_SCALAENV_SHOW_SYSTEM=true
  # Custom icon.
  # typeset -g POWERLEVEL9K_SCALAENV_VISUAL_IDENTIFIER_EXPANSION='⭐'

  ##########[ haskell_stack: haskell version from stack (https://haskellstack.org/) ]###########
  # Haskell color.
  typeset -g POWERLEVEL9K_HASKELL_STACK_FOREGROUND=172
  # Hide haskell version if it doesn't come from one of these sources.
  #
  #   shell:  version is set by STACK_YAML
  #   local:  version is set by stack.yaml up the directory tree
  #   global: version is set by the implicit global project (~/.stack/global-project/stack.yaml)
  typeset -g POWERLEVEL9K_HASKELL_STACK_SOURCES=(shell local)
  # If set to false, hide haskell version if it's the same as in the implicit global project.
  typeset -g POWERLEVEL9K_HASKELL_STACK_ALWAYS_SHOW=true
  # Custom icon.
  # typeset -g POWERLEVEL9K_HASKELL_STACK_VISUAL_IDENTIFIER_EXPANSION='⭐'

  ################[ terraform: terraform workspace (https://www.terraform.io) ]#################
  # Don't show terraform workspace if it's literally "default".
  typeset -g POWERLEVEL9K_TERRAFORM_SHOW_DEFAULT=false
  # POWERLEVEL9K_TERRAFORM_CLASSES is an array with even number of elements. The first element
  # in each pair defines a pattern against which the current terraform workspace gets matched.
  # More specifically, it's P9K_CONTENT prior to the application of context expansion (see below)
  # that gets matched. If you unset all POWERLEVEL9K_TERRAFORM_*CONTENT_EXPANSION parameters,
  # you'll see this value in your prompt. The second element of each pair in
  # POWERLEVEL9K_TERRAFORM_CLASSES defines the workspace class. Patterns are tried in order. The
  # first match wins.
  #
  # For example, given these settings:
  #
  #   typeset -g POWERLEVEL9K_TERRAFORM_CLASSES=(
  #     '*prod*'  PROD
  #     '*test*'  TEST
  #     '*'       OTHER)
  #
  # If your current terraform workspace is "project_test", its class is TEST because "project_test"
  # doesn't match the pattern '*prod*' but does match '*test*'.
  #
  # You can define different colors, icons and content expansions for different classes:
  #
  #   typeset -g POWERLEVEL9K_TERRAFORM_TEST_FOREGROUND=28
  #   typeset -g POWERLEVEL9K_TERRAFORM_TEST_VISUAL_IDENTIFIER_EXPANSION='⭐'
  #   typeset -g POWERLEVEL9K_TERRAFORM_TEST_CONTENT_EXPANSION='> ${P9K_CONTENT} <'
  typeset -g POWERLEVEL9K_TERRAFORM_CLASSES=(
      # '*prod*'  PROD    # These values are examples that are unlikely
      # '*test*'  TEST    # to match your needs. Customize them as needed.
      '*'         OTHER)
  typeset -g POWERLEVEL9K_TERRAFORM_OTHER_FOREGROUND=38
  # typeset -g POWERLEVEL9K_TERRAFORM_OTHER_VISUAL_IDENTIFIER_EXPANSION='⭐'

  #############[ terraform_version: terraform version (https://www.terraform.io) ]##############
  # Terraform version color.
  typeset -g POWERLEVEL9K_TERRAFORM_VERSION_FOREGROUND=38
  # Custom icon.
  # typeset -g POWERLEVEL9K_TERRAFORM_VERSION_VISUAL_IDENTIFIER_EXPANSION='⭐'

  #############[ kubecontext: current kubernetes context (https://kubernetes.io/) ]#############
  # Show kubecontext only when the command you are typing invokes one of these tools.
  # Tip: Remove the next line to always show kubecontext.
  typeset -g POWERLEVEL9K_KUBECONTEXT_SHOW_ON_COMMAND='kubectl|helm|kubens|kubectx|oc|istioctl|kogito|k9s|helmfile|flux|fluxctl|stern|kubeseal|skaffold|kubent|kubecolor|cmctl|sparkctl'

  # Kubernetes context classes for the purpose of using different colors, icons and expansions with
  # different contexts.
  #
  # POWERLEVEL9K_KUBECONTEXT_CLASSES is an array with even number of elements. The first element
  # in each pair defines a pattern against which the current kubernetes context gets matched.
  # More specifically, it's P9K_CONTENT prior to the application of context expansion (see below)
  # that gets matched. If you unset all POWERLEVEL9K_KUBECONTEXT_*CONTENT_EXPANSION parameters,
  # you'll see this value in your prompt. The second element of each pair in
  # POWERLEVEL9K_KUBECONTEXT_CLASSES defines the context class. Patterns are tried in order. The
  # first match wins.
  #
  # For example, given these settings:
  #
  #   typeset -g POWERLEVEL9K_KUBECONTEXT_CLASSES=(
  #     '*prod*'  PROD
  #     '*test*'  TEST
  #     '*'       DEFAULT)
  #
  # If your current kubernetes context is "deathray-testing/default", its class is TEST
  # because "deathray-testing/default" doesn't match the pattern '*prod*' but does match '*test*'.
  #
  # You can define different colors, icons and content expansions for different classes:
  #
  #   typeset -g POWERLEVEL9K_KUBECONTEXT_TEST_FOREGROUND=28
  #   typeset -g POWERLEVEL9K_KUBECONTEXT_TEST_VISUAL_IDENTIFIER_EXPANSION='⭐'
  #   typeset -g POWERLEVEL9K_KUBECONTEXT_TEST_CONTENT_EXPANSION='> ${P9K_CONTENT} <'
  typeset -g POWERLEVEL9K_KUBECONTEXT_CLASSES=(
      # '*prod*'  PROD    # These values are examples that are unlikely
      # '*test*'  TEST    # to match your needs. Customize them as needed.
      '*'       DEFAULT)
  typeset -g POWERLEVEL9K_KUBECONTEXT_DEFAULT_FOREGROUND=134
  # typeset -g POWERLEVEL9K_KUBECONTEXT_DEFAULT_VISUAL_IDENTIFIER_EXPANSION='⭐'

  # Use POWERLEVEL9K_KUBECONTEXT_CONTENT_EXPANSION to specify the content displayed by kubecontext
  # segment. Parameter expansions are very flexible and fast, too. See reference:
  # http://zsh.sourceforge.net/Doc/Release/Expansion.html#Parameter-Expansion.
  #
  # Within the expansion the following parameters are always available:
  #
  # - P9K_CONTENT                The content that would've been displayed if there was no content
  #                              expansion defined.
  # - P9K_KUBECONTEXT_NAME       The current context's name. Corresponds to column NAME in the
  #                              output of `kubectl config get-contexts`.
  # - P9K_KUBECONTEXT_CLUSTER    The current context's cluster. Corresponds to column CLUSTER in the
  #                              output of `kubectl config get-contexts`.
  # - P9K_KUBECONTEXT_NAMESPACE  The current context's namespace. Corresponds to column NAMESPACE
  #                              in the output of `kubectl config get-contexts`. If there is no
  #                              namespace, the parameter is set to "default".
  # - P9K_KUBECONTEXT_USER       The current context's user. Corresponds to column AUTHINFO in the
  #                              output of `kubectl config get-contexts`.
  #
  # If the context points to Google Kubernetes Engine (GKE) or Elastic Kubernetes Service (EKS),
  # the following extra parameters are available:
  #
  # - P9K_KUBECONTEXT_CLOUD_NAME     Either "gke" or "eks".
  # - P9K_KUBECONTEXT_CLOUD_ACCOUNT  Account/project ID.
  # - P9K_KUBECONTEXT_CLOUD_ZONE     Availability zone.
  # - P9K_KUBECONTEXT_CLOUD_CLUSTER  Cluster.
  #
  # P9K_KUBECONTEXT_CLOUD_* parameters are derived from P9K_KUBECONTEXT_CLUSTER. For example,
  # if P9K_KUBECONTEXT_CLUSTER is "gke_my-account_us-east1-a_my-cluster-01":
  #
  #   - P9K_KUBECONTEXT_CLOUD_NAME=gke
  #   - P9K_KUBECONTEXT_CLOUD_ACCOUNT=my-account
  #   - P9K_KUBECONTEXT_CLOUD_ZONE=us-east1-a
  #   - P9K_KUBECONTEXT_CLOUD_CLUSTER=my-cluster-01
  #
  # If P9K_KUBECONTEXT_CLUSTER is "arn:aws:eks:us-east-1:123456789012:cluster/my-cluster-01":
  #
  #   - P9K_KUBECONTEXT_CLOUD_NAME=eks
  #   - P9K_KUBECONTEXT_CLOUD_ACCOUNT=123456789012
  #   - P9K_KUBECONTEXT_CLOUD_ZONE=us-east-1
  #   - P9K_KUBECONTEXT_CLOUD_CLUSTER=my-cluster-01
  typeset -g POWERLEVEL9K_KUBECONTEXT_DEFAULT_CONTENT_EXPANSION=
  # Show P9K_KUBECONTEXT_CLOUD_CLUSTER if it's not empty and fall back to P9K_KUBECONTEXT_NAME.
  POWERLEVEL9K_KUBECONTEXT_DEFAULT_CONTENT_EXPANSION+='${P9K_KUBECONTEXT_CLOUD_CLUSTER:-${P9K_KUBECONTEXT_NAME}}'
  # Append the current context's namespace if it's not "default".
  POWERLEVEL9K_KUBECONTEXT_DEFAULT_CONTENT_EXPANSION+='${${:-/$P9K_KUBECONTEXT_NAMESPACE}:#/default}'

  # Custom prefix.
  # typeset -g POWERLEVEL9K_KUBECONTEXT_PREFIX='%244Fat '

  #[ aws: aws profile (https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-profiles.html) ]#
  # Show aws only when the command you are typing invokes one of these tools.
  # Tip: Remove the next line to always show aws.
  typeset -g POWERLEVEL9K_AWS_SHOW_ON_COMMAND='aws|awless|cdk|terraform|tofu|pulumi|terragrunt'

  # POWERLEVEL9K_AWS_CLASSES is an array with even number of elements. The first element
  # in each pair defines a pattern against which the current AWS profile gets matched.
  # More specifically, it's P9K_CONTENT prior to the application of context expansion (see below)
  # that gets matched. If you unset all POWERLEVEL9K_AWS_*CONTENT_EXPANSION parameters,
  # you'll see this value in your prompt. The second element of each pair in
  # POWERLEVEL9K_AWS_CLASSES defines the profile class. Patterns are tried in order. The
  # first match wins.
  #
  # For example, given these settings:
  #
  #   typeset -g POWERLEVEL9K_AWS_CLASSES=(
  #     '*prod*'  PROD
  #     '*test*'  TEST
  #     '*'       DEFAULT)
  #
  # If your current AWS profile is "company_test", its class is TEST
  # because "company_test" doesn't match the pattern '*prod*' but does match '*test*'.
  #
  # You can define different colors, icons and content expansions for different classes:
  #
  #   typeset -g POWERLEVEL9K_AWS_TEST_FOREGROUND=28
  #   typeset -g POWERLEVEL9K_AWS_TEST_VISUAL_IDENTIFIER_EXPANSION='⭐'
  #   typeset -g POWERLEVEL9K_AWS_TEST_CONTENT_EXPANSION='> ${P9K_CONTENT} <'
  typeset -g POWERLEVEL9K_AWS_CLASSES=(
      # '*prod*'  PROD    # These values are examples that are unlikely
      # '*test*'  TEST    # to match your needs. Customize them as needed.
      '*'       DEFAULT)
  typeset -g POWERLEVEL9K_AWS_DEFAULT_FOREGROUND=208
  # typeset -g POWERLEVEL9K_AWS_DEFAULT_VISUAL_IDENTIFIER_EXPANSION='⭐'

  # AWS segment format. The following parameters are available within the expansion.
  #
  # - P9K_AWS_PROFILE  The name of the current AWS profile.
  # - P9K_AWS_REGION   The region associated with the current AWS profile.
  typeset -g POWERLEVEL9K_AWS_CONTENT_EXPANSION='${P9K_AWS_PROFILE//\%/%%}${P9K_AWS_REGION:+ ${P9K_AWS_REGION//\%/%%}}'

  #[ aws_eb_env: aws elastic beanstalk environment (https://aws.amazon.com/elasticbeanstalk/) ]#
  # AWS Elastic Beanstalk environment color.
  typeset -g POWERLEVEL9K_AWS_EB_ENV_FOREGROUND=70
  # Custom icon.
  # typeset -g POWERLEVEL9K_AWS_EB_ENV_VISUAL_IDENTIFIER_EXPANSION='⭐'

  ##########[ azure: azure account name (https://docs.microsoft.com/en-us/cli/azure) ]##########
  # Show azure only when the command you are typing invokes one of these tools.
  # Tip: Remove the next line to always show azure.
  typeset -g POWERLEVEL9K_AZURE_SHOW_ON_COMMAND='az|terraform|tofu|pulumi|terragrunt'

  # POWERLEVEL9K_AZURE_CLASSES is an array with even number of elements. The first element
  # in each pair defines a pattern against which the current azure account name gets matched.
  # More specifically, it's P9K_CONTENT prior to the application of context expansion (see below)
  # that gets matched. If you unset all POWERLEVEL9K_AZURE_*CONTENT_EXPANSION parameters,
  # you'll see this value in your prompt. The second element of each pair in
  # POWERLEVEL9K_AZURE_CLASSES defines the account class. Patterns are tried in order. The
  # first match wins.
  #
  # For example, given these settings:
  #
  #   typeset -g POWERLEVEL9K_AZURE_CLASSES=(
  #     '*prod*'  PROD
  #     '*test*'  TEST
  #     '*'       OTHER)
  #
  # If your current azure account is "company_test", its class is TEST because "company_test"
  # doesn't match the pattern '*prod*' but does match '*test*'.
  #
  # You can define different colors, icons and content expansions for different classes:
  #
  #   typeset -g POWERLEVEL9K_AZURE_TEST_FOREGROUND=28
  #   typeset -g POWERLEVEL9K_AZURE_TEST_VISUAL_IDENTIFIER_EXPANSION='⭐'
  #   typeset -g POWERLEVEL9K_AZURE_TEST_CONTENT_EXPANSION='> ${P9K_CONTENT} <'
  typeset -g POWERLEVEL9K_AZURE_CLASSES=(
      # '*prod*'  PROD    # These values are examples that are unlikely
      # '*test*'  TEST    # to match your needs. Customize them as needed.
      '*'         OTHER)

  # Azure account name color.
  typeset -g POWERLEVEL9K_AZURE_OTHER_FOREGROUND=32
  # Custom icon.
  # typeset -g POWERLEVEL9K_AZURE_OTHER_VISUAL_IDENTIFIER_EXPANSION='⭐'

  ##########[ gcloud: google cloud account and project (https://cloud.google.com/) ]###########
  # Show gcloud only when the command you are typing invokes one of these tools.
  # Tip: Remove the next line to always show gcloud.
  typeset -g POWERLEVEL9K_GCLOUD_SHOW_ON_COMMAND='gcloud|gcs|gsutil'
   # Google cloud color.
  typeset -g POWERLEVEL9K_GCLOUD_FOREGROUND=32

  # Google cloud format. Change the value of POWERLEVEL9K_GCLOUD_PARTIAL_CONTENT_EXPANSION and/or
  # POWERLEVEL9K_GCLOUD_COMPLETE_CONTENT_EXPANSION if the default is too verbose or not informative
  # enough. You can use the following parameters in the expansions. Each of them corresponds to the
  # output of `gcloud` tool.
  #
  #   Parameter                | Source
  #   -------------------------|--------------------------------------------------------------------
  #   P9K_GCLOUD_CONFIGURATION | gcloud config configurations list --format='value(name)'
  #   P9K_GCLOUD_ACCOUNT       | gcloud config get-value account
  #   P9K_GCLOUD_PROJECT_ID    | gcloud config get-value project
  #   P9K_GCLOUD_PROJECT_NAME  | gcloud projects describe $P9K_GCLOUD_PROJECT_ID --format='value(name)'
  #
  # Note: ${VARIABLE//\%/%%} expands to ${VARIABLE} with all occurrences of '%' replaced with '%%'.
  #
  # Obtaining project name requires sending a request to Google servers. This can take a long time
  # and even fail. When project name is unknown, P9K_GCLOUD_PROJECT_NAME is not set and gcloud
  # prompt segment is in state PARTIAL. When project name gets known, P9K_GCLOUD_PROJECT_NAME gets
  # set and gcloud prompt segment transitions to state COMPLETE.
  #
  # You can customize the format, icon and colors of gcloud segment separately for states PARTIAL
  # and COMPLETE. You can also hide gcloud in state PARTIAL by setting
  # POWERLEVEL9K_GCLOUD_PARTIAL_VISUAL_IDENTIFIER_EXPANSION and
  # POWERLEVEL9K_GCLOUD_PARTIAL_CONTENT_EXPANSION to empty.
  typeset -g POWERLEVEL9K_GCLOUD_PARTIAL_CONTENT_EXPANSION='${P9K_GCLOUD_PROJECT_ID//\%/%%}'
  typeset -g POWERLEVEL9K_GCLOUD_COMPLETE_CONTENT_EXPANSION='${P9K_GCLOUD_PROJECT_NAME//\%/%%}'

  # Send a request to Google (by means of `gcloud projects describe ...`) to obtain project name
  # this often. Negative value disables periodic polling. In this mode project name is retrieved
  # only when the current configuration, account or project id changes.
  typeset -g POWERLEVEL9K_GCLOUD_REFRESH_PROJECT_NAME_SECONDS=60

  # Custom icon.
  # typeset -g POWERLEVEL9K_GCLOUD_VISUAL_IDENTIFIER_EXPANSION='⭐'

  #[ google_app_cred: google application credentials (https://cloud.google.com/docs/authentication/production) ]#
  # Show google_app_cred only when the command you are typing invokes one of these tools.
  # Tip: Remove the next line to always show google_app_cred.
  typeset -g POWERLEVEL9K_GOOGLE_APP_CRED_SHOW_ON_COMMAND='terraform|tofu|pulumi|terragrunt'

  # Google application credentials classes for the purpose of using different colors, icons and
  # expansions with different credentials.
  #
  # POWERLEVEL9K_GOOGLE_APP_CRED_CLASSES is an array with even number of elements. The first
  # element in each pair defines a pattern against which the current kubernetes context gets
  # matched. More specifically, it's P9K_CONTENT prior to the application of context expansion
  # (see below) that gets matched. If you unset all POWERLEVEL9K_GOOGLE_APP_CRED_*CONTENT_EXPANSION
  # parameters, you'll see this value in your prompt. The second element of each pair in
  # POWERLEVEL9K_GOOGLE_APP_CRED_CLASSES defines the context class. Patterns are tried in order.
  # The first match wins.
  #
  # For example, given these settings:
  #
  #   typeset -g POWERLEVEL9K_GOOGLE_APP_CRED_CLASSES=(
  #     '*:*prod*:*'  PROD
  #     '*:*test*:*'  TEST
  #     '*'           DEFAULT)
  #
  # If your current Google application credentials is "service_account deathray-testing x@y.com",
  # its class is TEST because it doesn't match the pattern '* *prod* *' but does match '* *test* *'.
  #
  # You can define different colors, icons and content expansions for different classes:
  #
  #   typeset -g POWERLEVEL9K_GOOGLE_APP_CRED_TEST_FOREGROUND=28
  #   typeset -g POWERLEVEL9K_GOOGLE_APP_CRED_TEST_VISUAL_IDENTIFIER_EXPANSION='⭐'
  #   typeset -g POWERLEVEL9K_GOOGLE_APP_CRED_TEST_CONTENT_EXPANSION='$P9K_GOOGLE_APP_CRED_PROJECT_ID'
  typeset -g POWERLEVEL9K_GOOGLE_APP_CRED_CLASSES=(
      # '*:*prod*:*'  PROD    # These values are examples that are unlikely
      # '*:*test*:*'  TEST    # to match your needs. Customize them as needed.
      '*'             DEFAULT)
  typeset -g POWERLEVEL9K_GOOGLE_APP_CRED_DEFAULT_FOREGROUND=32
  # typeset -g POWERLEVEL9K_GOOGLE_APP_CRED_DEFAULT_VISUAL_IDENTIFIER_EXPANSION='⭐'

  # Use POWERLEVEL9K_GOOGLE_APP_CRED_CONTENT_EXPANSION to specify the content displayed by
  # google_app_cred segment. Parameter expansions are very flexible and fast, too. See reference:
  # http://zsh.sourceforge.net/Doc/Release/Expansion.html#Parameter-Expansion.
  #
  # You can use the following parameters in the expansion. Each of them corresponds to one of the
  # fields in the JSON file pointed to by GOOGLE_APPLICATION_CREDENTIALS.
  #
  #   Parameter                        | JSON key file field
  #   ---------------------------------+---------------
  #   P9K_GOOGLE_APP_CRED_TYPE         | type
  #   P9K_GOOGLE_APP_CRED_PROJECT_ID   | project_id
  #   P9K_GOOGLE_APP_CRED_CLIENT_EMAIL | client_email
  #
  # Note: ${VARIABLE//\%/%%} expands to ${VARIABLE} with all occurrences of '%' replaced by '%%'.
  typeset -g POWERLEVEL9K_GOOGLE_APP_CRED_DEFAULT_CONTENT_EXPANSION='${P9K_GOOGLE_APP_CRED_PROJECT_ID//\%/%%}'

  ##############[ toolbox: toolbox name (https://github.com/containers/toolbox) ]###############
  # Toolbox color.
  typeset -g POWERLEVEL9K_TOOLBOX_FOREGROUND=178
  # Don't display the name of the toolbox if it matches fedora-toolbox-*.
  typeset -g POWERLEVEL9K_TOOLBOX_CONTENT_EXPANSION='${P9K_TOOLBOX_NAME:#fedora-toolbox-*}'
  # Custom icon.
  # typeset -g POWERLEVEL9K_TOOLBOX_VISUAL_IDENTIFIER_EXPANSION='⭐'
  # Custom prefix.
  # typeset -g POWERLEVEL9K_TOOLBOX_PREFIX='%244Fin '

  ###############################[ public_ip: public IP address ]###############################
  # Public IP color.
  typeset -g POWERLEVEL9K_PUBLIC_IP_FOREGROUND=94
  # Custom icon.
  # typeset -g POWERLEVEL9K_PUBLIC_IP_VISUAL_IDENTIFIER_EXPANSION='⭐'

  ########################[ vpn_ip: virtual private network indicator ]#########################
  # VPN IP color.
  typeset -g POWERLEVEL9K_VPN_IP_FOREGROUND=81
  # When on VPN, show just an icon without the IP address.
  # Tip: To display the private IP address when on VPN, remove the next line.
  typeset -g POWERLEVEL9K_VPN_IP_CONTENT_EXPANSION=
  # Regular expression for the VPN network interface. Run `ifconfig` or `ip -4 a show` while on VPN
  # to see the name of the interface.
  typeset -g POWERLEVEL9K_VPN_IP_INTERFACE='(gpd|wg|(.*tun)|tailscale)[0-9]*|(zt.*)'
  # If set to true, show one segment per matching network interface. If set to false, show only
  # one segment corresponding to the first matching network interface.
  # Tip: If you set it to true, you'll probably want to unset POWERLEVEL9K_VPN_IP_CONTENT_EXPANSION.
  typeset -g POWERLEVEL9K_VPN_IP_SHOW_ALL=false
  # Custom icon.
  # typeset -g POWERLEVEL9K_VPN_IP_VISUAL_IDENTIFIER_EXPANSION='⭐'

  ###########[ ip: ip address and bandwidth usage for a specified network interface ]###########
  # IP color.
  typeset -g POWERLEVEL9K_IP_FOREGROUND=38
  # The following parameters are accessible within the expansion:
  #
  #   Parameter             | Meaning
  #   ----------------------+-------------------------------------------
  #   P9K_IP_IP             | IP address
  #   P9K_IP_INTERFACE      | network interface
  #   P9K_IP_RX_BYTES       | total number of bytes received
  #   P9K_IP_TX_BYTES       | total number of bytes sent
  #   P9K_IP_RX_BYTES_DELTA | number of bytes received since last prompt
  #   P9K_IP_TX_BYTES_DELTA | number of bytes sent since last prompt
  #   P9K_IP_RX_RATE        | receive rate (since last prompt)
  #   P9K_IP_TX_RATE        | send rate (since last prompt)
  typeset -g POWERLEVEL9K_IP_CONTENT_EXPANSION='${P9K_IP_RX_RATE:+%70F⇣$P9K_IP_RX_RATE }${P9K_IP_TX_RATE:+%215F⇡$P9K_IP_TX_RATE }%38F$P9K_IP_IP'
  # Show information for the first network interface whose name matches this regular expression.
  # Run `ifconfig` or `ip -4 a show` to see the names of all network interfaces.
  typeset -g POWERLEVEL9K_IP_INTERFACE='[ew].*'
  # Custom icon.
  # typeset -g POWERLEVEL9K_IP_VISUAL_IDENTIFIER_EXPANSION='⭐'

  #########################[ proxy: system-wide http/https/ftp proxy ]##########################
  # Proxy color.
  typeset -g POWERLEVEL9K_PROXY_FOREGROUND=68
  # Custom icon.
  # typeset -g POWERLEVEL9K_PROXY_VISUAL_IDENTIFIER_EXPANSION='⭐'

  ################################[ battery: internal battery ]#################################
  # Show battery in red when it's below this level and not connected to power supply.
  typeset -g POWERLEVEL9K_BATTERY_LOW_THRESHOLD=20
  typeset -g POWERLEVEL9K_BATTERY_LOW_FOREGROUND=160
  # Show battery in green when it's charging or fully charged.
  typeset -g POWERLEVEL9K_BATTERY_{CHARGING,CHARGED}_FOREGROUND=70
  # Show battery in yellow when it's discharging.
  typeset -g POWERLEVEL9K_BATTERY_DISCONNECTED_FOREGROUND=178
  # Battery pictograms going from low to high level of charge.
  typeset -g POWERLEVEL9K_BATTERY_STAGES=('%K{232}▁' '%K{232}▂' '%K{232}▃' '%K{232}▄' '%K{232}▅' '%K{232}▆' '%K{232}▇' '%K{232}█')
  # Don't show the remaining time to charge/discharge.
  typeset -g POWERLEVEL9K_BATTERY_VERBOSE=false

  #####################################[ wifi: wifi speed ]#####################################
  # WiFi color.
  typeset -g POWERLEVEL9K_WIFI_FOREGROUND=68
  # Custom icon.
  # typeset -g POWERLEVEL9K_WIFI_VISUAL_IDENTIFIER_EXPANSION='⭐'

  # Use different colors and icons depending on signal strength ($P9K_WIFI_BARS).
  #
  #   # Wifi colors and icons for different signal strength levels (low to high).
  #   typeset -g my_wifi_fg=(68 68 68 68 68)                           # <-- change these values
  #   typeset -g my_wifi_icon=('WiFi' 'WiFi' 'WiFi' 'WiFi' 'WiFi')     # <-- change these values
  #
  #   typeset -g POWERLEVEL9K_WIFI_CONTENT_EXPANSION='%F{${my_wifi_fg[P9K_WIFI_BARS+1]}}$P9K_WIFI_LAST_TX_RATE Mbps'
  #   typeset -g POWERLEVEL9K_WIFI_VISUAL_IDENTIFIER_EXPANSION='%F{${my_wifi_fg[P9K_WIFI_BARS+1]}}${my_wifi_icon[P9K_WIFI_BARS+1]}'
  #
  # The following parameters are accessible within the expansions:
  #
  #   Parameter             | Meaning
  #   ----------------------+---------------
  #   P9K_WIFI_SSID         | service set identifier, a.k.a. network name
  #   P9K_WIFI_LINK_AUTH    | authentication protocol such as "wpa2-psk" or "none"; empty if unknown
  #   P9K_WIFI_LAST_TX_RATE | wireless transmit rate in megabits per second
  #   P9K_WIFI_RSSI         | signal strength in dBm, from -120 to 0
  #   P9K_WIFI_NOISE        | noise in dBm, from -120 to 0
  #   P9K_WIFI_BARS         | signal strength in bars, from 0 to 4 (derived from P9K_WIFI_RSSI and P9K_WIFI_NOISE)

  ####################################[ time: current time ]####################################
  # Current time color.
  typeset -g POWERLEVEL9K_TIME_FOREGROUND=66
  # Format for the current time: 09:51:02. See `man 3 strftime`.
  typeset -g POWERLEVEL9K_TIME_FORMAT='%D{%H:%M:%S}'
  # If set to true, time will update when you hit enter. This way prompts for the past
  # commands will contain the start times of their commands as opposed to the default
  # behavior where they contain the end times of their preceding commands.
  typeset -g POWERLEVEL9K_TIME_UPDATE_ON_COMMAND=false
  # Custom icon.
  typeset -g POWERLEVEL9K_TIME_VISUAL_IDENTIFIER_EXPANSION=
  # Custom prefix.
  # typeset -g POWERLEVEL9K_TIME_PREFIX='%244Fat '

  # Example of a user-defined prompt segment. Function prompt_example will be called on every
  # prompt if `example` prompt segment is added to POWERLEVEL9K_LEFT_PROMPT_ELEMENTS or
  # POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS. It displays an icon and orange text greeting the user.
  #
  # Type `p10k help segment` for documentation and a more sophisticated example.
  function prompt_example() {
    p10k segment -f 208 -i '⭐' -t 'hello, %n'
  }

  # User-defined prompt segments may optionally provide an instant_prompt_* function. Its job
  # is to generate the prompt segment for display in instant prompt. See
  # https://github.com/romkatv/powerlevel10k#instant-prompt.
  #
  # Powerlevel10k will call instant_prompt_* at the same time as the regular prompt_* function
  # and will record all `p10k segment` calls it makes. When displaying instant prompt, Powerlevel10k
  # will replay these calls without actually calling instant_prompt_*. It is imperative that
  # instant_prompt_* always makes the same `p10k segment` calls regardless of environment. If this
  # rule is not observed, the content of instant prompt will be incorrect.
  #
  # Usually, you should either not define instant_prompt_* or simply call prompt_* from it. If
  # instant_prompt_* is not defined for a segment, the segment won't be shown in instant prompt.
  function instant_prompt_example() {
    # Since prompt_example always makes the same `p10k segment` calls, we can call it from
    # instant_prompt_example. This will give us the same `example` prompt segment in the instant
    # and regular prompts.
    prompt_example
  }

  # User-defined prompt segments can be customized the same way as built-in segments.
  # typeset -g POWERLEVEL9K_EXAMPLE_FOREGROUND=208
  # typeset -g POWERLEVEL9K_EXAMPLE_VISUAL_IDENTIFIER_EXPANSION='⭐'

  # Transient prompt works similarly to the builtin transient_rprompt option. It trims down prompt
  # when accepting a command line. Supported values:
  #
  #   - off:      Don't change prompt when accepting a command line.
  #   - always:   Trim down prompt when accepting a command line.
  #   - same-dir: Trim down prompt when accepting a command line unless this is the first command
  #               typed after changing current working directory.
  typeset -g POWERLEVEL9K_TRANSIENT_PROMPT=off

  # Instant prompt mode.
  #
  #   - off:     Disable instant prompt. Choose this if you've tried instant prompt and found
  #              it incompatible with your zsh configuration files.
  #   - quiet:   Enable instant prompt and don't print warnings when detecting console output
  #              during zsh initialization. Choose this if you've read and understood
  #              https://github.com/romkatv/powerlevel10k#instant-prompt.
  #   - verbose: Enable instant prompt and print a warning when detecting console output during
  #              zsh initialization. Choose this if you've never tried instant prompt, haven't
  #              seen the warning, or if you are unsure what this all means.
  typeset -g POWERLEVEL9K_INSTANT_PROMPT=verbose

  # Hot reload allows you to change POWERLEVEL9K options after Powerlevel10k has been initialized.
  # For example, you can type POWERLEVEL9K_BACKGROUND=red and see your prompt turn red. Hot reload
  # can slow down prompt by 1-2 milliseconds, so it's better to keep it turned off unless you
  # really need it.
  typeset -g POWERLEVEL9K_DISABLE_HOT_RELOAD=true

  # If p10k is already loaded, reload configuration.
  # This works even with POWERLEVEL9K_DISABLE_HOT_RELOAD=true.
  (( ! $+functions[p10k] )) || p10k reload
}

# Tell `p10k configure` which file it should overwrite.
typeset -g POWERLEVEL9K_CONFIG_FILE=${${(%):-%x}:a}

(( ${#p10k_config_opts} )) && setopt ${p10k_config_opts[@]}
'builtin' 'unset' 'p10k_config_opts'
__EOF_CFG__

  write_file '$HOME_PLACEHOLDER/.config/starship.toml' <<'__EOF_CFG__'
format = """
$directory$git_branch$git_status$python$nodejs$docker
$character
"""

[directory]
style = "bold blue"
truncation_length = 3

[git_branch]
format = " [$branch]($style)"
style = "purple"

[git_status]
format = " [$all_status$ahead_behind]($style)"

[python]
format = " [🐍 $version]($style)"

[nodejs]
format = " [⬢ $version]($style)"

[docker_context]
format = " [🐳 $context]($style)"

[character]
success_symbol = "❯"
error_symbol = "❯"
__EOF_CFG__

  if ! git config --global user.name &>/dev/null; then
    warn "Git no tiene identidad. Configúrala con:"
    echo '      git config --global user.name  "Tu Nombre"'
    echo '      git config --global user.email "tu@correo.com"'
  fi
}

NODE_VERSION="v24.17.0"
NPM_GLOBALS=( @anthropic-ai/claude-code @google/gemini-cli openclaw )
PIP_USER_PACKAGES=( ipython ipykernel numpy pandas matplotlib seaborn scipy scikit-learn ruff debugpy rich )

sec_dev() {
  section "Desarrollo: nvm/Node, npm, Rust, Deno, Python"
  export NVM_DIR="$HOME/.nvm"
  [[ -s "$NVM_DIR/nvm.sh" ]] || run bash -c "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | PROFILE=/dev/null bash"
  if [[ -s "$NVM_DIR/nvm.sh" ]] && (( ! DRY )); then
    # shellcheck disable=SC1091
    . "$NVM_DIR/nvm.sh"
    nvm install "$NODE_VERSION" && nvm alias default "$NODE_VERSION"
    corepack enable || true
    corepack prepare pnpm@latest --activate || true
    npm install -g "${NPM_GLOBALS[@]}" || warn "npm globals"
  elif (( DRY )); then
    echo "  [dry] nvm install $NODE_VERSION; npm install -g ${NPM_GLOBALS[*]}"
  fi
  have rustup || run sh -c "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y"
  have deno || run sh -c "curl -fsSL https://deno.land/install.sh | DENO_INSTALL=\$HOME/.local sh -s -- -y --no-modify-path"
  run python3 -m pip install --user --upgrade "${PIP_USER_PACKAGES[@]}"
}

VSCODE_EXTENSIONS=( anthropic.claude-code dsznajder.es7-react-js-snippets james-yu.latex-workshop mathematic.vscode-latex mechatroner.rainbow-csv ms-azuretools.vscode-containers ms-python.debugpy ms-python.python ms-python.vscode-pylance ms-python.vscode-python-envs ms-toolsai.jupyter ms-toolsai.jupyter-keymap ms-toolsai.jupyter-renderers ms-toolsai.vscode-jupyter-cell-tags ms-toolsai.vscode-jupyter-slideshow ms-vscode-remote.remote-containers ms-vscode.cmake-tools ms-vscode.cpp-devtools ms-vscode.cpptools ms-vscode.cpptools-extension-pack ms-vscode.cpptools-themes ms-vscode.makefile-tools msjsdiag.vscode-react-native platformio.platformio-ide ritwickdey.liveserver tomoki1207.pdf )

sec_vscode() {
  section "VS Code"
  have code || run sudo dnf -y install code
  for e in "${VSCODE_EXTENSIONS[@]}"; do run code --install-extension "$e" --force; done
}

LATEX_PACKAGES=( texlive-scheme-medium latexmk )

sec_latex() {
  section "LaTeX (TeX Live medium + latexmk)"
  run sudo dnf -y install --skip-unavailable "${LATEX_PACKAGES[@]}"
}

KDE_COPRS=( infinality/kwin-effects-better-blur-dx )
KDE_PACKAGES=( kwin-effects-better-blur-dx )
KDE_ASSETS="$SCRIPT_DIR/kde-assets.tar.gz"

sec_kde() {
  section "KDE Plasma: temas, widgets, paneles y atajos"
  have plasmashell || { warn "KDE Plasma no detectado, se omite"; return; }
  for c in "${KDE_COPRS[@]}"; do run sudo dnf -y copr enable "$c"; done
  run sudo dnf -y install --skip-unavailable "${KDE_PACKAGES[@]}"
  if [[ -f "$KDE_ASSETS" ]]; then
    run mkdir -p "$HOME/.local/share"
    run tar -xzf "$KDE_ASSETS" -C "$HOME/.local/share"
  else
    warn "No se encontró $KDE_ASSETS: temas, iconos y widgets no instalados"
  fi
  # plasmashell reescribe su configuración al salir: se detiene antes de escribir.
  local restart=0
  if (( ! DRY )) && pgrep -x plasmashell >/dev/null; then
    kquitapp6 plasmashell >/dev/null 2>&1 || pkill -x plasmashell
    restart=1
  fi
  write_file '$HOME_PLACEHOLDER/.config/kdeglobals' <<'__EOF_CFG__'
[ColorEffects:Disabled]
ChangeSelectionColor=
Color=56,56,56
ColorAmount=0
ColorEffect=0
ContrastAmount=0.65
ContrastEffect=1
Enable=
IntensityAmount=0.1
IntensityEffect=2

[ColorEffects:Inactive]
ChangeSelectionColor=true
Color=112,111,110
ColorAmount=0.025
ColorEffect=2
ContrastAmount=0.1
ContrastEffect=2
Enable=false
IntensityAmount=0
IntensityEffect=0

[Colors:Button]
BackgroundAlternate=55,135,177
BackgroundNormal=41,44,48
DecorationFocus=61,174,233
DecorationHover=61,174,233
ForegroundActive=61,174,233
ForegroundInactive=161,169,177
ForegroundLink=61,174,233
ForegroundNegative=218,68,83
ForegroundNeutral=246,116,0
ForegroundNormal=252,252,252
ForegroundPositive=39,174,96
ForegroundVisited=155,89,182

[Colors:Complementary]
BackgroundAlternate=30,87,116
BackgroundNormal=32,35,38
DecorationFocus=61,174,233
DecorationHover=61,174,233
ForegroundActive=61,174,233
ForegroundInactive=161,169,177
ForegroundLink=61,174,233
ForegroundNegative=218,68,83
ForegroundNeutral=246,116,0
ForegroundNormal=252,252,252
ForegroundPositive=39,174,96
ForegroundVisited=155,89,182

[Colors:Header]
BackgroundAlternate=32,35,38
BackgroundNormal=41,44,48
DecorationFocus=61,174,233
DecorationHover=61,174,233
ForegroundActive=61,174,233
ForegroundInactive=161,169,177
ForegroundLink=61,174,233
ForegroundNegative=218,68,83
ForegroundNeutral=246,116,0
ForegroundNormal=252,252,252
ForegroundPositive=39,174,96
ForegroundVisited=155,89,182

[Colors:Header][Inactive]
BackgroundAlternate=41,44,48
BackgroundNormal=32,35,38
DecorationFocus=61,174,233
DecorationHover=61,174,233
ForegroundActive=61,174,233
ForegroundInactive=161,169,177
ForegroundLink=29,153,243
ForegroundNegative=218,68,83
ForegroundNeutral=246,116,0
ForegroundNormal=252,252,252
ForegroundPositive=39,174,96
ForegroundVisited=155,89,182

[Colors:Selection]
BackgroundAlternate=48,128,170
BackgroundNormal=48,128,170
DecorationFocus=61,174,233
DecorationHover=61,174,233
ForegroundActive=61,174,233
ForegroundInactive=0,0,0
ForegroundLink=45,127,170
ForegroundNegative=176,55,69
ForegroundNeutral=198,92,0
ForegroundNormal=0,0,0
ForegroundPositive=23,104,57
ForegroundVisited=155,89,182

[Colors:Tooltip]
BackgroundAlternate=32,35,38
BackgroundNormal=41,44,48
DecorationFocus=61,174,233
DecorationHover=61,174,233
ForegroundActive=61,174,233
ForegroundInactive=161,169,177
ForegroundLink=61,174,233
ForegroundNegative=218,68,83
ForegroundNeutral=246,116,0
ForegroundNormal=252,252,252
ForegroundPositive=39,174,96
ForegroundVisited=155,89,182

[Colors:View]
BackgroundAlternate=29,31,34
BackgroundNormal=20,22,24
DecorationFocus=61,174,233
DecorationHover=61,174,233
ForegroundActive=61,174,233
ForegroundInactive=161,169,177
ForegroundLink=61,174,233
ForegroundNegative=218,68,83
ForegroundNeutral=246,116,0
ForegroundNormal=252,252,252
ForegroundPositive=39,174,96
ForegroundVisited=155,89,182

[Colors:Window]
BackgroundAlternate=41,44,48
BackgroundNormal=32,35,38
DecorationFocus=61,174,233
DecorationHover=61,174,233
ForegroundActive=61,174,233
ForegroundInactive=161,169,177
ForegroundLink=61,174,233
ForegroundNegative=218,68,83
ForegroundNeutral=246,116,0
ForegroundNormal=252,252,252
ForegroundPositive=39,174,96
ForegroundVisited=155,89,182

[General]
AccentColor=61,174,233
BrowserApplication=google-chrome.desktop
ColorSchemeHash=27363f5706202c1c8261fbda7381ddaab8ad48f3
LastUsedCustomAccentColor=61,174,233
TerminalApplication=ptyxis
TerminalService=org.gnome.Ptyxis.desktop

[Icons]
Theme=Noir-Gently-White-Blue-Dark-Icons

[KDE]
AnimationDurationFactor=0.5
LookAndFeelPackage=org.fedoraproject.fedoradark.desktop
contrast=4
frameContrast=0.2

[KFileDialog Settings]
Allow Expansion=false
Automatically select filename extension=true
Breadcrumb Navigation=true
Decoration position=2
Show Full Path=false
Show Inline Previews=true
Show Preview=false
Show Speedbar=true
Show hidden files=false
Sort by=Name
Sort directories first=true
Sort hidden files last=false
Sort reversed=false
Speedbar Width=140
View Style=DetailTree

[WM]
activeBackground=39,44,49
activeBlend=252,252,252
activeForeground=252,252,252
inactiveBackground=32,36,40
inactiveBlend=161,169,177
inactiveForeground=161,169,177
__EOF_CFG__

  write_file '$HOME_PLACEHOLDER/.config/kglobalshortcutsrc' <<'__EOF_CFG__'
[ActivityManager]
_k_friendly_name=Activity Manager
switch-to-activity-f23c98a1-0207-4367-9983-5dbb8d1a0268=none,none,Switch to activity "Default"

[KDE Keyboard Layout Switcher]
Switch keyboard layout to English (US)=none,none,Switch keyboard layout to English (US)
Switch keyboard layout to Spanish=none,none,Switch keyboard layout to Spanish
Switch to Last-Used Keyboard Layout=Meta+Alt+L,Meta+Alt+L,Switch to Last-Used Keyboard Layout
Switch to Next Keyboard Layout=Meta+Space,Meta+Alt+K,Switch to Next Keyboard Layout
_k_friendly_name=Keyboard Layout Switcher

[kmix]
_k_friendly_name=Audio Volume
decrease_microphone_volume=Microphone Volume Down,Microphone Volume Down,Decrease Microphone Volume
decrease_volume=Volume Down,Volume Down,Decrease Volume
decrease_volume_small=Shift+Volume Down,Shift+Volume Down,Decrease Volume by 1%
increase_microphone_volume=Microphone Volume Up,Microphone Volume Up,Increase Microphone Volume
increase_volume=Volume Up,Volume Up,Increase Volume
increase_volume_small=Shift+Volume Up,Shift+Volume Up,Increase Volume by 1%
mic_mute=Microphone Mute\tMeta+Volume Mute,Microphone Mute\tMeta+Volume Mute,Mute Microphone
mute=Volume Mute,Volume Mute,Mute
push_to_talk=none,none,Push to talk

[ksmserver]
Halt Without Confirmation=none,none,Shut Down Without Confirmation
Lock Session=Screensaver\tCtrl+Launch (2),Screensaver\tMeta+L,Lock Session
Log Out=Ctrl+Alt+Del,Ctrl+Alt+Del,Show Logout Screen
Log Out Without Confirmation=none,none,Log Out Without Confirmation
LogOut=none,none,Log Out
Reboot=none,none,Reboot
Reboot Without Confirmation=none,none,Reboot Without Confirmation
Shut Down=none,none,Shut Down
_k_friendly_name=Session Management

[kwin]
Activate Window Demanding Attention=Meta+Ctrl+A,Meta+Ctrl+A,Activate Window Demanding Attention
Cycle Overview=none,none,Cycle through Overview and Grid View
Cycle Overview Opposite=none,none,Cycle through Grid View and Overview
Decrease Opacity=none,none,Decrease Opacity of Active Window by 5%
Edit Tiles=Meta+T,Meta+T,Toggle Tiles Editor
Expose=Ctrl+F9\tMeta+F9,Ctrl+F9\tMeta+F9,Toggle Present Windows (Current desktop)
ExposeAll=Launch (C)\tCtrl+F10\tMeta+F10,Launch (C)\tCtrl+F10\tMeta+F10,Toggle Present Windows (All desktops)
ExposeClass=Ctrl+F7\tMeta+F7,Ctrl+F7\tMeta+F7,Toggle Present Windows (Window class)
ExposeClassCurrentDesktop=none,none,Toggle Present Windows (Window class on current desktop)
Grid View=Meta+G,Meta+G,Toggle Grid View
Increase Opacity=none,none,Increase Opacity of Active Window by 5%
Kill Window=Meta+Ctrl+Esc,Meta+Ctrl+Esc,Kill Window
Move Tablet to Next LogicalOutput=none,none,Move the tablet to the next output
MoveMouseToCenter=Meta+F6,Meta+F6,Center Pointer in Screen
MoveMouseToFocus=Meta+F5,Meta+F5,Center Pointer in Focused Window
MoveZoomDown=none,none,Move Zoomed Area Downwards
MoveZoomLeft=none,none,Move Zoomed Area to Left
MoveZoomRight=none,none,Move Zoomed Area to Right
MoveZoomUp=none,none,Move Zoomed Area Upwards
Overview=Meta+W,Meta+W,Toggle Overview
Setup Window Shortcut=none,none,Setup Window Shortcut
Show Desktop=Meta+D,Meta+D,Peek at Desktop
Switch One Desktop Down=Meta+Ctrl+Down,Meta+Ctrl+Down,Switch One Desktop Down
Switch One Desktop Up=Meta+Ctrl+Up,Meta+Ctrl+Up,Switch One Desktop Up
Switch One Desktop to the Left=Meta+Ctrl+Left,Meta+Ctrl+Left,Switch One Desktop to the Left
Switch One Desktop to the Right=Meta+Ctrl+Right,Meta+Ctrl+Right,Switch One Desktop to the Right
Switch Window Down=Meta+Alt+Down,Meta+Alt+Down,Switch to Window Below
Switch Window Left=Meta+Alt+Left,Meta+Alt+Left,Switch to Window to the Left
Switch Window Right=Meta+Alt+Right,Meta+Alt+Right,Switch to Window to the Right
Switch Window Up=Meta+Alt+Up,Meta+Alt+Up,Switch to Window Above
Switch to Desktop 1=Ctrl+F1\tMeta+F1,Ctrl+F1\tMeta+F1,Switch to Desktop 1
Switch to Desktop 10=none,none,Switch to Desktop 10
Switch to Desktop 11=none,none,Switch to Desktop 11
Switch to Desktop 12=none,none,Switch to Desktop 12
Switch to Desktop 13=none,none,Switch to Desktop 13
Switch to Desktop 14=none,none,Switch to Desktop 14
Switch to Desktop 15=none,none,Switch to Desktop 15
Switch to Desktop 16=none,none,Switch to Desktop 16
Switch to Desktop 17=none,none,Switch to Desktop 17
Switch to Desktop 18=none,none,Switch to Desktop 18
Switch to Desktop 19=none,none,Switch to Desktop 19
Switch to Desktop 2=Ctrl+F2\tMeta+F2,Ctrl+F2\tMeta+F2,Switch to Desktop 2
Switch to Desktop 20=none,none,Switch to Desktop 20
Switch to Desktop 21=none,none,Switch to Desktop 21
Switch to Desktop 22=none,none,Switch to Desktop 22
Switch to Desktop 23=none,none,Switch to Desktop 23
Switch to Desktop 24=none,none,Switch to Desktop 24
Switch to Desktop 25=none,none,Switch to Desktop 25
Switch to Desktop 3=Ctrl+F3\tMeta+F3,Ctrl+F3\tMeta+F3,Switch to Desktop 3
Switch to Desktop 4=Ctrl+F4\tMeta+F4,Ctrl+F4\tMeta+F4,Switch to Desktop 4
Switch to Desktop 5=none,none,Switch to Desktop 5
Switch to Desktop 6=none,none,Switch to Desktop 6
Switch to Desktop 7=none,none,Switch to Desktop 7
Switch to Desktop 8=none,none,Switch to Desktop 8
Switch to Desktop 9=none,none,Switch to Desktop 9
Switch to Next Desktop=none,none,Switch to Next Desktop
Switch to Next Screen=none,none,Switch to Next Screen
Switch to Previous Desktop=none,none,Switch to Previous Desktop
Switch to Previous Screen=none,none,Switch to Previous Screen
Switch to Screen 0=none,none,Switch to Screen 0
Switch to Screen 1=none,none,Switch to Screen 1
Switch to Screen 2=none,none,Switch to Screen 2
Switch to Screen 3=none,none,Switch to Screen 3
Switch to Screen 4=none,none,Switch to Screen 4
Switch to Screen 5=none,none,Switch to Screen 5
Switch to Screen 6=none,none,Switch to Screen 6
Switch to Screen 7=none,none,Switch to Screen 7
Switch to Screen Above=none,none,Switch to Screen Above
Switch to Screen Below=none,none,Switch to Screen Below
Switch to Screen to the Left=none,none,Switch to Screen to the Left
Switch to Screen to the Right=none,none,Switch to Screen to the Right
Toggle Night Color=none,none,Suspend/Resume Night Light
Toggle Show Compositing=none,none,Toggle “Show Compositing” effect
Toggle Window Raise/Lower=none,none,Toggle Window Raise/Lower
ToggleMouseClick=Meta+*,Meta+*,Toggle Mouse Click Animation
Walk Through Windows=Alt+Tab\tMeta+Tab,Alt+Tab\tMeta+Tab,Walk Through Windows
Walk Through Windows (Reverse)=Alt+Shift+Tab\tMeta+Shift+Tab,Alt+Shift+Tab\tMeta+Shift+Tab,Walk Through Windows (Reverse)
Walk Through Windows Alternative=none,none,Walk Through Windows Alternative
Walk Through Windows Alternative (Reverse)=none,none,Walk Through Windows Alternative (Reverse)
Walk Through Windows of Current Application=Alt+`\tMeta+`,Alt+`\tMeta+`,Walk Through Windows of Current Application
Walk Through Windows of Current Application (Reverse)=Alt+~\tMeta+~,Alt+~\tMeta+~,Walk Through Windows of Current Application (Reverse)
Walk Through Windows of Current Application Alternative=none,none,Walk Through Windows of Current Application Alternative
Walk Through Windows of Current Application Alternative (Reverse)=none,none,Walk Through Windows of Current Application Alternative (Reverse)
Window Above Other Windows=none,none,Keep Window Above Others
Window Below Other Windows=none,none,Keep Window Below Others
Window Close=Alt+F4,Alt+F4,Close Window
Window Custom Quick Tile Bottom=none,none,Custom Quick Tile Window to the Bottom
Window Custom Quick Tile Left=none,none,Custom Quick Tile Window to the Left
Window Custom Quick Tile Right=none,none,Custom Quick Tile Window to the Right
Window Custom Quick Tile Top=none,none,Custom Quick Tile Window to the Top
Window Fullscreen=none,none,Make Window Fullscreen
Window Grow Horizontal=none,none,Expand Window Horizontally
Window Grow Vertical=none,none,Expand Window Vertically
Window Lower=none,none,Lower Window
Window Maximize=Meta+PgUp,Meta+PgUp,Maximize Window
Window Maximize Horizontal=none,none,Maximize Window Horizontally
Window Maximize Vertical=none,none,Maximize Window Vertically
Window Minimize=Meta+PgDown,Meta+PgDown,Minimize Window
Window Move=none,none,Move Window
Window Move Center=none,none,Move Window to the Center
Window No Border=none,none,Toggle Window Titlebar and Frame
Window On All Desktops=none,none,Keep Window on All Desktops
Window One Desktop Down=Meta+Ctrl+Shift+Down,Meta+Ctrl+Shift+Down,Window One Desktop Down
Window One Desktop Up=Meta+Ctrl+Shift+Up,Meta+Ctrl+Shift+Up,Window One Desktop Up
Window One Desktop to the Left=Meta+Ctrl+Shift+Left,Meta+Ctrl+Shift+Left,Window One Desktop to the Left
Window One Desktop to the Right=Meta+Ctrl+Shift+Right,Meta+Ctrl+Shift+Right,Window One Desktop to the Right
Window One Screen Down=none,none,Move Window One Screen Down
Window One Screen Up=none,none,Move Window One Screen Up
Window One Screen to the Left=none,none,Move Window One Screen to the Left
Window One Screen to the Right=none,none,Move Window One Screen to the Right
Window Operations Menu=Alt+F3,Alt+F3,Window Menu
Window Pack Down=none,none,Move Window Down
Window Pack Left=none,none,Move Window Left
Window Pack Right=none,none,Move Window Right
Window Pack Up=none,none,Move Window Up
Window Quick Tile Bottom=Meta+Down,Meta+Down,Quick Tile Window to the Bottom
Window Quick Tile Bottom Left=none,none,Quick Tile Window to the Bottom Left
Window Quick Tile Bottom Right=none,none,Quick Tile Window to the Bottom Right
Window Quick Tile Left=Meta+Left,Meta+Left,Quick Tile Window to the Left
Window Quick Tile Right=Meta+Right,Meta+Right,Quick Tile Window to the Right
Window Quick Tile Top=Meta+Up,Meta+Up,Quick Tile Window to the Top
Window Quick Tile Top Left=none,none,Quick Tile Window to the Top Left
Window Quick Tile Top Right=none,none,Quick Tile Window to the Top Right
Window Raise=none,none,Raise Window
Window Resize=none,none,Resize Window
Window Restore=Meta+Backspace,Meta+Backspace,Restore Window
Window Shrink Horizontal=none,none,Shrink Window Horizontally
Window Shrink Vertical=none,none,Shrink Window Vertically
Window to Desktop 1=none,none,Window to Desktop 1
Window to Desktop 10=none,none,Window to Desktop 10
Window to Desktop 11=none,none,Window to Desktop 11
Window to Desktop 12=none,none,Window to Desktop 12
Window to Desktop 13=none,none,Window to Desktop 13
Window to Desktop 14=none,none,Window to Desktop 14
Window to Desktop 15=none,none,Window to Desktop 15
Window to Desktop 16=none,none,Window to Desktop 16
Window to Desktop 17=none,none,Window to Desktop 17
Window to Desktop 18=none,none,Window to Desktop 18
Window to Desktop 19=none,none,Window to Desktop 19
Window to Desktop 2=none,none,Window to Desktop 2
Window to Desktop 20=none,none,Window to Desktop 20
Window to Desktop 21=none,none,Window to Desktop 21
Window to Desktop 22=none,none,Window to Desktop 22
Window to Desktop 23=none,none,Window to Desktop 23
Window to Desktop 24=none,none,Window to Desktop 24
Window to Desktop 25=none,none,Window to Desktop 25
Window to Desktop 3=none,none,Window to Desktop 3
Window to Desktop 4=none,none,Window to Desktop 4
Window to Desktop 5=none,none,Window to Desktop 5
Window to Desktop 6=none,none,Window to Desktop 6
Window to Desktop 7=none,none,Window to Desktop 7
Window to Desktop 8=none,none,Window to Desktop 8
Window to Desktop 9=none,none,Window to Desktop 9
Window to Next Desktop=none,none,Window to Next Desktop
Window to Next Screen=Meta+Shift+Right,Meta+Shift+Right,Move Window to Next Screen
Window to Previous Desktop=none,none,Window to Previous Desktop
Window to Previous Screen=Meta+Shift+Left,Meta+Shift+Left,Move Window to Previous Screen
Window to Screen 0=none,none,Move Window to Screen 0
Window to Screen 1=none,none,Move Window to Screen 1
Window to Screen 2=none,none,Move Window to Screen 2
Window to Screen 3=none,none,Move Window to Screen 3
Window to Screen 4=none,none,Move Window to Screen 4
Window to Screen 5=none,none,Move Window to Screen 5
Window to Screen 6=none,none,Move Window to Screen 6
Window to Screen 7=none,none,Move Window to Screen 7
_k_friendly_name=KWin
disableInputCapture=Meta+Shift+Esc,Meta+Shift+Esc,Disable Active Input Capture
view_actual_size=Meta+0,Meta+0,Zoom to Actual Size
view_zoom_in=Meta++\tMeta+=,Meta++\tMeta+=,Zoom In
view_zoom_out=Meta+-,Meta+-,Zoom Out

[kwin][$InverseAction]
Cycle Overview=Cycle Overview Opposite
Decrease Opacity=Increase Opacity
MoveZoomLeft=MoveZoomRight
MoveZoomUp=MoveZoomDown
Switch One Desktop Down=Switch One Desktop Up
Switch One Desktop to the Left=Switch One Desktop to the Right
Switch Window Down=Switch Window Up
Switch Window Left=Switch Window Right
Switch to Next Desktop=Switch to Previous Desktop
Switch to Previous Screen=Switch to Next Screen
Switch to Screen Above=Switch to Screen Below
Switch to Screen to the Left=Switch to Screen to the Right
Walk Through Windows (Reverse)=Walk Through Windows
Walk Through Windows Alternative=Walk Through Windows Alternative (Reverse)
Walk Through Windows of Current Application=Walk Through Windows of Current Application (Reverse)
Walk Through Windows of Current Application Alternative=Walk Through Windows of Current Application Alternative (Reverse)
Window Grow Vertical=Window Shrink Vertical
Window One Desktop Up=Window One Desktop Down
Window One Desktop to the Right=Window One Desktop to the Left
Window One Screen Up=Window One Screen Down
Window One Screen to the Left=Window One Screen to the Right
Window Pack Down=Window Pack Up
Window Pack Left=Window Pack Right
Window Raise=Window Lower
Window Shrink Horizontal=Window Grow Horizontal
Window to Next Desktop=Window to Previous Desktop
Window to Next Screen=Window to Previous Screen
view_zoom_out=view_zoom_in

[mediacontrol]
_k_friendly_name=Media Controller
mediavolumedown=none,none,Media volume down
mediavolumeup=none,none,Media volume up
nextmedia=Media Next,Media Next,Media playback next
pausemedia=Media Pause,Media Pause,Pause media playback
playmedia=none,none,Play media playback
playpausemedia=Media Play,Media Play,Play/Pause media playback
previousmedia=Media Previous,Media Previous,Media playback previous
seekbackwardmedia=Media Rewind,Media Rewind,Media playback seek backward 5s
seekbackwardmedialong=none,none,Media playback seek backward 30s
seekforwardmedia=Media Fast Forward,Media Fast Forward,Media playback seek forward 5s
seekforwardmedialong=none,none,Media playback seek forward 30s
stopmedia=Media Stop,Media Stop,Stop media playback

[org_kde_powerdevil]
Decrease Keyboard Brightness=Keyboard Brightness Down,Keyboard Brightness Down,Decrease Keyboard Brightness
Decrease Screen Brightness=Monitor Brightness Down,Monitor Brightness Down,Decrease Screen Brightness
Decrease Screen Brightness Small=Shift+Monitor Brightness Down,Shift+Monitor Brightness Down,Decrease Screen Brightness by 1%
Hibernate=Hibernate,Hibernate,Hibernate
Increase Keyboard Brightness=Keyboard Brightness Up,Keyboard Brightness Up,Increase Keyboard Brightness
Increase Screen Brightness=Monitor Brightness Up,Monitor Brightness Up,Increase Screen Brightness
Increase Screen Brightness Small=Shift+Monitor Brightness Up,Shift+Monitor Brightness Up,Increase Screen Brightness by 1%
PowerDown=Power Down,Power Down,Power Down
PowerOff=Power Off,Power Off,Power Off
Sleep=Sleep,Sleep,Suspend
Toggle Keyboard Backlight=Keyboard Light On/Off,Keyboard Light On/Off,Toggle Keyboard Backlight
Turn Off Screen=none,none,Turn Off Screen
_k_friendly_name=Power Management
powerProfile=Battery\tMeta+B,Battery\tMeta+B,Switch Power Profile

[plasmashell]
Slideshow Wallpaper Next Image=none,none,Next Wallpaper Image
_k_friendly_name=plasmashell
activate application launcher=Meta\tAlt+F1,Meta\tAlt+F1,Activate Application Launcher
activate next task manager entry=Meta+Ctrl+PgDown,Meta+Ctrl+PgDown,Activate Next Task Manager Entry
activate previous task manager entry=Meta+Ctrl+PgUp,Meta+Ctrl+PgUp,Activate Previous Task Manager Entry
activate task manager entry 1=Meta+1,Meta+1,Activate Task Manager Entry 1
activate task manager entry 10=none,none,Activate Task Manager Entry 10
activate task manager entry 2=Meta+2,Meta+2,Activate Task Manager Entry 2
activate task manager entry 3=Meta+3,Meta+3,Activate Task Manager Entry 3
activate task manager entry 4=Meta+4,Meta+4,Activate Task Manager Entry 4
activate task manager entry 5=Meta+5,Meta+5,Activate Task Manager Entry 5
activate task manager entry 6=Meta+6,Meta+6,Activate Task Manager Entry 6
activate task manager entry 7=Meta+7,Meta+7,Activate Task Manager Entry 7
activate task manager entry 8=Meta+8,Meta+8,Activate Task Manager Entry 8
activate task manager entry 9=Meta+9,Meta+9,Activate Task Manager Entry 9
clear history=none,none,Clear Notification History
clear-history=none,none,Clear Clipboard History
clipboard_action=none,none,Toggle Automatic Popping Up of Action Menu
cycle-panels=Meta+Alt+P,Meta+Alt+P,Move keyboard focus between panels
cycleNextAction=none,none,Next History Item
cyclePrevAction=none,none,Previous History Item
edit_clipboard=none,none,Edit Contents…
manage activities=Meta+Q,Meta+Q,Show Activity Switcher
move active task to left=Meta+Ctrl+Shift+PgUp,Meta+Ctrl+Shift+PgUp,Move Active Task Manager Entry Backward
move active task to right=Meta+Ctrl+Shift+PgDown,Meta+Ctrl+Shift+PgDown,Move Active Task Manager Entry Forward
next activity=Meta+A,none,Walk through activities
previous activity=Meta+Shift+A,none,Walk through activities (Reverse)
repeat_action=none,none,Manually Invoke Action on Current Clipboard
show dashboard=Ctrl+F12,Ctrl+F12,Show Desktop
show-barcode=none,none,Show Barcode…
show-on-mouse-pos=Meta+V,Meta+V,Show Clipboard Items at Mouse Position
switch to next activity=none,none,Switch to Next Activity
switch to previous activity=none,none,Switch to Previous Activity
toggle do not disturb=none,none,Toggle do not disturb
__EOF_CFG__

  write_file '$HOME_PLACEHOLDER/.config/kxkbrc' <<'__EOF_CFG__'
[Layout]
DisplayNames=,
LayoutList=us,es
Use=true
VariantList=,
__EOF_CFG__

  write_file '$HOME_PLACEHOLDER/.config/kcminputrc' <<'__EOF_CFG__'
[Libinput][1267][12826][ELAN0788:00 04F3:321A Touchpad]
NaturalScroll=false
PointerAcceleration=0.350
PointerAccelerationProfile=1
ScrollFactor=0.5

[Libinput][7511][64096][Beken 2.4G Wireless Device]
PointerAccelerationProfile=1

[Libinput][7511][64097][Beken USB Gaming Mouse]
PointerAccelerationProfile=1
__EOF_CFG__

  write_file '$HOME_PLACEHOLDER/.config/konsolerc' <<'__EOF_CFG__'
[General]
ConfigVersion=1

[MainWindow]
MenuBar=Disabled

[UiSettings]
ColorScheme=
__EOF_CFG__

  write_file '$HOME_PLACEHOLDER/.config/ksplashrc' <<'__EOF_CFG__'
[KSplash]
Theme=Fedora-Minimalistic
__EOF_CFG__

  write_file '$HOME_PLACEHOLDER/.config/katerc' <<'__EOF_CFG__'
[General]
Days Meta Infos=30
PinnedDocuments=
Save Meta Infos=true
Show Full Path in Title=false
Show Menu Bar=true
Show Status Bar=true
Show Tab Bar=true
Show Url Nav Bar=true

[MainWindow]
1920x1080 screen: Height=1006
1920x1080 screen: Width=960
1920x1080 screen: Window-Maximized=true
2 screens: Window-Maximized=true

[filetree]
editShade=30,78,103
listMode=false
middleClickToClose=false
shadingEnabled=true
showCloseButton=false
showFullPathOnRoots=false
showToolbar=true
sortRole=0
viewShade=77,46,91
__EOF_CFG__

  write_file '$HOME_PLACEHOLDER/.config/gtk-3.0/settings.ini' <<'__EOF_CFG__'
[Settings]
gtk-application-prefer-dark-theme=true
gtk-button-images=true
gtk-cursor-blink=true
gtk-cursor-blink-time=1000
gtk-cursor-theme-name=breeze_cursors
gtk-cursor-theme-size=24
gtk-decoration-layout=icon:minimize,maximize,close
gtk-enable-animations=true
gtk-font-name=Noto Sans,  10
gtk-icon-theme-name=Noir-Gently-White-Blue-Dark-Icons
gtk-menu-images=true
gtk-modules=colorreload-gtk-module:window-decorations-gtk-module
gtk-primary-button-warps-slider=true
gtk-sound-theme-name=ocean
gtk-theme-name=Breeze
gtk-toolbar-style=3
gtk-xft-dpi=98304
__EOF_CFG__

  write_file '$HOME_PLACEHOLDER/.config/gtk-4.0/settings.ini' <<'__EOF_CFG__'
[Settings]
gtk-application-prefer-dark-theme=true
gtk-cursor-blink=true
gtk-cursor-blink-time=1000
gtk-cursor-theme-name=breeze_cursors
gtk-cursor-theme-size=24
gtk-decoration-layout=icon:minimize,maximize,close
gtk-enable-animations=true
gtk-font-name=Noto Sans,  10
gtk-icon-theme-name=Noir-Gently-White-Blue-Dark-Icons
gtk-primary-button-warps-slider=true
gtk-sound-theme-name=ocean
gtk-xft-dpi=98304
__EOF_CFG__

  write_file '$HOME_PLACEHOLDER/.config/kwinrc' <<'__EOF_CFG__'
[Desktops]
Id_1=a90980b5-a195-4fef-906d-6c2764f7ab3e
Id_2=38258093-837d-4770-9cae-7cd80cd07110
Name_1=Main
Name_2=Dev
Number=2
Rows=1

[Effect-better-blur-dx]
BlurDecorations=true
BlurDocks=true
BlurMatching=false
BlurMenus=true
BlurNonMatching=true
BlurStrength=14
Brightness=175
NoiseStrength=10
RefractionStrength=7

[Plugins]
better_blur_dxEnabled=true
blurEnabled=false
kwin6_effect_glitchEnabled=true
mouseclickEnabled=true
scaleEnabled=false
translucencyEnabled=true
virtualdesktopsonlyonprimaryEnabled=true

[TabBox]
DelayTime=40
HighlightWindows=false

[Windows]
RollOverDesktops=true

[org.kde.kdecoration2]
library=org.kde.kwin.aurorae.v2
theme=__aurorae__svg__Utterly-Round-Dark
__EOF_CFG__

  write_file '$HOME_PLACEHOLDER/.config/plasmashellrc' <<'__EOF_CFG__'
[PIMEventsPlugin]
calendars=8

[PlasmaViews][Panel 117]
floating=1
panelLengthMode=1
panelOpacity=2
panelVisibility=0
shell=org.kde.plasma.desktop

[PlasmaViews][Panel 117][Defaults]
maxLength=234
minLength=98
thickness=48

[PlasmaViews][Panel 117][Horizontal1920]
maxLength=234
minLength=98

[PlasmaViews][Panel 2]
floating=1
panelLengthMode=2
panelOpacity=2
panelVisibility=0
shell=org.kde.plasma.desktop

[PlasmaViews][Panel 2][Defaults]
thickness=42

__EOF_CFG__

  write_file '$HOME_PLACEHOLDER/.config/plasma-org.kde.plasma.desktop-appletsrc' <<'__EOF_CFG__'
[ActionPlugins][0]
RightButton;NoModifier=org.kde.contextmenu

[ActionPlugins][1]
RightButton;NoModifier=org.kde.contextmenu

[Containments][1]
ItemGeometries-1920x1080=Applet-129:128,48,208,240,0;Applet-78:784,144,656,160,0;
ItemGeometriesHorizontal=Applet-129:128,48,208,240,0;Applet-78:784,144,656,160,0;
activityId=__ACTIVITY_ID__
formfactor=0
immutability=1
lastScreen=0
location=0
plugin=org.kde.plasma.folder
wallpaperplugin=org.kde.image

[Containments][1][Applets][78]
immutability=1
plugin=com.github.prayag2.modernclock

[Containments][1][Applets][78][Configuration][Appearance]
date_font_size=20
day_font_size=74

[Containments][1][Applets][78][Configuration][ConfigDialog]
DialogHeight=630
DialogWidth=810

[Containments][1][ConfigDialog]
DialogHeight=1010
DialogWidth=1920

[Containments][1][Wallpaper][org.kde.image][General]
SlidePaths=/usr/share/wallpapers/

[Containments][117]
activityId=
formfactor=2
immutability=1
lastScreen=0
location=4
plugin=org.kde.panel
wallpaperplugin=org.kde.image

[Containments][117][Applets][118]
immutability=1
plugin=org.kde.plasma.kickerdash

[Containments][117][Applets][118][Configuration][ConfigDialog]
DialogHeight=630
DialogWidth=810

[Containments][117][Applets][118][Configuration][General]
favoritesPortedToKAstats=true
icon=start-here

[Containments][117][Applets][119]
immutability=1
plugin=org.kde.plasma.icon

[Containments][117][Applets][119][Configuration]
url=file:///usr/share/applications/google-chrome.desktop

[Containments][117][Applets][122]
immutability=1
plugin=org.kde.plasma.icon

[Containments][117][Applets][122][Configuration]
url=file:///usr/share/applications/com.microsoft.VSCode.desktop

[Containments][117][Applets][123]
immutability=1
plugin=org.kde.plasma.icon

[Containments][117][Applets][123][Configuration]
url=file:///var/lib/flatpak/exports/share/applications/org.telegram.desktop.desktop

[Containments][117][Applets][124]
immutability=1
plugin=org.kde.plasma.icon

[Containments][117][Applets][124][Configuration]
url=file:///usr/share/applications/org.kde.dolphin.desktop

[Containments][117][Applets][125]
immutability=1
plugin=org.kde.plasma.icon

[Containments][117][Applets][125][Configuration]
url=file:///usr/share/applications/discord.desktop

[Containments][117][Applets][126]
immutability=1
plugin=org.kde.plasma.icon

[Containments][117][Applets][126][Configuration]
url=file:///usr/share/applications/org.gnome.Ptyxis.desktop

[Containments][117][General]
AppletOrder=118;119;122;123;124;125;126

[Containments][2]
activityId=
formfactor=2
immutability=1
lastScreen=0
location=3
plugin=org.kde.panel
wallpaperplugin=org.kde.image

[Containments][2][Applets][112]
immutability=1
plugin=org.kde.plasma.systemmonitor.net

[Containments][2][Applets][112][Configuration]
CurrentPreset=org.kde.plasma.systemmonitor
popupHeight=195
popupWidth=204

[Containments][2][Applets][112][Configuration][Appearance]
chartFace=org.kde.ksysguard.linechart
title=Network Speed

[Containments][2][Applets][112][Configuration][SensorColors]
network/all/download=48,128,170
network/all/upload=170,90,48

[Containments][2][Applets][112][Configuration][Sensors]
highPrioritySensorIds=["network/all/download","network/all/upload"]

[Containments][2][Applets][113]
immutability=1
plugin=org.kde.plasma.systemmonitor

[Containments][2][Applets][113][Configuration]
CurrentPreset=org.kde.plasma.systemmonitor
popupHeight=195
popupWidth=187

[Containments][2][Applets][113][Configuration][Appearance]
chartFace=org.kde.ksysguard.piechart

[Containments][2][Applets][114]
immutability=1
plugin=org.kde.plasma.battery

[Containments][2][Applets][114][Configuration]
popupHeight=400
popupWidth=560

[Containments][2][Applets][127]
immutability=1
plugin=org.kde.plasma.bluetooth

[Containments][2][Applets][127][Configuration]
popupHeight=433
popupWidth=432

[Containments][2][Applets][24]
immutability=1
plugin=org.kde.plasma.showdesktop

[Containments][2][Applets][30]
immutability=1
plugin=org.kde.plasma.digitalclock

[Containments][2][Applets][30][Configuration]
popupHeight=451
popupWidth=810

[Containments][2][Applets][30][Configuration][Appearance]
displayTimezoneFormat=FullText
enabledCalendarPlugins=pimevents
showWeekNumbers=true

[Containments][2][Applets][30][Configuration][ConfigDialog]
DialogHeight=630
DialogWidth=810

[Containments][2][Applets][34]
immutability=1
plugin=luisbocanegra.panelspacer.extended

[Containments][2][Applets][34][Configuration][ConfigDialog]
DialogHeight=630
DialogWidth=810

[Containments][2][Applets][34][Configuration][General]
screenWidth=1920

[Containments][2][Applets][35]
immutability=1
plugin=luisbocanegra.panelspacer.extended

[Containments][2][Applets][35][Configuration][General]
screenWidth=1920

[Containments][2][Applets][40]
immutability=1
plugin=AndromedaLauncher

[Containments][2][Applets][43]
immutability=1
plugin=KdeControlStation

[Containments][2][Applets][43][Configuration]
popupHeight=419
popupWidth=420

[Containments][2][Applets][6]
immutability=1
plugin=org.kde.plasma.marginsseparator

[Containments][2][Applets][80]
immutability=1
plugin=zayron.chaac.weather

[Containments][2][Applets][81]
immutability=1
plugin=org.kde.plasma.networkmanagement

[Containments][2][Applets][81][Configuration]
popupHeight=400
popupWidth=560

[Containments][2][General]
AppletOrder=40;6;35;30;34;114;112;113;43;24;80;81;127

[Containments][25]
ItemGeometries-1920x1080=
ItemGeometriesHorizontal=
activityId=__ACTIVITY_ID__
formfactor=0
immutability=1
lastScreen=1
location=0
plugin=org.kde.plasma.folder
wallpaperplugin=org.kde.image

[Containments][25][ConfigDialog]
DialogHeight=1047
DialogWidth=1017

[ScreenMapping]
itemsOnDisabledScreens=
screenMapping=
__EOF_CFG__

  if (( ! DRY )); then
    # El escritorio se asigna a la actividad actual de este equipo.
    local act f="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
    act=$(awk -F= '/^\[activities\]/{a=1;next} /^\[/{a=0} a&&NF{print $1;exit}' "$HOME/.config/kactivitymanagerdrc" 2>/dev/null)
    if [[ -n "$act" ]]; then sed -i "s/__ACTIVITY_ID__/$act/" "$f"; else sed -i '/^activityId=__ACTIVITY_ID__$/d' "$f"; fi
    qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
    (( restart )) && { kstart plasmashell >/dev/null 2>&1 & disown; }
  fi
  log "Apariencia de KDE aplicada (cierra sesión para ver todo)"
}

GNOME_EXTENSIONS=( live-lockscreen@nick-redwill tiling-assistant@leleat-on-github clipboard-indicator@tudmotu.com blur-my-shell@aunetx just-perfection-desktop@just-perfection Vitals@CoreCoding.com )

install_gnome_ext() {
  local uuid="$1" shellv url tmp
  shellv=$(gnome-shell --version | grep -oE '[0-9]+' | head -1)
  [[ -d "$HOME/.local/share/gnome-shell/extensions/$uuid" ]] && { log "$uuid ya instalada"; return; }
  if (( DRY )); then echo "  [dry] instalar extensión $uuid"; return; fi
  url=$(curl -fsSL "https://extensions.gnome.org/extension-info/?uuid=${uuid}&shell_version=${shellv}" \
        | python3 -c 'import sys,json; print(json.load(sys.stdin).get("download_url",""))' 2>/dev/null)
  [[ -z "$url" ]] && { warn "$uuid no disponible para GNOME $shellv"; return; }
  tmp=$(mktemp --suffix=.zip)
  curl -fsSL "https://extensions.gnome.org${url}" -o "$tmp" && gnome-extensions install --force "$tmp" && log "Instalada $uuid"
  rm -f "$tmp"
}

sec_gnome() {
  section "GNOME: extensiones y apariencia"
  have gnome-shell || { warn "GNOME no detectado, se omite"; return; }
  for e in "${GNOME_EXTENSIONS[@]}"; do install_gnome_ext "$e"; done
  if (( DRY )); then echo "  [dry] dconf load (apariencia, atajos, extensiones)"; return; fi
  dconf load /org/gnome/desktop/interface/ <<'__EOF_DCONF__'
[/]
accent-color='yellow'
color-scheme='prefer-dark'
document-font-name='Adwaita Sans Ultra-Bold 12 @wght=800'
enable-animations=true
font-antialiasing='grayscale'
font-hinting='medium'
font-name='Adwaita Sans Ultra-Bold 11 @wght=800'
gtk-enable-primary-paste=false
gtk-theme='Adwaita'
icon-theme='hicolor'
monospace-font-name='Adwaita Sans Heavy Italic 11 @wght=900'
toolkit-accessibility=false
__EOF_DCONF__
  dconf load /org/gnome/desktop/wm/ <<'__EOF_DCONF__'
[keybindings]
maximize=@as []
unmaximize=@as []
__EOF_DCONF__
  dconf load /org/gnome/desktop/peripherals/ <<'__EOF_DCONF__'
[keyboard]
numlock-state=false

[mouse]
accel-profile='flat'

[touchpad]
accel-profile='flat'
click-method='areas'
disable-while-typing=true
natural-scroll=false
send-events='enabled'
speed=-0.053497942386831254
two-finger-scrolling-enabled=true
__EOF_DCONF__
  dconf load /org/gnome/mutter/ <<'__EOF_DCONF__'
[/]
center-new-windows=false
edge-tiling=false
workspaces-only-on-primary=false

[keybindings]
toggle-tiled-left=@as []
toggle-tiled-right=@as []
__EOF_DCONF__
  dconf load /org/gnome/settings-daemon/plugins/media-keys/ <<'__EOF_DCONF__'
[/]
screensaver=['<Control>Launch2']
__EOF_DCONF__
  dconf load /org/gnome/shell/ <<'__EOF_DCONF__'
[/]
disable-user-extensions=false
disabled-extensions=['window-list@gnome-shell-extensions.gcampax.github.com', 'launch-new-instance@gnome-shell-extensions.gcampax.github.com', 'places-menu@gnome-shell-extensions.gcampax.github.com']
enabled-extensions=['live-lockscreen@nick-redwill', 'tiling-assistant@leleat-on-github', 'clipboard-indicator@tudmotu.com', 'blur-my-shell@aunetx', 'just-perfection-desktop@just-perfection', 'Vitals@CoreCoding.com', 'background-logo@fedorahosted.org', 'apps-menu@gnome-shell-extensions.gcampax.github.com']
favorite-apps=['org.mozilla.firefox.desktop', 'org.gnome.Calendar.desktop', 'org.gnome.Nautilus.desktop', 'org.gnome.Software.desktop', 'org.gnome.TextEditor.desktop', 'org.gnome.Calculator.desktop', 'google-chrome.desktop']

[extensions/blur-my-shell]
pipelines={'pipeline_default': {'name': <'Default'>, 'effects': <[<{'type': <'dual_kawase_blur'>, 'id': <'effect_000000000000'>, 'params': <{'unscaled_radius': <30>, 'brightness': <0.59999999999999998>}>}>]>}, 'pipeline_migrated_dynamic_blur': {'name': <'Migrated dynamic blur'>, 'effects': <[<{'type': <'dual_kawase_blur'>, 'id': <'effect_migrated_dynamic_blur'>, 'params': <{'unscaled_radius': <60>, 'brightness': <0.59999999999999998>}>}>]>}, 'pipeline_liquid_glass': {'name': <'Liquid Glass'>, 'effects': <[<{'type': <'luminosity'>, 'id': <'effect_liquid_glass_luminosity'>, 'params': <{'saturation_multiplicator': <1.1000000000000001>}>}>, <{'type': <'refraction'>, 'id': <'effect_liquid_glass_refraction'>, 'params': <{'tint': <0>}>}>, <{'type': <'noise'>, 'id': <'effect_liquid_glass_noise'>, 'params': <{'noise': <0.10000000000000001>}>}>]>}, 'pipeline_vapor_glass': {'name': <'Vapor Glass'>, 'effects': <[<{'type': <'luminosity'>, 'id': <'effect_vapor_glass_luminosity'>, 'params': <{'saturation_multiplicator': <1.1000000000000001>}>}>, <{'type': <'wave'>, 'id': <'effect_vapor_glass_wave'>, 'params': <@a{sv} {}>}>, <{'type': <'refraction'>, 'id': <'effect_vapor_glass_refraction'>, 'params': <{'tint': <0>}>}>, <{'type': <'noise'>, 'id': <'effect_vapor_glass_noise'>, 'params': <{'noise': <0.10000000000000001>}>}>]>}, 'pipeline_classic_light_background': {'name': <'Classic Light Background'>, 'effects': <[<{'type': <'dual_kawase_blur'>, 'id': <'effect_classic_light_blur'>, 'params': <{'unscaled_radius': <30>, 'brightness': <0.59999999999999998>}>}>, <{'type': <'color'>, 'id': <'effect_classic_light_color'>, 'params': <{'color': <(1.0, 1.0, 1.0, 0.25)>, 'blend_mode': <17>}>}>]>}, 'pipeline_classic_dark_background': {'name': <'Classic Dark Background'>, 'effects': <[<{'type': <'dual_kawase_blur'>, 'id': <'effect_classic_dark_blur'>, 'params': <{'unscaled_radius': <30>, 'brightness': <0.59999999999999998>}>}>, <{'type': <'color'>, 'id': <'effect_classic_dark_color'>, 'params': <{'color': <(0.40000000000000002, 0.40000000000000002, 0.40000000000000002, 0.34999999999999998)>, 'blend_mode': <17>}>}>]>}}
rounded-blur-found=false
settings-version=8

[extensions/blur-my-shell/appfolder]
pipeline='pipeline_migrated_dynamic_blur'

[extensions/blur-my-shell/dash-to-dock]
blur=true
static-blur=true
style-dash-to-dock=0

[extensions/blur-my-shell/panel]
corner-radius=0

[extensions/blur-my-shell/window-list]
pipeline='pipeline_migrated_dynamic_blur'

[extensions/just-perfection]
accent-color-icon=false
accessibility-menu=false
activities-button=false
animation=1
background-menu=true
clock-menu=true
dash=false
dash-separator=false
double-super-to-appgrid=true
invert-calendar-column-items=false
keyboard-layout=true
osd=true
panel=true
panel-in-overview=true
power-icon=true
quick-settings=true
quick-settings-backlight=false
quick-settings-dark-mode=false
quick-settings-do-not-disturb=false
ripple-box=true
screen-sharing-indicator=true
search=true
show-apps-button=true
startup-status=0
support-notifier-showed-version=36
support-notifier-type=0
switcher-popup-delay=false
theme=false
weather=true
workspace=true
workspace-peek=true
workspace-popup=true
workspaces-in-app-grid=true

[extensions/live-lockscreen]
background-audio-volume=5
background-fade-in-duration=0

[extensions/tiling-assistant]
activate-layout0=@as []
activate-layout1=@as []
activate-layout2=@as []
activate-layout3=@as []
auto-tile=@as []
center-window=@as []
debugging-free-rects=@as []
debugging-show-tiled-rects=@as []
default-move-mode=0
dynamic-keybinding-behavior=0
focus-hint=0
focus-hint-color='rgb(33,144,164)'
import-layout-examples=false
overridden-settings={'org.gnome.mutter.edge-tiling': <true>, 'org.gnome.desktop.wm.keybindings.maximize': <@mb nothing>, 'org.gnome.desktop.wm.keybindings.unmaximize': <@mb nothing>, 'org.gnome.mutter.keybindings.toggle-tiled-left': <@mb nothing>, 'org.gnome.mutter.keybindings.toggle-tiled-right': <@mb nothing>}
restore-window=['<Super>Down']
search-popup-layout=@as []
tile-bottom-half=['<Super>KP_2']
tile-bottom-half-ignore-ta=@as []
tile-bottomleft-quarter=['<Super>KP_1']
tile-bottomleft-quarter-ignore-ta=@as []
tile-bottomright-quarter=['<Super>KP_3']
tile-bottomright-quarter-ignore-ta=@as []
tile-edit-mode=@as []
tile-left-half=['<Super>Left', '<Super>KP_4']
tile-left-half-ignore-ta=@as []
tile-maximize=['<Super>Up', '<Super>KP_5']
tile-maximize-horizontally=@as []
tile-maximize-vertically=@as []
tile-right-half=['<Super>Right', '<Super>KP_6']
tile-right-half-ignore-ta=@as []
tile-top-half=['<Super>KP_8']
tile-top-half-ignore-ta=@as []
tile-topleft-quarter=['<Super>KP_7']
tile-topleft-quarter-ignore-ta=@as []
tile-topright-quarter=['<Super>KP_9']
tile-topright-quarter-ignore-ta=@as []
toggle-always-on-top=@as []
toggle-tiling-popup=@as []

[extensions/window-list]
display-all-workspaces=false
embed-previews=false
grouping-mode='always'
show-on-all-monitors=true
__EOF_DCONF__
  dconf load /org/gnome/Ptyxis/ <<'__EOF_DCONF__'
[/]
default-profile-uuid='7186f941ec42b5ce4239fb3d6a337105'
font-name='Nimbus Mono PS Bold 12'
interface-style='system'
profile-uuids=['7186f941ec42b5ce4239fb3d6a337105', '83dfc122c0a65eb8193454b66a397571']
use-system-font=false

[Profiles/7186f941ec42b5ce4239fb3d6a337105]
label='Main'
palette='dracula'

[Profiles/83dfc122c0a65eb8193454b66a397571]
use-custom-command=false

[Shortcuts]
reset=''
reset-and-clear=''
select-none=''
__EOF_DCONF__
  for e in "${GNOME_EXTENSIONS[@]}"; do gnome-extensions enable "$e" 2>/dev/null || true; done
  log "Apariencia de GNOME aplicada (cierra sesión para ver todo)"
}

sec_latexfull() {
  section "LaTeX completo (texlive-scheme-full)"
  run sudo dnf -y install texlive-scheme-full latexmk
}

# -----------------------------------------------------------------------------
main() {
  echo "${C_B}Fedora setup — secciones: ${ONLY:-todas}${SKIP:+ (omitiendo $SKIP)}${WITH:+ (+ $WITH)}${C_0}"
  if (( ! DRY )); then
    sudo -v || exit 1
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
  fi
  for s in "${SECTIONS[@]}"; do enabled "$s" && "sec_$s"; done
  echo; log "¡Listo! Reinicia para aplicar todo (shell, grupo docker, temas)."
}
main
