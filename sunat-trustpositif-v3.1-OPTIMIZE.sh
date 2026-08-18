#!/usr/bin/env bash
# shellcheck disable=SC2312
# ============================================================
# Script Name  : sunat-trustpositif-v3.1-OPTIMIZE.sh
# Description  : Validasi dan penggabungan multi-source daftar domain
#                TrustPositif/Komdigi serta blocklist publik terpilih terhadap
#                TLD resmi IANA, standar RFC, filter IPv4/IPv6, sanitasi prefix
#                umum, deduplikasi, dan ekspor daftar domain siap DNS/RPZ/blocklist.
# Function     : Mengunduh TLD IANA dan semua sumber pada TRUSTPOSITIF_URLS,
#                menggabungkan payload yang valid, membersihkan input mentah,
#                memvalidasi struktur domain, membuang IP/sampah/duplikat,
#                menjalankan cleanup manual legacy, lalu menghasilkan output final
#                stabil, hemat RAM, atomic, cron-friendly, dan tetap kompatibel
#                dengan semantik output default v2.9/v2.8/v3.0.
# Author       : HARRY DERTIN SUTISNA ALSYUNDAWY
# Created Date : 07 APRIL 2024
# Last Modified: 18 AGUSTUS 2026
# Version      : 3.1-optimized
# Usage        : bash sunat-trustpositif-v3.1-OPTIMIZE.sh
#
# TUTORIAL SINGKAT:
#   bash sunat-trustpositif-v3.1-OPTIMIZE.sh
#   bash sunat-trustpositif-v3.1-OPTIMIZE.sh --version
#   bash sunat-trustpositif-v3.1-OPTIMIZE.sh --help
#   bash sunat-trustpositif-v3.1-OPTIMIZE.sh --force-cleanup
#   NUM_CORES=8 CHUNK_SIZE=28000 bash sunat-trustpositif-v3.1-OPTIMIZE.sh
#   CUT_SUBDOMAINS=1 bash sunat-trustpositif-v3.1-OPTIMIZE.sh
#
# DOCNOTE v3.1-optimized:
#   Versi ini adalah rilis optimasi mandiri berbasis v3.1, tanpa ketergantungan
#   pada v3.2/v3.3. Perbaikan utama: mktemp untuk semua file sementara,
#   variabel lokal eksplisit, SC2312 fix, force_cleanup aman, trap EXIT yang
#   lebih robust, penghapusan dokumentasi ganda, dan peningkatan keamanan
#   tanpa mengubah perilaku output default.
# ============================================================

set -Eeuo pipefail
IFS=$'\n\t'

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export LC_ALL=C
export LANG=C

readonly IANA_TLD_URL="https://data.iana.org/TLD/tlds-alpha-by-domain.txt"
readonly KOMINFO_URL="https://trustpositif.komdigi.go.id/assets/db/domains_isp"

# ---- URL sumber domain ----
# KOMINFO_URL tetap ada untuk kompatibilitas script/cron lama.
# Mulai v3.0, proses download domain memakai TRUSTPOSITIF_URLS agar semua sumber
# dapat digabung, divalidasi, lalu diproses oleh engine validasi yang sama.
readonly TRUSTPOSITIF_URLS=(
    # --- TRUSTPOSITIF / KOMDIGI ---
    "$KOMINFO_URL"

    # --- STEVENBLACK FAKENEWS, GAMBLING & PORN ---
    "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling-porn-only/hosts"

    # --- HAGEZI/DNS-BLOCKLISTS ---
    "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/fake-onlydomains.txt"
    "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/tif-onlydomains.txt"
    "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/gambling-onlydomains.txt"
    "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/nsfw-onlydomains.txt"

    # --- APABILA INGIN MEMBLOKIR HOSTNAME DNS DOH / DOT ---
    # "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/doh-onlydomains.txt"

    # --- ALSYUNDAWY DOMAIN BLACKLIST (OPTIONAL) ---
    "https://raw.githubusercontent.com/alsyundawy/TrustPositif/refs/heads/main/alsyundawy_porn_v2.txt"
    "https://raw.githubusercontent.com/alsyundawy/TrustPositif/refs/heads/main/alsyundawy_gambling_v2.txt"
    "https://raw.githubusercontent.com/alsyundawy/TrustPositif/refs/heads/main/alsyundawy_fake_malware_v2.txt"
)

readonly DOMAIN_FILE="domain_blacklist"

declare -A COLORS=(
    [RED]=$'\e[0;31m'
    [GREEN]=$'\e[0;32m'
    [YELLOW]=$'\e[1;33m'
    [BLUE]=$'\e[0;34m'
    [PURPLE]=$'\e[0;35m'
    [MAGENTA]=$'\e[0;35m'
    [CYAN]=$'\e[0;36m'
    [WHITE]=$'\e[1;37m'
    [BOLD]=$'\e[1m'
    [DIM]=$'\e[2m'
    [NC]=$'\e[0m'
)

declare -A BG_COLORS=(
    [BG_RED]=$'\e[41m'
    [BG_GREEN]=$'\e[42m'
    [BG_YELLOW]=$'\e[43m'
    [BG_BLUE]=$'\e[44m'
    [BG_PURPLE]=$'\e[45m'
    [BG_CYAN]=$'\e[46m'
)

SCRIPT_NAME="sunat-trustpositif-v3.1-OPTIMIZE.sh"
SCRIPT_VERSION="3.1-optimized"
OUTPUT_DIR="${OUTPUT_DIR:-/var/www/html/trustpositif}"
VALID_OUTPUT="${OUTPUT_DIR}/sunat-trustpositif.txt"
VALID_OUTPUT_TMP=""
CLEANUP_QUIET=0
AWK_CMD="${AWK_CMD:-}"
AWK_FLAVOR=""
APT_UPDATED=0

# Konfigurasi Verifikasi SSL/TLS (Bypass SSL):
# Set ke 1 (atau true) untuk bypass/mengabaikan verifikasi sertifikat SSL (default).
# Set ke 0 (atau false) untuk mengaktifkan kembali (enable) verifikasi SSL secara ketat.
CURL_INSECURE="${CURL_INSECURE:-1}"
DOWNLOAD_CONNECT_TIMEOUT="${DOWNLOAD_CONNECT_TIMEOUT:-30}"
DOWNLOAD_MAX_TIME="${DOWNLOAD_MAX_TIME:-300}"
DOWNLOAD_RETRY="${DOWNLOAD_RETRY:-5}"
DOWNLOAD_RETRY_DELAY="${DOWNLOAD_RETRY_DELAY:-15}"

get_total_cores() {
    local cores
    cores="$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)"
    [[ "$cores" =~ ^[0-9]+$ ]] || cores=1
    if (( cores < 1 )); then cores=1; fi
    printf '%s\n' "$cores"
}

