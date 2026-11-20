#!/usr/bin/env bash
# Regenera fedora-setup.sh a partir del estado actual de ESTE equipo.
# Uso: bash regenerar.sh [salida]   (por defecto: fedora-setup.sh)
#
# Solo incluye configuración visual y herramientas de desarrollo.
# NO incluye: git personal, drivers (NVIDIA/firmware), herramientas de
# seguridad/forense, fondos ni rutas personales.
set -euo pipefail
OUT="${1:-fedora-setup.sh}"
H="$HOME"

# ---------------------------- Listas curadas ---------------------------------
DNF_LIST=(
  # Terminal / shell
  kitty zsh contour-terminal ptyxis fzf eza bat btop fastfetch tree vim-enhanced
  # Herramientas base de desarrollo
  git git-lfs gh curl wget2-wget unzip zip rsync make gcc gcc-c++ just strace lsof
  # Lenguajes
  python3-pip python3-devel python3.12 python3-tkinter jdk-21 ruby ruby-devel
  # Contenedores
  podman podman-compose toolbox moby-engine docker-compose docker-buildx
  # Embebidos
  platformio
  # Librerías de desarrollo (Tauri / GTK)
  gtk3-devel webkit2gtk4.1-devel librsvg2-devel libappindicator-gtk3-devel libsoup3-devel ncurses-devel
  # Bases de datos
  valkey-compat-redis
  # Apps
  code google-chrome-stable
  # Visual / GNOME
  gnome-tweaks gnome-extensions-app gnome-browser-connector hydrapaper
  jetbrains-mono-fonts-all fira-code-fonts
)
FLATPAK_LIST=(
  cc.arduino.arduinoide com.getpostman.Postman com.jetbrains.IntelliJ-IDEA-Ultimate
  io.github.shiftey.Desktop md.obsidian.Obsidian org.gaphor.Gaphor org.gnome.Extensions
  org.telegram.desktop
)
PIP_LIST=(ipython ipykernel numpy pandas matplotlib seaborn scipy scikit-learn ruff debugpy rich)
NPM_LIST=(@anthropic-ai/claude-code @google/gemini-cli openclaw)
LATEX_LIST=(texlive-scheme-medium latexmk)

# KDE Plasma
KDE_COPR_LIST=(infinality/kwin-effects-better-blur-dx)
KDE_DNF_LIST=(kwin-effects-better-blur-dx)
# Archivos de ~/.config que se copian tal cual
KDE_RC=(kdeglobals kglobalshortcutsrc kxkbrc kcminputrc konsolerc ksplashrc katerc
  gtk-3.0/settings.ini gtk-4.0/settings.ini)
# Temas/widgets de la KDE Store (relativos a ~/.local/share) que se empaquetan
KDE_ASSET_PATHS=(plasma/plasmoids plasma/look-and-feel aurorae/themes kwin/effects)
# Widgets personales que no se incluyen
KDE_EXCLUDE_PLASMOIDS=(pe.trazi.face)

# ------------------------- Datos leídos del sistema --------------------------
VSCODE=$(code --list-extensions 2>/dev/null | tr '\n' ' ')
EXTS=$(gnome-extensions list --enabled --user 2>/dev/null | tr '\n' ' ' || true)
NODEV=$(node --version 2>/dev/null || echo "--lts")
DCONF_PATHS=(/org/gnome/desktop/interface/ /org/gnome/desktop/wm/ /org/gnome/desktop/peripherals/
  /org/gnome/mutter/ /org/gnome/settings-daemon/plugins/media-keys/ /org/gnome/shell/
  /org/gnome/Ptyxis/ /org/gnome/TextEditor/)

embed() { # embed <destino> <archivo>
  [[ -f "$2" ]] || return 0
  printf "  write_file '%s' <<'__EOF_CFG__'\n" "$1"
  sed "s|$H|\$HOME_PLACEHOLDER|g" "$2"
  printf '__EOF_CFG__\n\n'
}