get_mem_mib() {
    local mem_mib=""
    local cgroup_limit=""

    if [[ -r /sys/fs/cgroup/memory.max ]]; then
        cgroup_limit="$(cat /sys/fs/cgroup/memory.max 2>/dev/null || true)"
        if [[ "$cgroup_limit" =~ ^[0-9]+$ && "$cgroup_limit" -gt 0 && "$cgroup_limit" -lt 9223372036854771712 ]]; then
            mem_mib=$(( cgroup_limit / 1024 / 1024 ))
        fi
    fi

    if [[ -z "$mem_mib" && -r /sys/fs/cgroup/memory/memory.limit_in_bytes ]]; then
        cgroup_limit="$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null || true)"
        if [[ "$cgroup_limit" =~ ^[0-9]+$ && "$cgroup_limit" -gt 0 && "$cgroup_limit" -lt 9223372036854771712 ]]; then
            mem_mib=$(( cgroup_limit / 1024 / 1024 ))
        fi
    fi

    if [[ -z "$mem_mib" && -r /proc/meminfo ]]; then
        while read -r key value _unit; do
            if [[ "$key" == "MemTotal:" && "$value" =~ ^[0-9]+$ ]]; then
                mem_mib=$(( value / 1024 ))
                break
            fi
        done < /proc/meminfo
    fi

    if [[ -z "$mem_mib" ]]; then
        mem_mib="$(free -m 2>/dev/null | sed -n 's/^Mem:[[:space:]]*\([0-9][0-9]*\).*/\1/p' | head -n 1)"
    fi

    [[ "$mem_mib" =~ ^[0-9]+$ ]] || mem_mib=1024
    if (( mem_mib < 1 )); then mem_mib=1024; fi
    printf '%s\n' "$mem_mib"
}

TOTAL_CORES="$(get_total_cores)"
TOTAL_MEM_MIB="$(get_mem_mib)"
TOTAL_MEM_GB=$(( TOTAL_MEM_MIB / 1024 ))

if [[ -z "${NUM_CORES:-}" ]]; then
    NUM_CORES="$TOTAL_CORES"
    if (( NUM_CORES < 4 )); then NUM_CORES=4; fi
    if (( NUM_CORES > 32 )); then NUM_CORES=32; fi
    if   (( TOTAL_MEM_MIB < 2048 ));                   then NUM_CORES=1
    elif (( TOTAL_MEM_MIB < 4096 && NUM_CORES > 2 ));  then NUM_CORES=2
    elif (( TOTAL_MEM_MIB < 8192 && NUM_CORES > 4 ));  then NUM_CORES=4
    fi
fi

[[ "$NUM_CORES" =~ ^[0-9]+$ ]] || NUM_CORES=1
if (( NUM_CORES < 1 )); then NUM_CORES=1; fi
if (( NUM_CORES > TOTAL_CORES )); then NUM_CORES="$TOTAL_CORES"; fi

if [[ -z "${CHUNK_SIZE:-}" ]]; then
    CHUNK_SIZE=$(( 20000 + (NUM_CORES * 1000) ))
fi
[[ "$CHUNK_SIZE" =~ ^[0-9]+$ ]] || CHUNK_SIZE=28000
if (( CHUNK_SIZE < 1000  )); then CHUNK_SIZE=1000; fi
if (( CHUNK_SIZE > 50000 )); then CHUNK_SIZE=50000; fi

if [[ -z "${SORT_BUFFER:-}" ]]; then
    if   (( TOTAL_MEM_MIB < 2048 )); then SORT_BUFFER="128M"
    elif (( TOTAL_MEM_MIB < 4096 )); then SORT_BUFFER="256M"
    elif (( TOTAL_MEM_MIB < 8192 )); then SORT_BUFFER="512M"
    else                                   SORT_BUFFER="50%"
    fi
fi

CUT_SUBDOMAINS="${CUT_SUBDOMAINS:-0}"
case "$CUT_SUBDOMAINS" in
    1|true|TRUE|yes|YES|on|ON)   CUT_SUBDOMAINS=1 ;;
    0|false|FALSE|no|NO|off|OFF) CUT_SUBDOMAINS=0 ;;
    *)                           CUT_SUBDOMAINS=0 ;;
esac

export CUT_SUBDOMAINS
export AWK_CMD AWK_FLAVOR

SCRIPT_BASENAME="${SCRIPT_NAME%.*}"
SCRIPT_BASENAME="${SCRIPT_BASENAME//[^A-Za-z0-9._-]/_}"

TEMP_DIR="$(mktemp -d -t "${SCRIPT_BASENAME}.XXXXXX")" || {
    echo "[X] [ERROR] Gagal membuat temporary directory" >&2
    exit 1
}

show_runtime_config() {
    printf '%s\n' "${COLORS[CYAN]}============ Konfigurasi Otomatis ============${COLORS[NC]}"
    printf '%s\n' "${COLORS[YELLOW]}Total Core        : ${COLORS[GREEN]}$TOTAL_CORES${COLORS[NC]}"
    printf '%s\n' "${COLORS[YELLOW]}Digunakan Core    : ${COLORS[GREEN]}$NUM_CORES${COLORS[NC]}"
    printf '%s\n' "${COLORS[YELLOW]}Total RAM Efektif : ${COLORS[GREEN]}${TOTAL_MEM_MIB} MiB (${TOTAL_MEM_GB} GiB)${COLORS[NC]}"
    printf '%s\n' "${COLORS[YELLOW]}Chunk Size        : ${COLORS[GREEN]}$CHUNK_SIZE${COLORS[NC]}"
    printf '%s\n' "${COLORS[YELLOW]}Sort Buffer       : ${COLORS[GREEN]}$SORT_BUFFER${COLORS[NC]}"
    printf '%s\n' "${COLORS[YELLOW]}Cut Subdomain     : ${COLORS[GREEN]}$CUT_SUBDOMAINS ${COLORS[DIM]}(default 0 = kompatibel v2.8)${COLORS[NC]}"
    printf '%s\n' "${COLORS[YELLOW]}AWK Engine        : ${COLORS[GREEN]}${AWK_CMD:-belum dicek}${COLORS[NC]}"
    printf '%s\n' "${COLORS[YELLOW]}Temp Dir          : ${COLORS[GREEN]}$TEMP_DIR${COLORS[NC]}"
    printf '%s\n' "${COLORS[CYAN]}===============================================${COLORS[NC]}"
}

print_colored() {
    local color="$1" message="$2" bg_color="${3:-}"
    local fg="${COLORS[$color]:-${COLORS[NC]}}"
    local reset="${COLORS[NC]}"
    if [[ -n "$bg_color" ]]; then
        local bg="${BG_COLORS[$bg_color]:-}"
        printf '%s%s%s%s\n' "$bg" "$fg" "$message" "$reset"
    else
        printf '%s%s%s\n' "$fg" "$message" "$reset"
    fi
}

log_info()     { print_colored "CYAN"   "[i] [INFO] $1"; }
log_success()  { print_colored "PURPLE" "[OK] [BERHASIL] $1"; }
log_warning()  { print_colored "YELLOW" "[!] [PERINGATAN] $1"; }
log_error()    { print_colored "RED"    "[X] [ERROR] $1"; }
log_progress() { print_colored "GREEN"  "[>] [PROSES] $1"; }

show_banner() {
    printf '%s\n' "${COLORS[GREEN]}"
    printf '%s\n' "    _   _   _   _   _     _   _     _   _   _   _   _   _   _   _   _   _  "
    printf '%s\n' "   / \\ / \\ / \\ / \\ / \\   / \\ / \\   / \\ / \\ / \\ / \\ / \\ / \\ / \\ / \\ / \\ "
    printf '%s\n' "  ( H | A | R | R | Y ) ( D | S ) ( A | L | S | Y | U | N | D | A | W | Y )"
    printf '%s\n' "   \\_/ \\_/ \\_/ \\_/ \\_/   \\_/ \\_/   \\_/ \\_/ \\_/ \\_/ \\_/ \\_/ \\_/ \\_/ \\_/ "
    printf '%s\n' "${COLORS[NC]}"
    echo ""
    printf '%s\n' "${COLORS[CYAN]}############################################################################${COLORS[NC]}"
    printf '%s\n' "${COLORS[CYAN]}##${COLORS[NC]}                                                                        ${COLORS[CYAN]}##${COLORS[NC]}"
    printf '%s\n' "${COLORS[CYAN]}##${COLORS[MAGENTA]}     SCRIPT INI DIBUAT & DIMODIFIKASI OLEH HARRY DS ALSYUNDAWY          ${COLORS[CYAN]}##${COLORS[NC]}"
    printf '%s\n' "${COLORS[CYAN]}##${COLORS[YELLOW]}       ALSYUNDAWY@GMAIL.COM | 08568515212 | ALSYUNDAWY.COM              ${COLORS[CYAN]}##${COLORS[NC]}"
    printf '%s\n' "${COLORS[CYAN]}##${COLORS[GREEN]}                DIBUAT PADA TANGGAL 07 APRIL 2024                       ${COLORS[CYAN]}##${COLORS[NC]}"
    printf '%s\n' "${COLORS[CYAN]}##${COLORS[RED]}            DIPERBAIKI / REVISI PADA TANGGAL 18 AGUSTUS 2026            ${COLORS[CYAN]}##${COLORS[NC]}"
    printf '%s\n' "${COLORS[CYAN]}##${COLORS[NC]}                                                                        ${COLORS[CYAN]}##${COLORS[NC]}"
    printf '%s\n' "${COLORS[CYAN]}############################################################################${COLORS[NC]}"
    echo ""
    print_colored "CYAN"   "+------------------------------------------------------------------------------+" "BG_BLUE"
    print_colored "WHITE"  "¦ SUNAT TRUST POSITIF v${SCRIPT_VERSION} - ENTERPRISE EDITION                                ¦" "BG_BLUE"
    print_colored "WHITE"  "¦ VALIDASI TLD, RFC, IPV4/IPV6 & HIGH PERFORMANCE PROCESSING                   ¦" "BG_BLUE"
    print_colored "CYAN"   "+------------------------------------------------------------------------------+" "BG_BLUE"
    print_colored "YELLOW" "¦ Script Name     : ${SCRIPT_NAME}                                      ¦" "BG_BLUE"
    print_colored "YELLOW" "¦ Deskripsi       : Validasi domain TrustPositif terhadap TLD IANA & RFC.      ¦" "BG_BLUE"
    print_colored "YELLOW" "¦ Fungsi Utama    : Download, sanitasi prefix, filter IPv4/IPv6, dedupe.       ¦" "BG_BLUE"
    print_colored "YELLOW" "¦ Optimasi        : Multi-source, AWK fallback, atomic output, hardening.      ¦" "BG_BLUE"
    print_colored "YELLOW" "¦ Output          : Daftar domain valid siap pakai untuk DNS/RPZ/blocklist.    ¦" "BG_BLUE"
    print_colored "YELLOW" "¦ Pembuat         : HARRY DERTIN SUTISNA ALSYUNDAWY                            ¦" "BG_BLUE"
    print_colored "YELLOW" "¦ Kontak          : ALSYUNDAWY@GMAIL.COM | 08568515212 | ALSYUNDAWY.COM        ¦" "BG_BLUE"
    print_colored "YELLOW" "¦ Dibuat          : 07 APRIL 2024                                              ¦" "BG_BLUE"
    print_colored "YELLOW" "¦ Versi           : ${SCRIPT_VERSION}                                                        ¦" "BG_BLUE"
    print_colored "YELLOW" "¦ Terakhir Diubah : 18 AGUSTUS 2026                                           ¦" "BG_BLUE"
    print_colored "CYAN"   "+------------------------------------------------------------------------------+" "BG_BLUE"
}

show_system_resources() {
    local phase="$1"
    local label total _used free _shared _bufc avail
    local total_mem="unknown"
    local avail_mem="unknown"
    local line_count=0
    print_colored "YELLOW" " [SYS] Status Sistem - $phase" "BG_PURPLE"
    while IFS=' ' read -r label total _used free _shared _bufc avail; do
        if [[ "$label" == "Mem:" ]]; then
            total_mem="$total"
            avail_mem="${avail:-${free:-unknown}}"
            break
        fi
        line_count=$(( line_count + 1 ))
        if (( line_count > 10 )); then break; fi
    done < <(free -h 2>/dev/null || true)
    print_colored "DIM" " * Total RAM  : ${COLORS[CYAN]}$total_mem${COLORS[NC]}"
    print_colored "DIM" " * Tersedia   : ${COLORS[GREEN]}$avail_mem${COLORS[NC]}"
    print_colored "DIM" " * CPU Cores  : ${COLORS[CYAN]}$NUM_CORES${COLORS[NC]}"
    print_colored "DIM" " * Chunk Size : ${COLORS[CYAN]}$CHUNK_SIZE${COLORS[NC]}"
    print_colored "DIM" " * Sort Buffer: ${COLORS[CYAN]}$SORT_BUFFER${COLORS[NC]}"
}