# Quita rutas personales, ubicación (clima/relojes) y estado de ventanas.
dconf_clean() {
  dconf dump "$1" | awk '
    /^\[/ { skip = ($0 ~ /^\[(weather|world-clocks)\]/) }
    skip { next }
    /\/home\/|file:\/\// { next }
    /^(app-picker-layout|window-|last-|recent|playlist-|welcome-dialog|.*-size=|.*maximized=|.*position=)/ { next }
    { print }'
}

# Como embed, pero lee el contenido de stdin.
embed_stdin() { # embed_stdin <destino> < contenido
  printf "  write_file '%s' <<'__EOF_CFG__'\n" "$1"
  sed "s|$H|\$HOME_PLACEHOLDER|g"
  printf '__EOF_CFG__\n\n'
}

# Imprime un archivo INI sin las secciones indicadas.  ini_drop <archivo> 'A|B'
ini_drop() {
  awk -v names="$2" '/^\[/ { skip = ($0 ~ ("^[[](" names ")[]]")) } skip { next } { print }' "$1"
}

# Disposición de paneles/escritorio: sin rutas personales (fondo, iconos
# copiados), sin widgets excluidos y con la actividad como marcador.
appletsrc_clean() {
  awk -v excl=" ${KDE_EXCLUDE_PLASMOIDS[*]} " '
    NR == FNR {
      if ($0 ~ /^\[/) sec = $0
      if ($0 ~ /^plugin=/ && index(excl, " " substr($0, 8) " ")) bad[sec] = 1
      next
    }
    /^\[/ { skip = 0; for (b in bad) if (index($0, b) == 1) skip = 1 }
    skip { next }
    /^(localPath|Image)=/ { next }
    /^activityId=./ { print "activityId=__ACTIVITY_ID__"; next }
    { print }' "$1" "$1"
}

# Empaqueta temas/widgets de ~/.local/share junto al script generado.
kde_assets() { # kde_assets <tar.gz>
  local share="$H/.local/share" icons paths=() p ex=()
  icons=$(kreadconfig6 --file kdeglobals --group Icons --key Theme 2>/dev/null || true)
  [[ -n "$icons" && -d "$share/icons/$icons" ]] && paths+=("icons/$icons")
  for p in "${KDE_ASSET_PATHS[@]}"; do [[ -d "$share/$p" ]] && paths+=("$p"); done
  for p in "${KDE_EXCLUDE_PLASMOIDS[@]}"; do ex+=(--exclude="plasma/plasmoids/$p"); done
  (( ${#paths[@]} )) || return 0
  tar -czf "$1" -C "$share" "${ex[@]}" "${paths[@]}"
  echo "Generado $1 ($(du -h "$1" | cut -f1): ${paths[*]})" >&2
}

# Sección GNOME del script anterior, para no perderla al regenerar desde KDE.
PREV_GNOME=""
[[ -f "$OUT" ]] && PREV_GNOME=$(awk '/^GNOME_EXTENSIONS=\(/{f=1} f{print} f&&/Apariencia de GNOME aplicada/{g=1} g&&/^}$/{exit}' "$OUT" | sed "s/have gnome-extensions ||/have gnome-shell ||/")
TMP_OUT=$(mktemp)
trap 'rm -f "$TMP_OUT"' EXIT

{
cat <<'HEAD'
#!/usr/bin/env bash
# =============================================================================
#  fedora-setup.sh — Entorno de desarrollo + configuración visual para Fedora
HEAD
echo "#  Generado el $(date +%F) desde $(. /etc/os-release; echo "$PRETTY_NAME")$(plasmashell --version 2>/dev/null | sed 's/^/, /')$(gnome-shell --version 2>/dev/null | sed 's/^/, /')"
cat <<'HEAD'
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

HEAD
echo "DNF_PACKAGES=("
printf '%s\n' "${DNF_LIST[@]}" | fold -s -w 100 | paste -sd' ' | fold -s -w 100 | sed 's/^/  /'
echo ")"
cat <<'EOS'

sec_packages() {
  section "Paquetes DNF (${#DNF_PACKAGES[@]})"
  run sudo dnf -y install --skip-unavailable "${DNF_PACKAGES[@]}"
  run git lfs install
  if have docker; then
    run sudo systemctl enable --now docker
    run sudo usermod -aG docker "$USER"
  fi
}

EOS
echo "FLATPAKS=( ${FLATPAK_LIST[*]} )"
cat <<'EOS'

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
EOS
embed '$HOME_PLACEHOLDER/.config/kitty/kitty.conf'          "$H/.config/kitty/kitty.conf"
embed '$HOME_PLACEHOLDER/.config/kitty/current-theme.conf'  "$H/.config/kitty/current-theme.conf"
embed '$HOME_PLACEHOLDER/.zshrc'                            "$H/.zshrc"
embed '$HOME_PLACEHOLDER/.p10k.zsh'                         "$H/.p10k.zsh"
embed '$HOME_PLACEHOLDER/.config/starship.toml'             "$H/.config/starship.toml"
cat <<'EOS'
  if ! git config --global user.name &>/dev/null; then
    warn "Git no tiene identidad. Configúrala con:"
    echo '      git config --global user.name  "Tu Nombre"'
    echo '      git config --global user.email "tu@correo.com"'
  fi
}

EOS
echo "NODE_VERSION=\"$NODEV\""
echo "NPM_GLOBALS=( ${NPM_LIST[*]} )"
echo "PIP_USER_PACKAGES=( ${PIP_LIST[*]} )"
cat <<'EOS'

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

EOS
echo "VSCODE_EXTENSIONS=( $VSCODE)"
cat <<'EOS'

sec_vscode() {
  section "VS Code"
  have code || run sudo dnf -y install code
  for e in "${VSCODE_EXTENSIONS[@]}"; do run code --install-extension "$e" --force; done
}

EOS
echo "LATEX_PACKAGES=( ${LATEX_LIST[*]} )"
cat <<'EOS'

sec_latex() {
  section "LaTeX (TeX Live medium + latexmk)"
  run sudo dnf -y install --skip-unavailable "${LATEX_PACKAGES[@]}"
}

EOS
echo "KDE_COPRS=( ${KDE_COPR_LIST[*]} )"
echo "KDE_PACKAGES=( ${KDE_DNF_LIST[*]} )"
cat <<'EOS'
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
EOS
for rc in "${KDE_RC[@]}"; do embed "\$HOME_PLACEHOLDER/.config/$rc" "$H/.config/$rc"; done
f="$H/.config/kwinrc";         [[ -f "$f" ]] && ini_drop "$f" 'Tiling|Xwayland' | embed_stdin '$HOME_PLACEHOLDER/.config/kwinrc'
f="$H/.config/plasmashellrc";  [[ -f "$f" ]] && ini_drop "$f" 'Updates' | embed_stdin '$HOME_PLACEHOLDER/.config/plasmashellrc'
f="$H/.config/plasma-org.kde.plasma.desktop-appletsrc"
[[ -f "$f" ]] && appletsrc_clean "$f" | embed_stdin '$HOME_PLACEHOLDER/.config/plasma-org.kde.plasma.desktop-appletsrc'
cat <<'EOS'
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

EOS
if [[ -n "$PREV_GNOME" && "${XDG_CURRENT_DESKTOP:-}" != *GNOME* ]]; then
  # No estamos en GNOME: se conserva la sección GNOME del script anterior.
  echo "$PREV_GNOME"
  echo
else
echo "GNOME_EXTENSIONS=( $EXTS)"
cat <<'EOS'

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
EOS
for p in "${DCONF_PATHS[@]}"; do
  d=$(dconf_clean "$p")
  [[ -z "$(grep -v '^\[' <<<"$d" | grep -v '^$')" ]] && continue
  echo "  dconf load $p <<'__EOF_DCONF__'"
  echo "$d"
  echo "__EOF_DCONF__"
done
cat <<'EOS'
  for e in "${GNOME_EXTENSIONS[@]}"; do gnome-extensions enable "$e" 2>/dev/null || true; done
  log "Apariencia de GNOME aplicada (cierra sesión para ver todo)"
}

EOS
fi
cat <<'EOS'
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
EOS
} > "$TMP_OUT"
mv "$TMP_OUT" "$OUT"
chmod +x "$OUT"
kde_assets "$(dirname "$OUT")/kde-assets.tar.gz"
echo "Generado $OUT ($(wc -l < "$OUT") líneas)"