install_packages() {
    local packages=("$@")
    local sudo_cmd=()
    (( ${#packages[@]} > 0 )) || return 0
    if (( EUID != 0 )); then
        if command -v sudo &>/dev/null; then
            sudo_cmd=(sudo)
        else
            log_error "Butuh root/sudo untuk install paket: ${packages[*]}"
            return 1
        fi
    fi
    if command -v apt-get &>/dev/null; then
        if (( APT_UPDATED == 0 )); then
            DEBIAN_FRONTEND=noninteractive "${sudo_cmd[@]}" apt-get update -y
            APT_UPDATED=1
        fi
        DEBIAN_FRONTEND=noninteractive "${sudo_cmd[@]}" apt-get install -y --no-install-recommends "${packages[@]}"
    elif command -v apt &>/dev/null; then
        if (( APT_UPDATED == 0 )); then
            DEBIAN_FRONTEND=noninteractive "${sudo_cmd[@]}" apt update -y
            APT_UPDATED=1
        fi
        DEBIAN_FRONTEND=noninteractive "${sudo_cmd[@]}" apt install -y --no-install-recommends "${packages[@]}"
    elif command -v dnf &>/dev/null; then
        "${sudo_cmd[@]}" dnf install -y "${packages[@]}"
    elif command -v yum &>/dev/null; then
        "${sudo_cmd[@]}" yum install -y "${packages[@]}"
    elif command -v zypper &>/dev/null; then
        "${sudo_cmd[@]}" zypper --non-interactive install "${packages[@]}"
    elif command -v apk &>/dev/null; then
        "${sudo_cmd[@]}" apk add --no-cache "${packages[@]}"
    else
        log_error "Package manager tidak dikenali. Install manual: ${packages[*]}"
        return 1
    fi
}

install_missing_command() {
    local cmd="$1" pkg_apt="$2" pkg_yum="$3" pkg_apk="${4:-$3}"
    local pkg="$pkg_apt"
    if command -v "$cmd" &>/dev/null; then
        return 0
    fi
    if   command -v dnf &>/dev/null || command -v yum &>/dev/null; then pkg="$pkg_yum"
    elif command -v apk &>/dev/null;                               then pkg="$pkg_apk"
    fi
    log_warning "Dependency hilang: $cmd. Mencoba install: $pkg"
    install_packages "$pkg"
    command -v "$cmd" &>/dev/null
}

validate_awk_candidate() {
    local candidate="$1"
    local output=""
    command -v "$candidate" &>/dev/null || return 1
    # shellcheck disable=SC2016
    output="$(printf 'A\n' | "$candidate" '{print tolower($0)}' 2>/dev/null || true)"
    if [[ "$output" == "a" ]]; then
        return 0
    else
        return 1
    fi
}

set_awk_command() {
    local candidate="$1"
    local version_output=""
    validate_awk_candidate "$candidate" || return 1
    AWK_CMD="$(command -v "$candidate")"
    if version_output="$("$AWK_CMD" --version 2>/dev/null | head -n 1)" && [[ -n "$version_output" ]]; then
        AWK_FLAVOR="$version_output"
    elif version_output="$("$AWK_CMD" -W version 2>/dev/null | head -n 1)" && [[ -n "$version_output" ]]; then
        AWK_FLAVOR="$version_output"
    else
        AWK_FLAVOR="$AWK_CMD"
    fi
    export AWK_CMD AWK_FLAVOR
}

select_awk_command() {
    if [[ -n "${AWK_CMD:-}" ]]; then
        if set_awk_command "$AWK_CMD"; then return 0; fi
        log_warning "AWK_CMD='$AWK_CMD' tidak valid, fallback ke deteksi otomatis"
        AWK_CMD=""
    fi
    if   set_awk_command mawk; then return 0
    elif set_awk_command gawk; then return 0
    elif set_awk_command awk;  then return 0
    fi
    return 1
}

ensure_awk_available() {
    if select_awk_command; then return 0; fi
    log_warning "Tidak ditemukan mawk/gawk/awk. Mencoba install..."
    if   command -v apt-get &>/dev/null || command -v apt &>/dev/null; then
        install_packages mawk || install_packages gawk
    elif command -v dnf &>/dev/null || command -v yum &>/dev/null; then
        install_packages gawk
    elif command -v zypper &>/dev/null; then
        install_packages gawk
    elif command -v apk &>/dev/null; then
        install_packages mawk || install_packages gawk
    else
        log_error "Tidak ada AWK dan package manager tidak dikenali."
        return 1
    fi
    if ! select_awk_command; then
        log_error "AWK tetap tidak tersedia. Install manual: mawk/gawk/awk"
        return 1
    fi
}

ensure_parallel_available() {
    if ! command -v parallel &>/dev/null; then
        log_warning "Perintah 'parallel' tidak ditemukan."
        print_colored "CYAN" "  - Ubuntu/Debian : sudo apt-get install parallel"
        print_colored "CYAN" "  - RHEL/CentOS   : sudo yum install parallel"
        print_colored "CYAN" "  - Fedora        : sudo dnf install parallel"
        print_colored "CYAN" "  - Alpine Linux  : sudo apk add parallel"
        echo ""
        install_missing_command "parallel" "parallel" "parallel" "parallel" || {
            log_error "Gagal install 'parallel'. Harap install manual."
            exit 1
        }
    fi
}

check_dependencies() {
    ensure_awk_available    || exit 1
    ensure_parallel_available
    install_missing_command "wget"   "wget"      "wget"      "wget"      || log_warning "Dependency wget tidak dapat diinstal secara otomatis, curl akan digunakan sebagai fallback."
    install_missing_command "curl"   "curl"      "curl"      "curl"      || { log_error "Dependency hilang: curl";    exit 1; }
    install_missing_command "grep"   "grep"      "grep"      "grep"      || { log_error "Dependency hilang: grep";    exit 1; }
    install_missing_command "find"   "findutils" "findutils" "findutils" || { log_error "Dependency hilang: find";    exit 1; }
    install_missing_command "sort"   "coreutils" "coreutils" "coreutils" || { log_error "Dependency hilang: sort";    exit 1; }
    install_missing_command "split"  "coreutils" "coreutils" "coreutils" || { log_error "Dependency hilang: split";   exit 1; }
    install_missing_command "du"     "coreutils" "coreutils" "coreutils" || { log_error "Dependency hilang: du";      exit 1; }
    install_missing_command "wc"     "coreutils" "coreutils" "coreutils" || { log_error "Dependency hilang: wc";      exit 1; }
    install_missing_command "mktemp" "coreutils" "coreutils" "coreutils" || { log_error "Dependency hilang: mktemp"; exit 1; }
    install_missing_command "head"   "coreutils" "coreutils" "coreutils" || { log_error "Dependency hilang: head";   exit 1; }
    install_missing_command "date"   "coreutils" "coreutils" "coreutils" || { log_error "Dependency hilang: date";    exit 1; }
    log_info "AWK Engine: ${AWK_CMD} (${AWK_FLAVOR})"
}

download_data() {
    local url="$1" output="$2" description="$3"
    local tmp_output
    local -a curl_tls_opts=()
    local -a wget_tls_opts=()
    local user_agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"

    log_progress "Mengunduh $description..."
    tmp_output="$(mktemp -p "$(dirname "$output")" "$(basename "$output").part.XXXXXX")" || {
        log_error "Gagal membuat temporary file untuk unduhan"
        return 1
    }

    case "${CURL_INSECURE:-1}" in
        1|true|TRUE|yes|YES|on|ON)
            curl_tls_opts=(--insecure)
            wget_tls_opts=(--no-check-certificate)
            ;;
        *) curl_tls_opts=(); wget_tls_opts=() ;;
    esac

    # Try Wget first as the primary download tool
    if command -v wget &>/dev/null; then
        if wget "${wget_tls_opts[@]}" -q -O "$tmp_output" \
            --user-agent="$user_agent" \
            --timeout="${DOWNLOAD_CONNECT_TIMEOUT:-30}" \
            --tries="${DOWNLOAD_RETRY:-3}" \
            --waitretry="${DOWNLOAD_RETRY_DELAY:-2}" \
            --retry-connrefused \
            "$url"; then
            if [[ -s "$tmp_output" ]]; then
                mv -f -- "$tmp_output" "$output"
                log_success "Unduh $description berhasil dengan wget"
                return 0
            fi
            log_warning "Hasil unduhan $description kosong (wget)"
        fi
    fi

    # Clean up and try Curl as fallback
    rm -f -- "$tmp_output" 2>/dev/null || true

    if command -v curl &>/dev/null; then
        if curl -fsSL "${curl_tls_opts[@]}" \
            --user-agent "$user_agent" \
            --compressed \
            --connect-timeout "${DOWNLOAD_CONNECT_TIMEOUT:-30}" \
            --max-time        "${DOWNLOAD_MAX_TIME:-300}" \
            --retry           "${DOWNLOAD_RETRY:-3}" \
            --retry-delay     "${DOWNLOAD_RETRY_DELAY:-2}" \
            -o "$tmp_output"  "$url"; then
            if [[ -s "$tmp_output" ]]; then
                mv -f -- "$tmp_output" "$output"
                log_success "Unduh $description berhasil dengan curl"
                return 0
            fi
            log_warning "Hasil unduhan $description kosong (curl)"
        fi
    fi

    rm -f -- "$tmp_output" 2>/dev/null || true
    log_error "Gagal mengunduh $description"
    return 1
}

validate_nonempty_file() {
    local file="$1" description="$2"
    if [[ ! -s "$file" ]]; then
        log_error "$description kosong atau tidak berhasil dibuat: $file"
        return 1
    fi
}

normalize_tld_file() {
    local input="$1" output="$2"
    # shellcheck disable=SC2016
    "$AWK_CMD" '
    {
        gsub(/\r/, "")
        gsub(/^[[:space:]]+/, "")
        gsub(/[[:space:]]+$/, "")
    }
    $0 != "" && $0 !~ /^#/ && $0 ~ /^[A-Za-z0-9-]+$/ { print tolower($0) }
    ' "$input" | sort -u > "$output"
    validate_nonempty_file "$output" "Daftar TLD IANA hasil normalisasi"
}

validate_download_payload() {
    local file="$1" description="$2"
    validate_nonempty_file "$file" "$description" || return 1
    if head -n 20 "$file" | grep -qiE '<html|<!DOCTYPE|<head|<body|<title|404 Not Found|403 Forbidden'; then
        log_warning "$description tampaknya HTML/error page, dilewati: $file"
        return 1
    fi
}

validate_source_url() {
    local url="$1"
    [[ -n "$url" ]] || return 1
    if [[ "$url" =~ ^https?://[a-zA-Z0-9._/-]+ ]]; then return 0; fi
    return 1
}

download_all_domain_sources() {
    local output="$1"
    local source_dir="${TEMP_DIR}/sources"
    mkdir -p "$source_dir"

    local combined_tmp="${TEMP_DIR}/combined_sources.tmp"
    local idx=0 ok_count=0 fail_count=0
    local url source_file description

    : > "$combined_tmp"

    if (( ${#TRUSTPOSITIF_URLS[@]} < 1 )); then
        log_error "TRUSTPOSITIF_URLS kosong."
        return 1
    fi

    log_info "Total sumber domain aktif: ${#TRUSTPOSITIF_URLS[@]}"

    for url in "${TRUSTPOSITIF_URLS[@]}"; do
        idx=$(( idx + 1 ))
        description="sumber domain #${idx}"
        source_file="${source_dir}/source_${idx}.txt"

        if ! validate_source_url "$url"; then
            log_warning "URL #${idx} tidak valid, dilewati: $url"
            fail_count=$(( fail_count + 1 ))
            continue
        fi

        if download_data "$url" "$source_file" "$description" \
            && validate_download_payload "$source_file" "$description"; then
            cat -- "$source_file" >> "$combined_tmp"
            printf '\n' >> "$combined_tmp"
            ok_count=$(( ok_count + 1 ))
        else
            log_warning "Sumber #${idx} gagal/invalid, dilewati: $url"
            fail_count=$(( fail_count + 1 ))
        fi
    done

    if (( ok_count < 1 )); then
        log_error "Tidak ada sumber domain yang berhasil diunduh."
        rm -f -- "$combined_tmp" 2>/dev/null || true
        return 1
    fi

    validate_nonempty_file "$combined_tmp" "Gabungan sumber domain" || return 1
    mv -f -- "$combined_tmp" "$output"
    log_success "Gabungan selesai: ${ok_count} berhasil, ${fail_count} gagal/dilewati"
}

# ============================================================
# FUNGSI PEMBERSIHAN
# ============================================================

# Daftar domain untuk pembersihan (minimal untuk performa)
# List DOMAINS_TO_CLEAN bisa di ambil dari file DOMAINS_TO_CLEAN.txt
readonly DOMAINS_TO_CLEAN=(
 "000000033.xyz" "00002555-coi2.cfd" "0000377.xyz" "0000378.xyz" "0000540.xyz" "0000542.xyz" "0000543.xyz" "0000544.xyz"
 "0000545.xyz" "0000546.xyz" "0000547.xyz" "0000549.xyz" "0000711.xyz" "0000713.xyz" "0000715.xyz" "0000717.xyz"
 "0000719.xyz" "0000971.xyz" "0000972.xyz" "0000973.xyz" "0000974.xyz" "0000975.xyz" "0000976.xyz" "0000977.xyz"
 "0000978.xyz" "0000979.xyz" "0001xnxx.com" "0002010.com" "0005h.com" "000a.biz" "000a.de" "000dn.com"
 "000free.us" "000.pe" "000space.com" "000webhostapp.com" "000.xxx" "001015.xyz" "0011cartoons.com" "001472.click"
)

cleanup() {
    local exit_code="${1:-$?}"
    [[ "${CLEANUP_RUNNING:-0}" == "1" ]] && return 0
    export CLEANUP_RUNNING=1

    if [[ "${CLEANUP_QUIET:-0}" != "1" ]]; then
        log_info "Membersihkan file sementara..."
    fi

    if jobs -pr >/dev/null 2>&1; then
        while IFS= read -r job_pid; do
            if [[ -n "$job_pid" ]]; then kill "$job_pid" 2>/dev/null || true; fi
        done < <(jobs -pr)
        wait 2>/dev/null || true
    fi

    if [[ -n "${VALID_OUTPUT_TMP:-}" && -f "$VALID_OUTPUT_TMP" ]]; then
        rm -f -- "$VALID_OUTPUT_TMP" 2>/dev/null || true
    fi
    if [[ -n "${TEMP_DIR:-}" && -d "$TEMP_DIR" ]]; then
        rm -rf -- "${TEMP_DIR:?}" 2>/dev/null || true
    fi
    if [[ -n "${DOMAIN_FILE:-}" && -f "$DOMAIN_FILE" && "$DOMAIN_FILE" != */* && ! -L "$DOMAIN_FILE" ]]; then
        rm -f -- "${DOMAIN_FILE:?}" 2>/dev/null || true
    fi

    if [[ "${CLEANUP_QUIET:-0}" != "1" ]]; then
        log_success "Pembersihan selesai."
    fi
    return "$exit_code"
}

force_cleanup() {
    print_colored "YELLOW" " [CLEANUP] Memulai Pembersihan Paksa..."
    if command -v pgrep &>/dev/null; then
        while IFS= read -r pid; do
            if [[ -z "$pid" || "$pid" == "$$" ]]; then continue; fi
            kill "$pid" 2>/dev/null || true
        done < <(pgrep -f -- "$SCRIPT_NAME" 2>/dev/null || true)
    fi
    if [[ -n "${TEMP_DIR:-}" && -d "$TEMP_DIR" ]]; then
        rm -rf -- "${TEMP_DIR:?}" 2>/dev/null || true
    fi
    rm -f -- "$DOMAIN_FILE" "${VALID_OUTPUT}.tmp" "${VALID_OUTPUT}.tmp."[0-9]* 2>/dev/null || true
    log_success "Cleanup selesai. Sistem bersih."
}

on_exit() {
    local status=$?
    cleanup "$status" || true
    exit "$status"
}
on_int() {
    cleanup 130 || true
    exit 130
}
on_term() {
    cleanup 143 || true
    exit 143
}
trap on_exit EXIT
trap on_int INT
trap on_term TERM

process_chunk() {
    local chunk_file="$1"
    local valid_tlds_file="$2"
    local output_file="${chunk_file}.processed"

    # shellcheck disable=SC2016
    "${AWK_CMD:?AWK_CMD belum diset}" \
        -v tlds_file="$valid_tlds_file" \
        -v cut_subdomains="${CUT_SUBDOMAINS:-0}" \
    '
    function is_common_cc_sld(label) {
        return (label ~ /^(ac|ad|biz|co|com|edu|firm|gen|go|gov|info|mil|my|ne|net|nic|nom|or|org|rec|sch|store|web)$/)
    }

    function collapse_to_parent_domain(d,    a, n, tld, sld) {
        n = split(d, a, ".")
        if (n <= 2) return d
        tld = a[n]; sld = a[n - 1]
        if (length(tld) == 2 && is_common_cc_sld(sld) && n >= 3) {
            return a[n - 2] "." sld "." tld
        }
        return sld "." tld
    }

    BEGIN {
        while ((getline line < tlds_file) > 0) {
            gsub(/\r/, "", line)
            if (line ~ /^[ \t]*$/) continue
            if (line ~ /^#/) continue
            valid_tlds[tolower(line)] = 1
        }
        close(tlds_file)
    }

    /^[ \t\r]*$/ { next }
    /^[ \t\r]*[#;]/ && $0 !~ /[a-zA-Z0-9.-]/ { next }

    {
        if (length($0) > 512) next
        domain = $0
        sub(/^[a-zA-Z]+:\/\//, "", domain)
        gsub(/[ \t]*[#;].*$/, "", domain)
        gsub(/[ \t]*\/\/.*$/, "", domain)
        sub(/^[ \t]+/, "", domain)
        sub(/[ \t]+$/, "", domain)
        if (domain == "") next

        sub(/^[ \t]*([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+|::1)[ \t]+/, "", domain)
        sub(/^[*|]+/, "", domain)
        sub(/:[0-9]+$/, "", domain)
        if (domain == "") next
        if (index(domain, ":") > 0) next
        if (domain ~ /^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$/) next

        domain_l = tolower(domain)
        sub(/^www\./,  "", domain_l)
        sub(/^mail\./, "", domain_l)
        sub(/^1\./,    "", domain_l)
        sub(/^0\./,    "", domain_l)
        sub(/[\/\^ \t].*$/, "", domain_l)
        sub(/\.$/, "", domain_l)
        gsub(/[^a-z0-9.-]/, "", domain_l)
        if (domain_l == "") next
        if (domain_l ~ /^[0-9]+(\.[0-9]+){1,3}$/) next

        if (cut_subdomains == 1) {
            domain_l = collapse_to_parent_domain(domain_l)
        }

        n = split(domain_l, parts, ".")
        if (n < 2) next
        if (length(domain_l) > 253) next

        tld = parts[n]
        if (!(tld in valid_tlds)) next

        bad = 0
        for (i = 1; i <= n; i++) {
            lab = parts[i]
            if (lab == "")                                             { bad = 1; break }
            if (length(lab) > 63)                                      { bad = 1; break }
            if (substr(lab,1,1)=="-" || substr(lab,length(lab),1)=="-"){ bad = 1; break }
            if (length(lab)>=4 && substr(lab,3,2)=="--" && lab !~ /^xn--/) { bad = 1; break }
        }
        if (bad) next

        print domain_l
    }
    ' "$chunk_file" > "$output_file"
}

export AWK_CMD AWK_FLAVOR
export -f process_chunk

main() {
    local start_time end_time duration
    local domain_count_initial domain_file_size
    local processed_count final_count final_file_size
    local valid_percentage final_percentage removed_count
    local processed_files_count work_output_tmp

    start_time=$(date +%s)

    check_dependencies
    show_runtime_config
    show_banner

    log_info "Waktu Mulai: $(date '+%d %B %Y - %H:%M:%S')"
    show_system_resources "Sebelum Proses"

    if [[ ! -d "$OUTPUT_DIR" ]]; then
        mkdir -p "$OUTPUT_DIR" || { log_error "Gagal membuat direktori '${OUTPUT_DIR}'"; exit 1; }
    fi
    if [[ ! -w "$OUTPUT_DIR" ]]; then
        log_error "Output dir tidak writable: $OUTPUT_DIR"
        exit 1
    fi

    print_colored "YELLOW" " [DL] Fase Unduhan" "BG_BLUE"

    if ! download_data "${IANA_TLD_URL}" "${TEMP_DIR}/iana_tlds.raw" "daftar TLD IANA"; then
        log_error "Gagal mengunduh TLD IANA."
        exit 1
    fi
    normalize_tld_file "${TEMP_DIR}/iana_tlds.raw" "${TEMP_DIR}/iana_tlds.txt"

    if ! download_all_domain_sources "${DOMAIN_FILE}"; then
        log_error "Gagal mengunduh dan menggabungkan sumber domain."
        exit 1
    fi
    validate_download_payload "${DOMAIN_FILE}" "Gabungan daftar domain"

    domain_count_initial=$(wc -l < "${DOMAIN_FILE}")
    domain_file_size=$(du -h "${DOMAIN_FILE}" | cut -f1)

    print_colored "YELLOW" " [PROC] Fase Pemrosesan" "BG_BLUE"

    log_progress "Membagi daftar domain..."
    split -l "${CHUNK_SIZE}" -- "${DOMAIN_FILE}" "${TEMP_DIR}/chunk_"

    processed_files_count=$(find "${TEMP_DIR}" -type f -name 'chunk_*' ! -name '*.processed' | wc -l)
    if (( processed_files_count < 1 )); then
        log_error "Tidak ada chunk yang dibuat."
        exit 1
    fi

    log_progress "Memproses chunk paralel (${NUM_CORES} Cores)..."
    find "${TEMP_DIR}" -type f -name 'chunk_*' ! -name '*.processed' -print0 \
        | sort -z \
        | parallel -0 --will-cite --halt soon,fail=1 --line-buffer -j"${NUM_CORES}" \
            process_chunk {} "${TEMP_DIR}/iana_tlds.txt"

    processed_files_count=$(find "${TEMP_DIR}" -type f -name 'chunk_*.processed' | wc -l)
    if (( processed_files_count < 1 )); then
        log_error "Tidak ada file .processed yang dihasilkan."
        exit 1
    fi
    log_success "Pemrosesan paralel selesai."

    log_progress "Menggabungkan dan deduplikasi..."
    work_output_tmp="${TEMP_DIR}/valid_output.tmp"
    find "${TEMP_DIR}" -type f -name 'chunk_*.processed' -exec cat {} + \
        | sort -u -S "$SORT_BUFFER" -T "${TEMP_DIR}" > "$work_output_tmp"

    validate_nonempty_file "$work_output_tmp" "Hasil validasi otomatis" || exit 1
    processed_count=$(wc -l < "$work_output_tmp")

    print_colored "YELLOW" " [CLEAN] Fase Pembersihan Manual" "BG_BLUE"

    local clean_list_file="${TEMP_DIR}/domains_to_clean.txt"
    printf '%s\n' "${DOMAINS_TO_CLEAN[@]}" > "$clean_list_file"

    VALID_OUTPUT_TMP="$(mktemp -p "$(dirname "$VALID_OUTPUT")" "$(basename "$VALID_OUTPUT").tmp.XXXXXX")" || {
        log_error "Gagal membuat temporary file untuk output akhir"
        exit 1
    }

    # Menggunakan AWK hash table lookup untuk performa instan dan akurasi 100%
    # shellcheck disable=SC2016
    "$AWK_CMD" '
        FNR == NR {
            clean_domains[tolower($0)] = 1
            next
        }
        {
            domain = tolower($0)
            matched = 0
            n = split(domain, parts, ".")
            current = ""
            for (i = n; i >= 1; i--) {
                if (current == "") {
                    current = parts[i]
                } else {
                    current = parts[i] "." current
                }
                if (current in clean_domains) {
                    matched = 1
                    break
                }
            }
            if (!matched) {
                print $0
            }
        }
    ' "$clean_list_file" "$work_output_tmp" > "$VALID_OUTPUT_TMP"

    mv -f -- "$VALID_OUTPUT_TMP" "$VALID_OUTPUT"
    VALID_OUTPUT_TMP=""

    final_count=$(wc -l < "${VALID_OUTPUT}")
    final_file_size=$(du -h "${VALID_OUTPUT}" | cut -f1)
    removed_count=$(( processed_count - final_count ))

    print_colored "YELLOW" " [STAT] Statistik" "BG_GREEN"

    if (( domain_count_initial > 0 )); then
        valid_percentage=$(( processed_count * 100 / domain_count_initial ))
        final_percentage=$(( final_count     * 100 / domain_count_initial ))
    else
        valid_percentage=0; final_percentage=0
    fi

    print_colored "BOLD" "[REPORT] Statistik Akhir:"
    print_colored "DIM"  " * Input Awal        : ${COLORS[YELLOW]}$domain_count_initial${COLORS[NC]} (100%) - ${COLORS[CYAN]}$domain_file_size${COLORS[NC]}"
    print_colored "DIM"  " * Valid (Automated) : ${COLORS[YELLOW]}$processed_count${COLORS[NC]} (${COLORS[CYAN]}$valid_percentage%${COLORS[NC]})"
    print_colored "DIM"  " * Dibuang Manual    : ${COLORS[YELLOW]}$removed_count${COLORS[NC]}"
    print_colored "DIM"  " * HASIL AKHIR       : ${COLORS[GREEN]}$final_count${COLORS[NC]} (${COLORS[CYAN]}$final_percentage%${COLORS[NC]}) - ${COLORS[CYAN]}$final_file_size${COLORS[NC]}"
    print_colored "DIM"  " * File Output       : ${COLORS[CYAN]}$VALID_OUTPUT${COLORS[NC]}"

    show_system_resources "Selesai"

    end_time=$(date +%s)
    duration=$(( end_time - start_time ))
    local duration_min=$(( duration / 60 ))
    local duration_sec=$(( duration % 60 ))
    print_colored "GREEN" " [DONE] Selesai dalam ${duration_min}m ${duration_sec}s [DONE]" "BG_GREEN"

    cleanup 0
    return 0
}

show_full_help() {
    show_banner
    printf '%s\n' "${COLORS[BOLD]}${COLORS[WHITE]}"
    cat << 'HELPEOF'
============================================================
DOKUMENTASI LENGKAP DAN PANDUAN PENGGUNAAN
============================================================
RINGKASAN PERBAIKAN DAN OPTIMASI SCRIPT
---------------------------------------
Script ini telah mengalami perbaikan dan optimasi menyeluruh untuk
meningkatkan performa, keamanan, dan kemudahan pemeliharaan.

FUNGSI SCRIPT:
+-- Mengunduh daftar TLD resmi IANA dan semua sumber TRUSTPOSITIF_URLS
+-- Menyaring domain terhadap RFC, struktur label, dan TLD valid
+-- Membuang IPv4, IPv6, komentar, URL scheme, path, port, wildcard, sampah
+-- Menjaga kompatibilitas output dengan v2.9/v2.8/v3.0
+-- Memproses jutaan baris dengan AWK auto-fallback + GNU Parallel
+-- Deduplikasi global dengan sort -u, output DNS/RPZ-ready

CARA PENGGUNAAN:
  bash sunat-trustpositif-v3.1-OPTIMIZE.sh              # Mode normal
  bash sunat-trustpositif-v3.1-OPTIMIZE.sh --help       # Bantuan lengkap
  bash sunat-trustpositif-v3.1-OPTIMIZE.sh --version    # Versi
  bash sunat-trustpositif-v3.1-OPTIMIZE.sh --force-cleanup  # Bersihkan sisa temp
  CUT_SUBDOMAINS=1 bash sunat-trustpositif-v3.1-OPTIMIZE.sh # Mode agresif subdomain
  NUM_CORES=8 CHUNK_SIZE=28000 bash sunat-trustpositif-v3.1-OPTIMIZE.sh

CHANGELOG:
  v3.1-optimized (18 AGUSTUS 2026) - Hardening & Optimasi Mandiri:
    - [FIX]   Semua temporary file kini menggunakan mktemp (anti-race, anti-path-traversal)
    - [FIX]   Variabel lokal eksplisit di show_system_resources (mencegah polusi global)
    - [FIX]   SC2312 fix: command substitution dipisah dari conditional di set_awk_command
    - [FIX]   Trap EXIT kini mempertahankan exit code asli meski cleanup gagal
    - [FIX]   force_cleanup hanya menghapus TEMP_DIR milik script (tidak melakukan find /tmp)
    - [FIX]   Menghapus || true dari AWK critical operation agar error tidak tersembunyi
    - [FIX]   Validasi cleanup DOMAIN_FILE: hanya menghapus file relatif yang bukan symlink
    - [FIX]   Menghapus clear command untuk keamanan cron/non-interaktif
    - [FIX]   Menghapus dokumentasi ganda di akhir file (bersihan struktur)
    - [FIX]   Menghapus shellcheck disable yang tidak lagi diperlukan
    - [BARU]  read-only modifiers pada konstanta URL dan konfigurasi
    - [IMPV]  Konsistensi quoting dan error handling di seluruh fungsi
    - [COMPAT] Semua perilaku default, output, dan pipeline tetap identik dengan v3.1

  v3.1 (13 JULI 2026) - Hardening, Bug Fix, Wget/Curl Opt, Bypass SSL & ShellCheck Pass:
    - [BARU]  Wget Primary: Menggunakan wget sebagai engine unduhan utama (fallback ke curl)
    - [BARU]  User-Agent: Browser-like header pada wget & curl agar terhindar dari block Cloudflare HTTP 520
    - [BARU]  Bypass SSL: Pengaturan default verifikasi SSL dilewati/bypass (CURL_INSECURE=1), dengan dokumentasi manual untuk di-enable
    - [FIX]   OUTPUT_DIR: Menggunakan fallback default variable expansion agar foldernya bisa di-override via env variable untuk testing
    - [FIX]   set -Eeuo pipefail: flag -E agar ERR trap mewarisi ke fungsi/subshell
    - [FIX]   DOWNLOAD_RETRY_DELAY dideklarasikan baris terpisah (quoting bug fix)
    - [FIX]   validate_source_url: grep -E diganti regex Bash native [[ =~ ]] (no fork)
    - [FIX]   show_system_resources: array split SC2206 diganti read loop aman
    - [FIX]   set_awk_command: pola A && B || C (SC2015) diganti if/else eksplisit
    - [FIX]   force_cleanup: glob pattern disesuaikan dengan SCRIPT_BASENAME mktemp
    - [FIX]   Pattern cleanup manual: sed diganti awk (escape '.' dan '-' benar)
    - [FIX]   print_colored: \n pada printf agar output tidak menyatu saat redirect
    - [BARU]  APT_UPDATED=0 guard: apt-get update hanya dijalankan sekali per sesi
    - [IMPV]  Deklarasi warna: \033[ diganti $'\e[' (ANSI C quoting, lebih bersih)
    - [IMPV]  echo -e diganti printf '%s\n' secara konsisten di seluruh fungsi output
    - [COMPAT] Semua perilaku default, output, dan pipeline tetap identik dengan v3.0

  v3.0 (03 JUNI 2026) - Multi-Source Input & Environment Stabilization:
    - [BARU]  TRUSTPOSITIF_URLS: multi-source Komdigi, StevenBlack, Hagezi, Alsyundawy
    - [COMPAT] KOMINFO_URL dipertahankan sebagai elemen pertama TRUSTPOSITIF_URLS
    - [ENV]   PATH eksplisit, LC_ALL=C, LANG=C, clear aman untuk cron/non-interaktif
    - [DATA]  DOMAIN_FILE diubah ke domain_blacklist (multi-source pipeline)
    - [HARDENING] Validasi URL, payload, HTML/error page detection per sumber
    - [LINT]  SC2034 dan SC2015 diperbaiki tanpa mematikan warning
    - [COMPAT] Core AWK, TLD IANA, sort -u, manual cleanup, CUT_SUBDOMAINS=0 dijaga

HAK CIPTA:
  (c) 2024-2026 HARRY DERTIN SUTISNA ALSYUNDAWY
  ALSYUNDAWY@GMAIL.COM | 08568515212 | ALSYUNDAWY.COM
HELPEOF
    printf '%s\n' "${COLORS[NC]}"
}

case "${1:-}" in
    --help|-h)
        CLEANUP_QUIET=1
        if   command -v less &>/dev/null; then show_full_help | less -R
        elif command -v more &>/dev/null; then show_full_help | more
        else                                   show_full_help
        fi
        exit 0
        ;;
    --force-cleanup)
        force_cleanup
        exit 0
        ;;
    --version|-v)
        CLEANUP_QUIET=1
        echo "$SCRIPT_NAME versi $SCRIPT_VERSION"
        exit 0
        ;;
    "")
        main
        ;;
    *)
        log_error "Opsi tidak dikenal: ${1}"
        echo "Gunakan --help untuk melihat opsi yang tersedia."
        exit 1
        ;;
esac

# ============================================================
# AKHIR SCRIPT - sunat-trustpositif-v3.1-OPTIMIZE.sh
# ============================================================
