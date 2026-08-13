#!/usr/bin/env bash
# ============================================================
# Script Name   : sunat-trustpositif.sh
# Description   : Validasi dan penggabungan multi-source daftar domain
#                 TrustPositif/Komdigi serta blocklist publik terpilih terhadap
#                 TLD resmi IANA, standar RFC, filter IPv4/IPv6, sanitasi prefix
#                 umum, deduplikasi, dan ekspor daftar domain siap DNS/RPZ/blocklist.
# Function      : Mengunduh TLD IANA dan semua sumber pada TRUSTPOSITIF_URLS,
#                 menggabungkan payload yang valid, membersihkan input mentah,
#                 memvalidasi struktur domain, membuang IP/sampah/duplikat,
#                 menjalankan cleanup manual legacy, lalu menghasilkan output final
#                 stabil, hemat RAM, atomic, cron-friendly, dan tetap kompatibel
#                 dengan semantik output default v2.9/v2.8.
# Author        : HARRY DERTIN SUTISNA ALSYUNDAWY
# Created Date  : 07 APRIL 2024
# Last Modified : 03 JUNI 2026
# Version       : 3.0
# Usage         : bash sunat-trustpositif.sh
#
# TUTORIAL SINGKAT:
#   bash sunat-trustpositif.sh
#       Menjalankan mode normal: download IANA + semua TRUSTPOSITIF_URLS,
#       validasi domain, deduplikasi, cleanup manual, dan tulis output final.
#
#   bash sunat-trustpositif.sh --version
#       Menampilkan versi script.
#
#   bash sunat-trustpositif.sh --help
#       Menampilkan dokumentasi penggunaan dan changelog.
#
#   NUM_CORES=8 CHUNK_SIZE=28000 bash sunat-trustpositif.sh
#       Override performa secara manual bila diperlukan.
#
#   CUT_SUBDOMAINS=1 bash sunat-trustpositif.sh
#       Mode agresif opsional untuk collapse hostname/subdomain ke parent domain.
#       Default tetap 0 agar statistik output tidak berubah drastis.
#
# DOCNOTE v3.0:
#   Versi 3.0 menambahkan input multi-source melalui TRUSTPOSITIF_URLS tanpa
#   merusak alur validasi lama. KOMINFO_URL tetap dipertahankan sebagai konstanta
#   kompatibilitas, sedangkan daftar sumber aktif dibuat lebih ringkas: Komdigi,
#   StevenBlack, Hagezi, dan blacklist pilihan Alsyundawy.
#   Lingkungan eksekusi distabilkan dengan PATH eksplisit, locale C, strict mode,
#   DOMAIN_FILE="domain_blacklist", download per-sumber tervalidasi, retry/timeout,
#   atomic output, cleanup aman, dan perbaikan ShellCheck SC2015.
#   Core AWK, validasi TLD, deduplikasi sort -u, CUT_SUBDOMAINS default 0, serta
#   manual cleanup legacy tetap dijaga supaya perilaku produksi tidak bergeser liar.
# ============================================================
# KONFIGURASI AWAL, LINGKUNGAN, DAN SUMBER DOMAIN
# ============================================================
# Clear dibuat aman untuk cron/non-interaktif: jika TERM tidak tersedia,
# script tetap lanjut tanpa noise dan tanpa menghentikan proses.
# ============================================================


clear 2>/dev/null || true

set -Eeuo pipefail
IFS=$'\n\t'

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export LC_ALL=C
export LANG=C

IANA_TLD_URL="https://data.iana.org/TLD/tlds-alpha-by-domain.txt"
KOMINFO_URL="https://trustpositif.komdigi.go.id/assets/db/domains_isp"

# OPTIONAL SUNAT VERSION
# KOMINFO_URL="https://raw.githubusercontent.com/alsyundawy/TrustPositif/refs/heads/main/tlds-valid-domains_v2.txt"

# ---- URL sumber domain ----
# KOMINFO_URL tetap ada untuk kompatibilitas script/cron lama.
# Mulai v3.0, proses download domain memakai TRUSTPOSITIF_URLS agar semua sumber
# dapat digabung, divalidasi, lalu diproses oleh engine validasi yang sama.
TRUSTPOSITIF_URLS=(
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

DOMAIN_FILE="domain_blacklist"

# ============================================================
# KONFIGURASI GLOBAL DAN KONSTANTA
# ============================================================
# Definisi warna untuk output console (ORIGINAL SCHEME)
declare -A COLORS=(
[RED]='\033[0;31m' [GREEN]='\033[0;32m' [YELLOW]='\033[1;33m'
[BLUE]='\033[0;34m' [PURPLE]='\033[0;35m' [MAGENTA]='\033[0;35m' [CYAN]='\033[0;36m'
[WHITE]='\033[1;37m' [BOLD]='\033[1m' [DIM]='\033[2m' [NC]='\033[0m'
)
declare -A BG_COLORS=(
[BG_RED]='\033[41m' [BG_GREEN]='\033[42m' [BG_YELLOW]='\033[43m'
[BG_BLUE]='\033[44m' [BG_PURPLE]='\033[45m' [BG_CYAN]='\033[46m'
)

# Konfigurasi utama script
SCRIPT_NAME="sunat-trustpositif.sh"
SCRIPT_VERSION="3.0"
OUTPUT_DIR="/var/www/html/trustpositif"
VALID_OUTPUT="${OUTPUT_DIR}/sunat-trustpositif.txt"
VALID_OUTPUT_TMP=""
CLEANUP_QUIET=0
AWK_CMD="${AWK_CMD:-}"
AWK_FLAVOR=""

# Konfigurasi download. Default CURL_INSECURE=1 dipertahankan untuk kompatibilitas
# endpoint lama yang kadang bermasalah sertifikat. Set CURL_INSECURE=0 bila ingin
# memaksa verifikasi TLS normal.
CURL_INSECURE="${CURL_INSECURE:-1}"
DOWNLOAD_CONNECT_TIMEOUT="${DOWNLOAD_CONNECT_TIMEOUT:-30}"
DOWNLOAD_MAX_TIME="${DOWNLOAD_MAX_TIME:-300}"
DOWNLOAD_RETRY="${DOWNLOAD_RETRY:-3}"
DOWNLOAD_RETRY_DELAY="${DOWNLOAD_RETRY_DELAY:-2}"

# =============================================
# Konfigurasi Performa - 2 Juta Domain (Validasi + RPZ)
# Fokus v3.0:
#   - Output default tetap kompatibel dengan v2.9/v2.8.
#   - Formula NUM_CORES/CHUNK_SIZE tetap mendekati v2.9/v2.8 pada server normal.
#   - Proteksi RAM/cgroup hanya aktif pada mesin/container kecil agar tidak OOM.
# Override manual bila perlu:
#   NUM_CORES=2 CHUNK_SIZE=5000 bash sunat-trustpositif.sh
# =============================================

get_total_cores() {
    local cores
    cores="$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)"
    [[ "$cores" =~ ^[0-9]+$ ]] || cores=1
    (( cores < 1 )) && cores=1
    printf '%s\n' "$cores"
}

get_mem_mib() {
    local mem_mib=""
    local cgroup_limit=""

    # cgroup v2
    if [[ -r /sys/fs/cgroup/memory.max ]]; then
        cgroup_limit="$(cat /sys/fs/cgroup/memory.max 2>/dev/null || true)"
        if [[ "$cgroup_limit" =~ ^[0-9]+$ && "$cgroup_limit" -gt 0 && "$cgroup_limit" -lt 9223372036854771712 ]]; then
            mem_mib=$(( cgroup_limit / 1024 / 1024 ))
        fi
    fi

    # cgroup v1
    if [[ -z "$mem_mib" && -r /sys/fs/cgroup/memory/memory.limit_in_bytes ]]; then
        cgroup_limit="$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null || true)"
        if [[ "$cgroup_limit" =~ ^[0-9]+$ && "$cgroup_limit" -gt 0 && "$cgroup_limit" -lt 9223372036854771712 ]]; then
            mem_mib=$(( cgroup_limit / 1024 / 1024 ))
        fi
    fi

    # fallback host memory tanpa bergantung pada awk, karena AWK baru dipilih/diinstall saat check_dependencies.
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
    (( mem_mib < 1 )) && mem_mib=1024
    printf '%s\n' "$mem_mib"
}

TOTAL_CORES="$(get_total_cores)"
TOTAL_MEM_MIB="$(get_mem_mib)"
TOTAL_MEM_GB=$(( TOTAL_MEM_MIB / 1024 ))

# Default dibuat kompatibel dengan perilaku v2.8 agar hasil/statistik tidak berubah jauh.
# Masih bisa dioverride dari environment: NUM_CORES=... CHUNK_SIZE=...
if [[ -z "${NUM_CORES:-}" ]]; then
    NUM_CORES="$TOTAL_CORES"
    if (( NUM_CORES < 4 )); then
        NUM_CORES=4
    elif (( NUM_CORES > 32 )); then
        NUM_CORES=32
    fi

    # Proteksi minimal untuk mesin/container kecil. Pada server 8 core/31GiB tetap menjadi 8.
    if (( TOTAL_MEM_MIB < 2048 )); then
        NUM_CORES=1
    elif (( TOTAL_MEM_MIB < 4096 && NUM_CORES > 2 )); then
        NUM_CORES=2
    elif (( TOTAL_MEM_MIB < 8192 && NUM_CORES > 4 )); then
        NUM_CORES=4
    fi
fi

[[ "$NUM_CORES" =~ ^[0-9]+$ ]] || NUM_CORES=1
(( NUM_CORES < 1 )) && NUM_CORES=1
(( NUM_CORES > TOTAL_CORES )) && NUM_CORES="$TOTAL_CORES"

if [[ -z "${CHUNK_SIZE:-}" ]]; then
    # Kompatibel dengan formula v2.8: 8 core -> 28000.
    CHUNK_SIZE=$((20000 + (NUM_CORES * 1000)))
fi

[[ "$CHUNK_SIZE" =~ ^[0-9]+$ ]] || CHUNK_SIZE=28000
(( CHUNK_SIZE < 1000 )) && CHUNK_SIZE=1000
(( CHUNK_SIZE > 50000 )) && CHUNK_SIZE=50000

# Buffer sort bisa dioverride manual, contoh:
#   SORT_BUFFER=512M bash sunat-trustpositif.sh
if [[ -z "${SORT_BUFFER:-}" ]]; then
    if (( TOTAL_MEM_MIB < 2048 )); then
        SORT_BUFFER="128M"
    elif (( TOTAL_MEM_MIB < 4096 )); then
        SORT_BUFFER="256M"
    elif (( TOTAL_MEM_MIB < 8192 )); then
        SORT_BUFFER="512M"
    else
        SORT_BUFFER="50%"
    fi
fi

# Mode potong subdomain global opsional:
#   0 = kompatibel v2.8: hanya sanitasi prefix umum (www/mail/1/0), lalu manual cleanup regex.
#   1 = mode ringkas agresif: hostname/subdomain dipotong menjadi parent domain sebelum dedupe.
# Default WAJIB 0 agar hasil mendekati v2.8, bukan turun drastis.
CUT_SUBDOMAINS="${CUT_SUBDOMAINS:-0}"
case "$CUT_SUBDOMAINS" in
    1|true|TRUE|yes|YES|on|ON) CUT_SUBDOMAINS=1 ;;
    0|false|FALSE|no|NO|off|OFF) CUT_SUBDOMAINS=0 ;;
    *) CUT_SUBDOMAINS=0 ;;
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
    printf '%s\n' "${COLORS[CYAN]}=== Konfigurasi Otomatis ===${COLORS[NC]}"
    printf '%s\n' "${COLORS[YELLOW]}Total Core       : ${COLORS[GREEN]}$TOTAL_CORES${COLORS[NC]}"
    printf '%s\n' "${COLORS[YELLOW]}Digunakan Core   : ${COLORS[GREEN]}$NUM_CORES${COLORS[NC]}"
    printf '%s\n' "${COLORS[YELLOW]}Total RAM Efektif: ${COLORS[GREEN]}${TOTAL_MEM_MIB} MiB (${TOTAL_MEM_GB} GiB)${COLORS[NC]}"
    printf '%s\n' "${COLORS[YELLOW]}Chunk Size       : ${COLORS[GREEN]}$CHUNK_SIZE${COLORS[NC]}"
    printf '%s\n' "${COLORS[YELLOW]}Sort Buffer      : ${COLORS[GREEN]}$SORT_BUFFER${COLORS[NC]}"
    printf '%s\n' "${COLORS[YELLOW]}Cut Subdomain    : ${COLORS[GREEN]}$CUT_SUBDOMAINS ${COLORS[DIM]}(default 0 = kompatibel v2.8)${COLORS[NC]}"
    printf '%s\n' "${COLORS[YELLOW]}AWK Engine       : ${COLORS[GREEN]}${AWK_CMD:-belum dicek}${COLORS[NC]}"
    printf '%s\n' "${COLORS[YELLOW]}Temp Dir         : ${COLORS[GREEN]}$TEMP_DIR${COLORS[NC]}"
    printf '%s\n' "${COLORS[CYAN]}=============================${COLORS[NC]}"
}

# ============================================================
# FUNGSI UTILITAS DAN LOGGING (ORIGINAL STYLE)
# ============================================================
print_colored() {
    local color="$1" message="$2" bg_color="${3:-}"
    local fg="${COLORS[$color]:-${COLORS[NC]}}"
    local reset="${COLORS[NC]}"

    if [[ -n "$bg_color" ]]; then
        local bg="${BG_COLORS[$bg_color]:-}"
        printf '%b
' "${bg}${fg}${message}${reset}"
    else
        printf '%b
' "${fg}${message}${reset}"
    fi
}

log_info() { print_colored "CYAN" "[i] [INFO] $1"; }
log_success() { print_colored "PURPLE" "[OK] [BERHASIL] $1"; }
log_warning() { print_colored "YELLOW" "[!] [PERINGATAN] $1"; }
log_error() { print_colored "RED" "[X] [ERROR] $1"; }
log_progress() { print_colored "GREEN" "[>] [PROSES] $1"; }

# Banner Original (Menggunakan BG_BLUE)

show_banner() {
    # Header ASCII Art - Nama Pembuat
    printf '%s\n' "${COLORS[GREEN]}"
    printf '%s\n' "   _   _   _   _   _     _   _     _   _   _   _   _   _   _   _   _   _  "
    printf '%s\n' "  / \\ / \\ / \\ / \\ / \\   / \\ / \\   / \\ / \\ / \\ / \\ / \\ / \\ / \\ / \\ / \\ / \\ "
    printf '%s\n' " ( H | A | R | R | Y ) ( D | S ) ( A | L | S | Y | U | N | D | A | W | Y )"
    printf '%s\n' "  \\_/ \\_/ \\_/ \\_/ \\_/   \\_/ \\_/   \\_/ \\_/ \\_/ \\_/ \\_/ \\_/ \\_/ \\_/ \\_/ \\_/ "
    printf '%s\n' "${COLORS[NC]}"
    
    echo ""
    
    # Informasi Kontak dan Pembuatan
    printf '%s\n' "${COLORS[CYAN]}############################################################################${COLORS[NC]}"
    printf '%s\n' "${COLORS[CYAN]}##${COLORS[NC]}                                                                        ${COLORS[CYAN]}##${COLORS[NC]}"
    printf '%s\n' "${COLORS[CYAN]}##${COLORS[MAGENTA]}      SCRIPT INI DIBUAT & DIMODIFIKASI OLEH HARRY DS ALSYUNDAWY         ${COLORS[CYAN]}##${COLORS[NC]}"
    printf '%s\n' "${COLORS[CYAN]}##${COLORS[YELLOW]}         ALSYUNDAWY@GMAIL.COM | 08568515212 | ALSYUNDAWY.COM            ${COLORS[CYAN]}##${COLORS[NC]}"
    printf '%s\n' "${COLORS[CYAN]}##${COLORS[GREEN]}                 DIBUAT PADA TANGGAL 07 APRIL 2024                      ${COLORS[CYAN]}##${COLORS[NC]}"
    printf '%s\n' "${COLORS[CYAN]}##${COLORS[RED]}            DIPERBAIKI / REVISI PADA TANGGAL 03 JUNI 2026                ${COLORS[CYAN]}##${COLORS[NC]}"
    printf '%s\n' "${COLORS[CYAN]}##${COLORS[NC]}                                                                        ${COLORS[CYAN]}##${COLORS[NC]}"
    printf '%s\n' "${COLORS[CYAN]}############################################################################${COLORS[NC]}"
    
    echo ""
    
    # Informasi Script Utama (Menggunakan Sistem Warna yang Konsisten)
    print_colored "CYAN"    "+------------------------------------------------------------------------------+" "BG_BLUE"
    print_colored "WHITE"   "¦                SUNAT TRUST POSITIF v${SCRIPT_VERSION} - ENTERPRISE EDITION                 ¦" "BG_BLUE"
    print_colored "WHITE"   "¦          VALIDASI TLD, RFC, IPV4/IPV6 & HIGH PERFORMANCE PROCESSING          ¦" "BG_BLUE"
    print_colored "CYAN"    "+------------------------------------------------------------------------------+" "BG_BLUE"
    print_colored "YELLOW"  "¦ Script Name     : ${SCRIPT_NAME}                                      ¦" "BG_BLUE"
    print_colored "YELLOW"  "¦ Deskripsi       : Validasi domain TrustPositif terhadap TLD IANA & RFC.      ¦" "BG_BLUE"
    print_colored "YELLOW"  "¦ Fungsi Utama    : Download, sanitasi prefix, filter IPv4/IPv6, deduplikasi.  ¦" "BG_BLUE"
    print_colored "YELLOW"  "¦ Optimasi        : Multi-source, AWK fallback, atomic output, hardening aman. ¦" "BG_BLUE"
    print_colored "YELLOW"  "¦ Output          : Daftar domain valid siap pakai untuk DNS/RPZ/blocklist.    ¦" "BG_BLUE"
    print_colored "YELLOW"  "¦ Pembuat         : HARRY DERTIN SUTISNA ALSYUNDAWY                            ¦" "BG_BLUE"
    print_colored "YELLOW"  "¦ Kontak          : ALSYUNDAWY@GMAIL.COM | 08568515212 | ALSYUNDAWY.COM        ¦" "BG_BLUE"
    print_colored "YELLOW"  "¦ Dibuat          : 07 APRIL 2024                                              ¦" "BG_BLUE"
    print_colored "YELLOW"  "¦ Versi           : ${SCRIPT_VERSION}                                                        ¦" "BG_BLUE"
    print_colored "YELLOW"  "¦ Terakhir Diubah : 03 JUNI 2026                                                ¦" "BG_BLUE"
    print_colored "CYAN"    "+------------------------------------------------------------------------------+" "BG_BLUE"
}

show_system_resources() {
    local phase="$1"
    print_colored "YELLOW" "
[SYS] Status Sistem - $phase" "BG_PURPLE"

    local mem_line=""
    local total_mem="unknown"
    local avail_mem="unknown"
    local old_ifs

    mem_line="$(free -h 2>/dev/null | sed -n 's/^Mem:[[:space:]]*//p' | head -n 1 || true)"
    if [[ -n "$mem_line" ]]; then
        old_ifs="$IFS"
        IFS=' '
        # Format umum free -h setelah kolom Mem:: total used free shared buff/cache available
        # shellcheck disable=SC2206
        local mem_fields=( $mem_line )
        IFS="$old_ifs"
        total_mem="${mem_fields[0]:-unknown}"
        avail_mem="${mem_fields[5]:-${mem_fields[2]:-unknown}}"
    fi

    print_colored "DIM" " * Total RAM : ${COLORS[CYAN]}$total_mem${COLORS[NC]}"
    print_colored "DIM" " * Tersedia  : ${COLORS[GREEN]}$avail_mem${COLORS[NC]}"
    print_colored "DIM" " * CPU Cores : ${COLORS[CYAN]}$NUM_CORES${COLORS[NC]}"
    print_colored "DIM" " * Chunk Size: ${COLORS[CYAN]}$CHUNK_SIZE${COLORS[NC]}"
    print_colored "DIM" " * Sort Buffer: ${COLORS[CYAN]}$SORT_BUFFER${COLORS[NC]}"
}

install_packages() {
    local packages=("$@")
    local sudo_cmd=()

    (( ${#packages[@]} > 0 )) || return 0

    if (( EUID != 0 )); then
        if command -v sudo &> /dev/null; then
            sudo_cmd=(sudo)
        else
            log_error "Butuh root/sudo untuk install paket: ${packages[*]}"
            return 1
        fi
    fi

    if command -v apt-get &> /dev/null; then
        DEBIAN_FRONTEND=noninteractive "${sudo_cmd[@]}" apt-get update -y
        DEBIAN_FRONTEND=noninteractive "${sudo_cmd[@]}" apt-get install -y --no-install-recommends "${packages[@]}"
    elif command -v apt &> /dev/null; then
        DEBIAN_FRONTEND=noninteractive "${sudo_cmd[@]}" apt update -y
        DEBIAN_FRONTEND=noninteractive "${sudo_cmd[@]}" apt install -y --no-install-recommends "${packages[@]}"
    elif command -v dnf &> /dev/null; then
        "${sudo_cmd[@]}" dnf install -y "${packages[@]}"
    elif command -v yum &> /dev/null; then
        "${sudo_cmd[@]}" yum install -y "${packages[@]}"
    elif command -v zypper &> /dev/null; then
        "${sudo_cmd[@]}" zypper --non-interactive install "${packages[@]}"
    elif command -v apk &> /dev/null; then
        "${sudo_cmd[@]}" apk add --no-cache "${packages[@]}"
    else
        log_error "Package manager tidak dikenali. Install manual paket: ${packages[*]}"
        return 1
    fi
}

install_missing_command() {
    local cmd="$1"
    local pkg_apt="$2"
    local pkg_yum="$3"
    local pkg_apk="${4:-$3}"
    local pkg="$pkg_apt"

    command -v "$cmd" &> /dev/null && return 0

    if command -v dnf &> /dev/null || command -v yum &> /dev/null; then
        pkg="$pkg_yum"
    elif command -v apk &> /dev/null; then
        pkg="$pkg_apk"
    fi

    log_warning "Dependency hilang: $cmd. Mencoba install paket: $pkg"
    install_packages "$pkg"
    command -v "$cmd" &> /dev/null
}

validate_awk_candidate() {
    local candidate="$1"
    local output=""

    command -v "$candidate" &> /dev/null || return 1
    # shellcheck disable=SC2016
    output="$(printf 'A\n' | "$candidate" '{print tolower($0)}' 2>/dev/null || true)"
    [[ "$output" == "a" ]]
}

set_awk_command() {
    local candidate="$1"

    validate_awk_candidate "$candidate" || return 1
    AWK_CMD="$(command -v "$candidate")"
    AWK_FLAVOR="$($AWK_CMD --version 2>/dev/null | head -n 1 || $AWK_CMD -W version 2>/dev/null | head -n 1 || echo "$AWK_CMD")"
    export AWK_CMD AWK_FLAVOR
}

select_awk_command() {
    # Jika user override, hormati selama executable dan lolos uji fungsi dasar AWK.
    if [[ -n "${AWK_CMD:-}" ]]; then
        if set_awk_command "$AWK_CMD"; then
            return 0
        fi
        log_warning "AWK_CMD='$AWK_CMD' tidak valid/tidak kompatibel, fallback ke deteksi otomatis"
        AWK_CMD=""
    fi

    # Prioritas: mawk cepat untuk dataset besar; gawk lebih lengkap; awk sebagai fallback POSIX.
    if set_awk_command mawk; then
        return 0
    elif set_awk_command gawk; then
        return 0
    elif set_awk_command awk; then
        return 0
    fi

    return 1
}

ensure_awk_available() {
    if select_awk_command; then
        return 0
    fi

    log_warning "Tidak ditemukan mawk/gawk/awk. Mencoba install AWK sesuai distro..."

    if command -v apt-get &> /dev/null || command -v apt &> /dev/null; then
        # Debian/Ubuntu: mawk biasanya ringan dan cepat. Jika gagal, coba gawk.
        install_packages mawk || install_packages gawk
    elif command -v dnf &> /dev/null || command -v yum &> /dev/null; then
        # RHEL/CentOS/Fedora umumnya menyediakan gawk sebagai awk utama.
        install_packages gawk
    elif command -v zypper &> /dev/null; then
        install_packages gawk
    elif command -v apk &> /dev/null; then
        install_packages mawk || install_packages gawk
    else
        log_error "Tidak ada AWK dan package manager tidak dikenali. Install manual: mawk atau gawk"
        return 1
    fi

    if ! select_awk_command; then
        log_error "AWK tetap tidak tersedia setelah percobaan install. Install manual: mawk/gawk/awk"
        return 1
    fi
}
ensure_parallel_available() {
    if ! command -v parallel &> /dev/null; then
        log_warning "Perintah 'parallel' tidak ditemukan di sistem."
        print_colored "YELLOW" "Silakan install 'parallel' secara manual sesuai OS/Distro Anda jika instalasi otomatis gagal:"
        print_colored "CYAN" " - Ubuntu/Debian : sudo apt-get install parallel"
        print_colored "CYAN" " - RHEL/CentOS   : sudo yum install parallel"
        print_colored "CYAN" " - Fedora        : sudo dnf install parallel"
        print_colored "CYAN" " - Arch Linux    : sudo pacman -S parallel"
        print_colored "CYAN" " - Alpine Linux  : sudo apk add parallel"
        print_colored "CYAN" " - macOS (brew)  : brew install parallel"
        echo ""
        
        install_missing_command "parallel" "parallel" "parallel" "parallel" || { 
            log_error "Gagal menginstal 'parallel' secara otomatis. Harap install manual menggunakan perintah di atas."
            exit 1
        }
    fi
}

check_dependencies() {
    # AWK diperlakukan khusus agar tidak hardcoded ke mawk/gawk.
    ensure_awk_available || exit 1

    ensure_parallel_available

    install_missing_command "curl" "curl" "curl" "curl" || { log_error "Dependency hilang: curl"; exit 1; }
    install_missing_command "grep" "grep" "grep" "grep" || { log_error "Dependency hilang: grep"; exit 1; }
    install_missing_command "find" "findutils" "findutils" "findutils" || { log_error "Dependency hilang: find"; exit 1; }
    install_missing_command "sort" "coreutils" "coreutils" "coreutils" || { log_error "Dependency hilang: sort"; exit 1; }
    install_missing_command "split" "coreutils" "coreutils" "coreutils" || { log_error "Dependency hilang: split"; exit 1; }
    install_missing_command "du" "coreutils" "coreutils" "coreutils" || { log_error "Dependency hilang: du"; exit 1; }
    install_missing_command "wc" "coreutils" "coreutils" "coreutils" || { log_error "Dependency hilang: wc"; exit 1; }
    install_missing_command "mktemp" "coreutils" "coreutils" "coreutils" || { log_error "Dependency hilang: mktemp"; exit 1; }
    install_missing_command "head" "coreutils" "coreutils" "coreutils" || { log_error "Dependency hilang: head"; exit 1; }
    install_missing_command "date"   "coreutils" "coreutils" "coreutils" || { log_error "Dependency hilang: date";    exit 1; }

    log_info "AWK Engine: ${AWK_CMD} (${AWK_FLAVOR})"
}
# ============================================================
# FUNGSI DOWNLOADER (OPTIMAL & BYPASS SSL)
# ============================================================
download_data() {
    local url="$1"
    local output="$2"
    local description="$3"
    local tmp_output="${output}.part.$$"
    local -a curl_tls_opts=()
    local -a wget_tls_opts=()

    log_progress "Mengunduh $description..."
    rm -f -- "$tmp_output" 2>/dev/null || true

    case "${CURL_INSECURE:-1}" in
        1|true|TRUE|yes|YES|on|ON)
            curl_tls_opts=(--insecure)
            wget_tls_opts=(--no-check-certificate)
            ;;
        *)
            curl_tls_opts=()
            wget_tls_opts=()
            ;;
    esac

    # Prioritas 1: curl dengan kompresi, timeout total, retry, dan fail on HTTP error.
    if command -v curl &> /dev/null; then
        if curl -fsSL "${curl_tls_opts[@]}" --compressed             --connect-timeout "${DOWNLOAD_CONNECT_TIMEOUT:-30}"             --max-time "${DOWNLOAD_MAX_TIME:-300}"             --retry "${DOWNLOAD_RETRY:-3}"             --retry-delay "${DOWNLOAD_RETRY_DELAY:-2}"             -o "$tmp_output" "$url"; then
            if [[ -s "$tmp_output" ]]; then
                mv -f -- "$tmp_output" "$output"
                log_success "Unduh $description berhasil dengan curl"
                return 0
            fi
            log_warning "Hasil unduhan $description kosong saat memakai curl"
        fi
    fi

    rm -f -- "$tmp_output" 2>/dev/null || true

    # Prioritas 2: wget fallback. Opsi no-check-certificate hanya aktif jika CURL_INSECURE=1.
    if command -v wget &> /dev/null; then
        if wget "${wget_tls_opts[@]}" -q -O "$tmp_output"             --timeout="${DOWNLOAD_CONNECT_TIMEOUT:-30}"             --tries="${DOWNLOAD_RETRY:-3}" "$url"; then
            if [[ -s "$tmp_output" ]]; then
                mv -f -- "$tmp_output" "$output"
                log_success "Unduh $description berhasil dengan wget"
                return 0
            fi
            log_warning "Hasil unduhan $description kosong saat memakai wget"
        fi
    fi

    rm -f -- "$tmp_output" 2>/dev/null || true
    log_error "Gagal mengunduh $description dengan semua metode"
    return 1
}

validate_nonempty_file() {
    local file="$1"
    local description="$2"

    if [[ ! -s "$file" ]]; then
        log_error "$description kosong atau tidak berhasil dibuat: $file"
        return 1
    fi
}

normalize_tld_file() {
    local input="$1"
    local output="$2"

    # shellcheck disable=SC2016
    "$AWK_CMD" '
        {
            gsub(/\r/, "")
            gsub(/^[[:space:]]+/, "")
            gsub(/[[:space:]]+$/, "")
        }
        $0 != "" && $0 !~ /^#/ && $0 ~ /^[A-Za-z0-9-]+$/ {
            print tolower($0)
        }
    ' "$input" | sort -u > "$output"

    validate_nonempty_file "$output" "Daftar TLD IANA hasil normalisasi"
}
validate_download_payload() {
    local file="$1"
    local description="$2"

    validate_nonempty_file "$file" "$description" || return 1

    # Guard ringan agar HTML/error page tidak lanjut diproses sebagai database domain.
    if head -n 20 "$file" | grep -qiE '<!doctype|<html|</html>|<head|<body'; then
        log_error "$description terlihat seperti HTML/error page, bukan data mentah yang valid"
        return 1
    fi
}

validate_source_url() {
    local url="$1"

    [[ -n "$url" ]] || return 1
    [[ "$url" != *$'\n'* && "$url" != *$'\r'* && "$url" != *$'\t'* ]] || return 1
    [[ "$url" =~ ^https://[^[:space:]]+$ || "$url" =~ ^http://[^[:space:]]+$ ]] || return 1
}

download_all_domain_sources() {
    local output="$1"
    local source_dir="${TEMP_DIR}/domain_sources"
    local combined_tmp="${TEMP_DIR}/domains_combined.tmp"
    local source_file url description
    local idx=0 ok_count=0 fail_count=0

    mkdir -p -- "$source_dir"
    : > "$combined_tmp"

    if (( ${#TRUSTPOSITIF_URLS[@]} < 1 )); then
        log_error "TRUSTPOSITIF_URLS kosong. Minimal harus berisi KOMINFO_URL."
        return 1
    fi

    log_info "Total sumber domain aktif: ${#TRUSTPOSITIF_URLS[@]}"

    for url in "${TRUSTPOSITIF_URLS[@]}"; do
        idx=$((idx + 1))
        description="sumber domain #${idx}"
        source_file="${source_dir}/source_${idx}.txt"

        if ! validate_source_url "$url"; then
            log_warning "URL sumber #${idx} tidak valid, dilewati: $url"
            fail_count=$((fail_count + 1))
            continue
        fi

        if download_data "$url" "$source_file" "$description" && validate_download_payload "$source_file" "$description"; then
            cat -- "$source_file" >> "$combined_tmp"
            printf '\n' >> "$combined_tmp"
            ok_count=$((ok_count + 1))
        else
            log_warning "Sumber #${idx} gagal/invalid dan dilewati: $url"
            fail_count=$((fail_count + 1))
        fi
    done

    if (( ok_count < 1 )); then
        log_error "Tidak ada sumber domain yang berhasil diunduh. Output tidak dibuat."
        rm -f -- "$combined_tmp" 2>/dev/null || true
        return 1
    fi

    validate_nonempty_file "$combined_tmp" "Gabungan sumber domain" || return 1
    mv -f -- "$combined_tmp" "$output"
    log_success "Gabungan sumber domain selesai: ${ok_count} berhasil, ${fail_count} gagal/dilewati"
}

# ============================================================
# FUNGSI PEMBERSIHAN
# ============================================================

# Daftar domain untuk pembersihan (minimal untuk performa)

# List DOMAINS_TO_CLEAN bisa di ambil dari file DOMAINS_TO_CLEAN.txt
DOMAINS_TO_CLEAN=(
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

    # Hentikan background jobs milik shell ini saja; jangan membunuh proses lain sembarangan.
    if jobs -pr > /dev/null 2>&1; then
        while IFS= read -r job_pid; do
            if [[ -n "$job_pid" ]]; then
                kill "$job_pid" 2>/dev/null || true
            fi
        done < <(jobs -pr)
        wait 2>/dev/null || true
    fi

    # Hapus file output sementara jika proses gagal sebelum mv final.
    if [[ -n "${VALID_OUTPUT_TMP:-}" && -f "$VALID_OUTPUT_TMP" ]]; then
        rm -f -- "$VALID_OUTPUT_TMP" 2>/dev/null || true
    fi

    # Hapus file sementara dengan aman.
    if [[ -n "${TEMP_DIR:-}" && -d "$TEMP_DIR" ]]; then
        rm -rf -- "${TEMP_DIR:?}" 2>/dev/null || true
    fi

    # Hapus file download sementara.
    if [[ -n "${DOMAIN_FILE:-}" && -f "$DOMAIN_FILE" ]]; then
        rm -f -- "${DOMAIN_FILE:?}" 2>/dev/null || true
    fi

    if [[ "${CLEANUP_QUIET:-0}" != "1" ]]; then
        log_success "Pembersihan selesai."
    fi
    return "$exit_code"
}

force_cleanup() {
    print_colored "YELLOW" "
[CLEANUP] Memulai Pembersihan Paksa..."

    # Matikan instance lama dengan nama script yang sama, kecuali proses saat ini.
    if command -v pgrep &> /dev/null; then
        while IFS= read -r pid; do
            [[ -z "$pid" || "$pid" == "$$" ]] && continue
            kill "$pid" 2>/dev/null || true
        done < <(pgrep -f -- "$SCRIPT_NAME" 2>/dev/null || true)
    fi

    find /tmp -maxdepth 1 -type d -name "${SCRIPT_BASENAME}.*" -exec rm -rf -- {} + 2>/dev/null || true
    rm -f -- "$DOMAIN_FILE" "${VALID_OUTPUT}.tmp" "${VALID_OUTPUT}.tmp.$$" 2>/dev/null || true

    log_success "Cleanup selesai. Sistem bersih."
}

# shellcheck disable=SC2154
trap 'status=$?; cleanup "$status"; exit "$status"' EXIT
trap 'cleanup 130; exit 130' INT
trap 'cleanup 143; exit 143' TERM
# ============================================================
# FUNGSI PEMROSESAN DOMAIN (CORE LOGIC)
# ============================================================
process_chunk() {
    local chunk_file="$1"
    local valid_tlds_file="$2"
    local output_file="${chunk_file}.processed"

    # Kompatibel dengan output v2.8:
    # - AWK engine tetap auto-fallback (mawk/gawk/awk), tetapi logika sanitasi dibuat setara v2.8.
    # - Tidak memakai seen[] agar tidak boros RAM; deduplikasi global tetap oleh sort -u.
    # - CUT_SUBDOMAINS=1 tetap tersedia sebagai mode opsional, tetapi default 0.
    # shellcheck disable=SC2016
    "${AWK_CMD:?AWK_CMD belum diset}" -v tlds_file="$valid_tlds_file" -v cut_subdomains="${CUT_SUBDOMAINS:-0}" '
    function is_common_cc_sld(label) {
        return (label ~ /^(ac|ad|biz|co|com|edu|firm|gen|go|gov|info|mil|my|ne|net|nic|nom|or|org|rec|sch|store|web)$/)
    }
    function collapse_to_parent_domain(d, a, n, tld, sld) {
        n = split(d, a, ".")
        if (n <= 2) return d
        tld = a[n]
        sld = a[n - 1]
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
        sub(/^www\./, "", domain_l)
        sub(/^mail\./, "", domain_l)
        sub(/^1\./, "", domain_l)
        sub(/^0\./, "", domain_l)

        sub(/[\/\^ \t].*$/, "", domain_l)
        sub(/\.$/, "", domain_l)
        gsub(/[^a-z0-9\.\-]/, "", domain_l)

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
            if (lab == "") { bad = 1; break }
            if (length(lab) > 63) { bad = 1; break }
            if (substr(lab, 1, 1) == "-" || substr(lab, length(lab), 1) == "-") { bad = 1; break }
            if (length(lab) >= 4 && substr(lab, 3, 2) == "--" && lab !~ /^xn--/) { bad = 1; break }
        }
        if (bad) next

        print domain_l
    }
    ' "$chunk_file" > "$output_file"
}
export AWK_CMD AWK_FLAVOR
export -f process_chunk
# ============================================================
# FUNGSI UTAMA PROGRAM
# ============================================================
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

    # Setup output dir
    if [[ ! -d "$OUTPUT_DIR" ]]; then
        mkdir -p "$OUTPUT_DIR" || { log_error "Gagal membuat direktori '${OUTPUT_DIR}'"; exit 1; }
    fi

    if [[ ! -w "$OUTPUT_DIR" ]]; then
        log_error "Output dir tidak writable: $OUTPUT_DIR"
        exit 1
    fi

    # === FASE UNDUHAN (BYPASS SSL) ===
    print_colored "YELLOW" "
[DL] Fase Unduhan" "BG_BLUE"

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

    # === FASE PEMROSESAN ===
    print_colored "YELLOW" "
[PROC] Fase Pemrosesan" "BG_BLUE"
    log_progress "Membagi daftar domain..."
    split -l "${CHUNK_SIZE}" -- "${DOMAIN_FILE}" "${TEMP_DIR}/chunk_"

    processed_files_count=$(find "${TEMP_DIR}" -type f -name 'chunk_*' ! -name '*.processed' | wc -l)
    if (( processed_files_count < 1 )); then
        log_error "Tidak ada chunk yang dibuat dari daftar domain."
        exit 1
    fi

    log_progress "Memproses chunk paralel (${NUM_CORES} Cores)..."
    find "${TEMP_DIR}" -type f -name 'chunk_*' ! -name '*.processed' -print0 \
        | sort -z \
        | parallel -0 --will-cite --halt soon,fail=1 --line-buffer -j"${NUM_CORES}" process_chunk {} "${TEMP_DIR}/iana_tlds.txt"

    processed_files_count=$(find "${TEMP_DIR}" -type f -name 'chunk_*.processed' | wc -l)
    if (( processed_files_count < 1 )); then
        log_error "Tidak ada file .processed yang dihasilkan."
        exit 1
    fi

    log_success "Pemrosesan paralel selesai."

    log_progress "Menggabungkan dan membersihkan duplikat..."
    work_output_tmp="${TEMP_DIR}/valid_output.tmp"
    find "${TEMP_DIR}" -type f -name 'chunk_*.processed' -exec cat {} + \
        | sort -u -S "$SORT_BUFFER" -T "${TEMP_DIR}" > "$work_output_tmp"

    validate_nonempty_file "$work_output_tmp" "Hasil validasi otomatis" || exit 1
    processed_count=$(wc -l < "$work_output_tmp")

    # === FASE PEMBERSIHAN KHUSUS ===
    print_colored "YELLOW" "
[CLEAN] Fase Pembersihan Manual" "BG_BLUE"
        # Kompatibel v2.8: pola diberi awalan titik, sehingga yang dibuang adalah subdomain
    # dari daftar manual, bukan root domain exact-nya. Ini yang membuat jumlah "Dibuang Manual"
    # besar seperti hasil asli.
    printf '%s\n' "${DOMAINS_TO_CLEAN[@]}" | sed 's/\./\\./g; s/^/\\./' > "${TEMP_DIR}/domains_pattern.txt"

    VALID_OUTPUT_TMP="${VALID_OUTPUT}.tmp.$$"
    grep -v -f "${TEMP_DIR}/domains_pattern.txt" "$work_output_tmp" > "$VALID_OUTPUT_TMP" || true
    mv -f -- "$VALID_OUTPUT_TMP" "$VALID_OUTPUT"
    VALID_OUTPUT_TMP=""
    final_count=$(wc -l < "${VALID_OUTPUT}")
    final_file_size=$(du -h "${VALID_OUTPUT}" | cut -f1)

    removed_count=$((processed_count - final_count))

    # === STATISTIK ===
    print_colored "YELLOW" "
[STAT] Statistik" "BG_GREEN"

    if (( domain_count_initial > 0 )); then
        valid_percentage=$((processed_count * 100 / domain_count_initial))
        final_percentage=$((final_count * 100 / domain_count_initial))
    else
        valid_percentage=0
        final_percentage=0
    fi

    print_colored "BOLD" "[REPORT] Statistik Akhir:"
    print_colored "DIM" " * Input Awal        : ${COLORS[YELLOW]}$domain_count_initial${COLORS[NC]} (100%) - ${COLORS[CYAN]}$domain_file_size${COLORS[NC]}"
    print_colored "DIM" " * Valid (Automated) : ${COLORS[YELLOW]}$processed_count${COLORS[NC]} (${COLORS[CYAN]}$valid_percentage%${COLORS[NC]})"
    print_colored "DIM" " * Dibuang Manual    : ${COLORS[YELLOW]}$removed_count${COLORS[NC]}"
    print_colored "DIM" " * HASIL AKHIR       : ${COLORS[GREEN]}$final_count${COLORS[NC]} (${COLORS[CYAN]}$final_percentage%${COLORS[NC]}) - ${COLORS[CYAN]}$final_file_size${COLORS[NC]}"
    print_colored "DIM" " * File Output       : ${COLORS[CYAN]}$VALID_OUTPUT${COLORS[NC]}"

    show_system_resources "Selesai"

    end_time=$(date +%s)
    duration=$((end_time - start_time))
    local duration_min=$((duration / 60))
    local duration_sec=$((duration % 60))

    print_colored "GREEN" "
[DONE] Selesai dalam ${duration_min}m ${duration_sec}s [DONE]" "BG_GREEN"

    # Pastikan pembersihan dilakukan sebelum keluar.
    cleanup 0
    return 0
}
# ============================================================
# BANTUAN & DOKUMENTASI
# ============================================================
show_full_help() {
    show_banner
    # Menggunakan warna Putih Tebal (Bold) untuk teks agar jelas di pager
    printf '%s\n' "${COLORS[BOLD]}${COLORS[WHITE]}"
    cat << 'EOF'
============================================================
DOKUMENTASI LENGKAP DAN PANDUAN PENGGUNAAN
============================================================
RINGKASAN PERBAIKAN DAN OPTIMASI SCRIPT
----------------------------------------
Script ini telah mengalami perbaikan dan optimasi menyeluruh untuk
meningkatkan performa, keamanan, dan kemudahan pemeliharaan.

FUNGSI SCRIPT:
+-- Mengunduh daftar TLD resmi dari IANA dan semua sumber pada TRUSTPOSITIF_URLS
+-- Menyaring domain terhadap standar RFC, struktur label, dan TLD valid
+-- Membuang IPv4, IPv6, komentar, URL scheme, path, port, wildcard, dan karakter sampah
+-- Menjaga output default kompatibel dengan v2.9/v2.8: sanitasi prefix umum saja
+-- Mempertahankan manual cleanup legacy agar statistik hasil tetap sejalur dengan produksi lama
+-- Memproses jutaan baris dengan AWK auto-fallback + GNU Parallel secara stabil
+-- Melakukan deduplikasi global dengan sort -u dan menghasilkan output DNS/RPZ-ready

OPTIMASI PERFORMA:
+-- Ukuran Chunk Legacy-Compatible: formula default tetap 20000 + (NUM_CORES * 1000)
+-- Pemrosesan AWK Konsisten: satu AWK_CMD untuk mawk/gawk/awk, tidak hardcoded mawk
+-- Dependency Fallback: jika AWK belum ada, script mencoba install sesuai package manager
+-- Manajemen Sumber Daya: proteksi RAM/cgroup aktif hanya untuk mesin/container kecil
+-- Pemrosesan Paralel: GNU parallel tetap dipakai dengan fail-fast saat chunk gagal
+-- Optimasi Unduhan: curl/wget dengan SSL bypass opsional, retry, timeout, dan validasi payload
+-- Penanganan Kesalahan: cleanup, interrupt, terminate, dan output atomik diperbaiki

CARA PENGGUNAAN SCRIPT
-----------------------
PENGGUNAAN DASAR:
bash sunat-trustpositif.sh                  # Jalankan script normal multi-source

OPSI BARIS PERINTAH:
bash sunat-trustpositif.sh --help           # Tampilkan bantuan lengkap ini
bash sunat-trustpositif.sh --version        # Tampilkan versi script
bash sunat-trustpositif.sh --force-cleanup  # Paksa bersihkan file sementara
CUT_SUBDOMAINS=1 bash sunat-trustpositif.sh  # Mode agresif opsional; output bisa berbeda dari default

CATATAN PERUBAHAN DAN RIWAYAT VERSI
-----------------------------------
VERSI 3.0 (03 JUNI 2026) - Multi-Source Domain Input, Environment Stabilization & Lint Fix:
+-- [BARU] Menambahkan TRUSTPOSITIF_URLS sebagai daftar sumber domain multi-source
+            yang lebih ringkas dan terkontrol: Komdigi, StevenBlack, Hagezi, serta
+            blacklist pilihan Alsyundawy.
+-- [COMPAT] KOMINFO_URL tetap dipertahankan sebagai konstanta kompatibilitas,
+            dan dipakai sebagai elemen pertama TRUSTPOSITIF_URLS agar tidak terkena SC2034.
+-- [ENV] Menambahkan PATH eksplisit, locale C, strict mode, serta clear yang aman
+         untuk terminal maupun cron/non-interaktif.
+-- [DATA] DOMAIN_FILE diubah menjadi domain_blacklist sesuai pipeline multi-source v3.0.
+-- [HARDENING] Setiap URL sumber divalidasi ringan, diunduh ke file terpisah,
+              dicek non-empty, dicek bukan HTML/error page, lalu baru digabung.
+-- [HARDENING] Download memakai retry, connect-timeout, max-time, serta fallback
+              curl/wget. CURL_INSECURE=1 tetap default legacy; set 0 untuk TLS strict.
+-- [LINT] Memperbaiki ShellCheck SC2015 pada cleanup process dengan blok if eksplisit.
+-- [COMPAT] Core validasi AWK, IANA TLD filter, sort -u, manual cleanup legacy,
+            CUT_SUBDOMAINS default 0, dan output atomic tetap dijaga.
+-- [DOC] Header, banner, --help, tutorial singkat, docnote, dan changelog disesuaikan
+        ke versi 3.0 dan tanggal 03 JUNI 2026.

VERSI 2.9 (24 MEI 2026) - Output-Compatible Optimization, AWK Fallback & Runtime Hardening:
+-- [PRINSIP] v2.9 adalah optimasi internal dari v2.8; hasil default tetap dijaga
+            kompatibel dengan pola produksi v2.8 agar jumlah baris, ukuran output,
+            dan pola manual cleanup tidak berubah drastis.
+-- [COMPAT] Default CUT_SUBDOMAINS=0; script tidak melakukan parent-domain collapse
+            secara agresif. Mode agresif hanya aktif jika user menjalankan
+            CUT_SUBDOMAINS=1 secara eksplisit.
+-- [COMPAT] Sanitasi prefix legacy tetap dipertahankan sesuai perilaku v2.8,
+            terutama pemotongan prefix umum seperti www., mail., 1., dan 0.
+-- [COMPAT] Manual cleanup legacy tetap memakai pola sed + grep -v -f seperti v2.8
+            supaya domain/subdomain turunan dari daftar manual tetap tersaring
+            mengikuti hasil produksi sebelumnya.
+-- [COMPAT] Formula performa default tetap mengikuti gaya v2.8: NUM_CORES dari nproc
+            dengan batas aman 4-32 core dan CHUNK_SIZE=20000+(NUM_CORES*1000).
+-- [OPTIMASI] AWK engine dibuat konsisten melalui AWK_CMD dengan prioritas deteksi
+              mawk -> gawk -> awk, serta dapat dioverride manual oleh user.
+-- [OPTIMASI] Jika AWK belum tersedia, script mencoba instalasi otomatis sesuai
+              package manager sistem: apt/apt-get, dnf, yum, zypper, atau apk.
+-- [OPTIMASI] Semua proses normalisasi TLD, validasi domain, dan helper AWK memakai
+              satu AWK engine yang sama sehingga tidak lagi bercampur antara mawk,
+              gawk, dan awk di lingkungan Debian/Ubuntu/RHEL.
+-- [HARDENING] Proses unduhan diperkuat dengan curl -f/wget fallback, retry,
+              timeout, validasi file kosong, dan deteksi HTML/error page.
+-- [HARDENING] Output final dibuat atomik melalui temporary output lalu mv ke target
+              akhir agar file produksi tidak rusak/setengah jadi saat gagal.
+-- [HARDENING] Trap EXIT/INT/TERM diperbaiki agar cleanup tetap berjalan dan exit code
+              benar dipertahankan, termasuk 130 untuk Ctrl+C dan 143 untuk TERM.
+-- [HARDENING] --force-cleanup dibuat lebih aman dan tidak lagi bergantung pada
+              pkill brutal yang berisiko membunuh proses lain.
+-- [FIX] Tampilan status RAM diperbaiki agar Total RAM dan Tersedia tidak kosong
+        pada Debian/Ubuntu tertentu.
+-- [FIX] Duplikasi assignment dan inkonsistensi kecil pada blok AWK dibersihkan tanpa
+        mengubah hasil validasi domain default.
+-- [DOC] Header, banner, --help, docnote, dan changelog diperbarui agar jelas bahwa
+        v2.9 mengoptimalkan mesin proses, bukan mengganti format hasil produksi.

VERSI 2.8 (26 DESEMBER 2025) - Optimasi Komprehensif & Perbaikan ShellCheck:
+-- [FIX] Semua peringatan ShellCheck diselesaikan (SC2155, SC2046, SC2086, SC2034)
+-- [OPTIMASI] Konfigurasi performa dinamis dengan NUM_CORES adaptif (4-32 core)
+-- [OPTIMASI] Penyesuaian CHUNK_SIZE otomatis sesuai kapasitas sistem
+-- [FIX] Mekanisme pembersihan file sementara yang lebih komprehensif dan aman
+-- [ENHANCE] Banner ASCII Art dengan alignment presisi dan informasi versi lengkap
+-- [FIX] Penanganan error diperketat pada setiap fase kritis proses
+-- [OPTIMASI] Penggunaan memori konstan melalui mekanisme smart chunking
+-- [SECURITY] Validasi input dan sanitasi data diperketat untuk mencegah data invalid
+-- [FIX] Perbaikan sintaks MAWK kritis untuk validasi domain RFC-compliant
+-- [DOC] Dokumentasi lengkap dalam Bahasa Indonesia dengan contoh penggunaan praktis

VERSI 2.7 (23 NOVEMBER 2025) - Optimization & Fixes:
+-- [BARU] Opsi baris perintah (--help, --force-cleanup, --version)
+-- [FIX] Perbaikan sintaks fatal pada MAWK
+-- [FIX] Mekanisme unduhan dengan Bypass SSL (--insecure) untuk keandalan tinggi
+-- [FIX] Filter IPv6 yang ditingkatkan untuk mencegah kebocoran alamat IP
+-- [MOD] Integrasi dokumentasi lengkap ke dalam perintah --help
+-- [MOD] Optimasi struktur kode untuk stabilitas eksekusi
+-- [DITINGKATKAN] Penyaringan 95.000 domain

VERSI 2.5 (31 AGUSTUS 2025) - Penulisan Ulang Lengkap:
+-- [DITINGKATKAN] Penyaringan hingga 45.000 domain
+-- [DITINGKATKAN] sunat subdomain *www dan mail

VERSI 2.2 (22 AGUSTUS 2025) - Penulisan Ulang Lengkap:
+-- [BARU] Penanganan error yang ditingkatkan dan mekanisme pemulihan
+-- [BARU] Pemantauan performa dan statistik detail
+-- [BARU] Pemantauan sumber daya sistem komprehensif
+-- [BARU] Validasi TLD berdasarkan IANA & RFC
+-- [DITINGKATKAN] Penyaringan 35 ribu domain
+-- [DITINGKATKAN] Efisiensi pemrosesan paralel dengan GNU parallel
+-- [DITINGKATKAN] Optimasi penggunaan memori dengan chunking cerdas
+-- [DITINGKATKAN] Penanganan sinyal dan shutdown yang anggun
+-- [DITINGKATKAN] Validasi domain canggih dengan optimasi AWK
+-- [DOCS] Dokumentasi ekstensif dan panduan pemecahan masalah

VERSI 1.8 (05 JUNI 2025) - Rilis Awal:
+-- Perapihan kode agar mudah di maintenatencae
+-- Penyaringan 2 ribu domain
+-- Tampilan konsole yang berwarna dan informatif
+-- pembaharuan kode yang error

VERSI 1.0 (07 APRIL 2024) - Rilis Awal:
+-- Fungsionalitas validasi domain dasar
+-- Pengecekan TLD terhadap daftar resmi IANA
+-- Implementasi pemrosesan paralel sederhana
+-- Pembersihan dasar dan manajemen file sementara
+-- Penyaringan dan deduplikasi domain inti
+-- Output konsol sederhana dengan indikasi progres dasar

KONTRIBUSI DAN HAK CIPTA
------------------------
Hak Cipta (c) 2024-2026 HARRY DERTIN SUTISNA ALSYUNDAWY.
Script ini disediakan "SEBAGAIMANA ADANYA". Penggunaan risiko ditanggung pengguna.
EOF
    printf '%s\n' "${COLORS[NC]}"
}
# ============================================================
# ARGS HANDLING
# ============================================================
case "${1:-}" in
    --help|-h)
        CLEANUP_QUIET=1
        if command -v less &> /dev/null; then
            show_full_help | less -R
        elif command -v more &> /dev/null; then
            show_full_help | more
        else
            show_full_help
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
        log_error "Opsi salah"; echo "Gunakan --help"; exit 1
        ;;
esac

# ============================================================
# DOKUMENTASI LENGKAP DAN PANDUAN PENGGUNAAN
# ============================================================

# ============================================================
# RINGKASAN PERBAIKAN DAN OPTIMASI SCRIPT
# ============================================================
#
# Script ini telah mengalami perbaikan dan optimasi menyeluruh untuk 
# meningkatkan performa, keamanan, dan kemudahan pemeliharaan:
#
# DOCNOTE v3.0:
# +-- Input domain sekarang multi-source melalui TRUSTPOSITIF_URLS yang lebih ringkas:
#     Komdigi, StevenBlack, Hagezi, dan blacklist pilihan Alsyundawy.
# +-- Output default tetap dijaga kompatibel dengan v2.9/v2.8 selama CUT_SUBDOMAINS
#     tidak diaktifkan.
# +-- Beda utama v3.0 ada pada environment PATH/locale, DOMAIN_FILE=domain_blacklist,
#     download/penggabungan sumber, validasi payload, timeout/retry, dokumentasi,
#     serta perbaikan ShellCheck SC2015; core sunat domain default tetap dijaga.
#
# OPTIMASI PERFORMA:
# +-- Deteksi Sumber Daya: kompatibel v2.8 pada server normal, proteksi RAM/cgroup untuk mesin kecil
# +-- Ukuran Chunk Legacy-Compatible: default 20000 + (NUM_CORES * 1000)
# +-- Penggunaan CPU Legacy-Compatible: NUM_CORES mengikuti nproc dengan batas 4-32
# +-- AWK Auto-Fallback: mawk -> gawk -> awk lewat AWK_CMD tunggal
# +-- Dependency Fallback: install otomatis AWK dan tool wajib bila hilang sesuai package manager
# +-- I/O Terkontrol: temporary file terisolasi dan output final ditulis atomik
# +-- Parallel Processing Aman: GNU parallel dengan fail-fast jika ada chunk gagal
# +-- Bypass SSL Opsional: CURL_INSECURE=1 default legacy; set 0 untuk TLS strict
#
# PENINGKATAN KEAMANAN & KEANDALAN:
# +-- Validasi Input Ketat: Sanitasi semua input sebelum diproses
# +-- Penanganan Error Komprehensif: Error handling di setiap fase kritis
# +-- Pembersihan Otomatis: Trap handler untuk EXIT, INT, TERM
# +-- Penanganan File Aman: Path validation dengan parameter expansion
# +-- Resource Limiting: Batas CPU/memory implisit melalui chunking
# +-- Keamanan Proses: Terminasi semua child process pada exit
# +-- Isolasi Temp Dir: Penggunaan mktemp untuk direktori sementara aman
# +-- Atomic Operations: Operasi file dengan atomic write patterns
#
# MANAJEMEN SUMBER DAYA:
# +-- Resource Tracking: Pemantauan RAM/CPU sebelum, selama, dan sesudah proses
# +-- Pembersihan Agresif: Penghapusan semua file sementara tanpa jejak
# +-- Process Management: Kill semua background jobs pada exit/abort
# +-- Memory Safety: Batasan chunk size untuk mencegah OOM
# +-- CPU Throttling: Penyesuaian otomatis jumlah worker berdasarkan core
# +-- Zero Footprint: Tidak meninggalkan file sementara setelah eksekusi
# +-- Graceful Shutdown: Penanganan sinyal untuk shutdown terkontrol
# +-- Resource Recovery: Pemulihan sumber daya pada crash/error
#
# PENGALAMAN PENGGUNA:
# +-- Console Output Profesional: Banner ASCII art dengan alignment sempurna
# +-- Color-Coded Logging: Kategori log dengan warna berbeda untuk keterbacaan
# +-- Progress Tracking: Indikator progres real-time per fase
# +-- Comprehensive Statistics: Ringkasan lengkap dengan metrik kuantitatif
# +-- System Resource Display: Informasi RAM/CPU yang mudah dipahami
# +-- Error Messages Jelas: Pesan error dengan solusi spesifik
# +-- Help System Terstruktur: Dokumentasi lengkap melalui --help
# +-- Version Tracking: Riwayat versi terperinci dengan perubahan signifikan
#
# DOKUMENTASI & PEMELIHARAAN:
# +-- Indonesian Documentation: Dokumentasi lengkap dalam Bahasa Indonesia
# +-- Inline Comments Komprehensif: Komentar penjelasan untuk setiap blok logika
# +-- Function Documentation: Penjelasan tujuan dan parameter setiap fungsi
# +-- ShellCheck-Oriented: pola warning yang diketahui diperbaiki tanpa mematikan lint
# +-- Code Structure Modular: Organisasi kode berdasarkan tanggung jawab
# +-- Version Control Ready: Struktur siap untuk SCM (Git/SVN)
# +-- Maintainability Focus: Pola coding yang mudah dimodifikasi
# +-- Cross-Platform Support: Kompatibel dengan semua distribusi Linux modern
#
# ============================================================
# CARA PENGGUNAAN SCRIPT
# ============================================================
#
# PENGGUNAAN DASAR:
# bash sunat-trustpositif.sh                  # Jalankan script normal multi-source
#
# OPSI BARIS PERINTAH YANG TERSEDIA:
# bash sunat-trustpositif.sh --help           # Tampilkan dokumentasi lengkap
# bash sunat-trustpositif.sh --version        # Tampilkan versi script
# bash sunat-trustpositif.sh --force-cleanup  # Paksa pembersihan file sementara
#
# PEMECAHAN MASALAH UMUM:
#
# 1. JIKA SCRIPT TERJEBAK/HANG:
#    bash sunat-trustpositif.sh --force-cleanup
#    # Kemudian jalankan kembali normal
#
# 2. JIKA MUNCUL ERROR TENTANG DEPENDENSI:
#    # Install paket yang diperlukan:
#    sudo apt-get install -y curl mawk gawk parallel coreutils
#
# 3. JIKA UNDUHAN GAGAL:
#    # Script otomatis retry 3 kali dengan delay
#    # Periksa koneksi internet dan firewall
#    # Pastikan DNS resolver berfungsi dengan baik
#
# 4. JIKA MEMORI TIDAK CUKUP:
#    # Script otomatis menyesuaikan ukuran chunk
#    # Tutup aplikasi lain yang menggunakan memori besar
#    # Tambahkan swap space jika diperlukan
#
# 5. JIKA OUTPUT TIDAK SESUAI HARAPAN:
#    # Periksa validasi TLD terhadap IANA database
#    # Pastikan file input tidak korup
#    # Lakukan diff dengan file output sebelumnya
#
# ============================================================
# INFORMASI KEBUTUHAN SISTEM
# ============================================================
#
# KEBUTUHAN SISTEM MINIMUM:
# +-- OS: Linux (Ubuntu 20.04+/Debian 11+/CentOS 8+)
# +-- RAM: 1GB minimum (Direkomendasikan: 2GB+ untuk dataset besar)
# +-- Penyimpanan: 500MB ruang kosong untuk file sementara
# +-- CPU: 2 core minimum (Optimal: 8+ core untuk pemrosesan paralel)
# +-- Jaringan: Koneksi internet stabil (minimum 10 Mbps)
# +-- Izin: Akses tulis ke direktori output dan temp
#
# PAKET WAJIB (terdeteksi otomatis):
# +-- bash 5.0+ - Lingkungan eksekusi
# +-- curl 7.68+ - Unduh data dengan SSL bypass
# +-- mawk/gawk/awk - Pemrosesan teks performa tinggi dengan auto-fallback
# +-- parallel 20210822+ - Framework parallel processing
# +-- coreutils 8.32+ - Sort, uniq, wc, cut, dll
# +-- procps-ng 3.3.16+ - Pemantauan sumber daya
#
# INSTALASI DEPENDENSI (Ubuntu/Debian):
# sudo apt update && sudo apt install -y curl mawk gawk parallel coreutils procps
#
# INSTALASI DEPENDENSI (RHEL/CentOS/Fedora):
# sudo dnf install -y curl gawk parallel coreutils procps-ng
#
# VERIFIKASI INSTALASI:
# bash sunat-trustpositif.sh --version
# # Output: sunat-trustpositif.sh versi 3.0
#
# ============================================================
# KONFIGURASI DINAMIS DAN TUNING
# ============================================================
#
# MEKANISME KONFIGURASI OTOMATIS:
# Script secara dinamis menyesuaikan parameter berikut:
# +-- NUM_CORES default kompatibel v2.9/v2.8: nproc dengan batas 4-32
# +-- CHUNK_SIZE default kompatibel v2.9/v2.8: 20000 + (NUM_CORES * 1000)
# +-- Proteksi RAM/cgroup hanya menurunkan NUM_CORES pada mesin/container kecil
# +-- SORT_BUFFER adaptif 128M/256M/512M/50%, bisa dioverride manual
# +-- AWK_CMD auto-detect: mawk -> gawk -> awk, bisa dioverride manual
#
# PARAMETER YANG DAPAT DIKONFIGURASI MANUAL:
# IANA_TLD_URL="https://data.iana.org/TLD/tlds-alpha-by-domain.txt"
# KOMINFO_URL="https://trustpositif.komdigi.go.id/assets/db/domains_isp"
# DOMAIN_FILE="domain_blacklist"
# readonly OUTPUT_DIR="/var/www/html/trustpositif"
# readonly VALID_OUTPUT="${OUTPUT_DIR}/sunat-trustpositif.txt"
#
# BENCHMARK PERFORMA (sistem referensi: 8 core, 16GB RAM, SSD):
# +-- Download Phase: 15-25 detik (tergantung bandwidth)
# +-- Processing Phase: 45-90 detik untuk 1.5 juta domain
# +-- Cleanup Phase: < 3 detik
# +-- Total Runtime: 1.5-2.5 menit
# +-- Memory Usage: 300-600MB (stable)
# +-- CPU Utilization: stabil pada core yang dialokasikan tanpa memicu OOM
# +-- Throughput: 25.000-35.000 domain/detik
#
# TIPS OPTIMASI TAMBAHAN:
# +-- Jalankan pada jam beban server rendah
# +-- Gunakan filesystem berbasis SSD untuk TEMP_DIR
# +-- Pastikan buffer cache kernel optimal dengan sysctl
# +-- Batasi aplikasi lain yang menggunakan CPU intensif
# +-- Gunakan jaringan dengan latency rendah untuk fase unduhan
#
# ============================================================
# OUTPUT DAN ARSITEKTUR FILE
# ============================================================
#
# OUTPUT UTAMA:
# /var/www/html/trustpositif/sunat-trustpositif.txt
# +-- Format: Satu domain valid per baris
# +-- Encoding: UTF-8 tanpa BOM
# +-- Sorting: Alphabetical case-insensitive
# +-- Filtering: Hanya domain RFC-compliant dengan TLD resmi IANA
# +-- Deduplication: Entry duplikat dihilangkan
# +-- Sanitization: Karakter ilegal, IP addresses, dan prefix legacy tidak relevan dihapus
# +-- Compatibility: Default tidak melakukan parent-domain collapse agar statistik output setara v2.8
#
# ARSITEKTUR PEMROSESAN:
# 1. Download TLD IANA dan semua sumber domain pada TRUSTPOSITIF_URLS
# 2. Split file domain menjadi chunks berdasarkan ukuran dinamis
# 3. Proses paralel setiap chunk dengan validasi RFC/TLD
# 4. Gabungkan hasil dan eliminasi duplikat
# 5. Lakukan pembersihan manual terhadap daftar domain yang ditentukan
# 6. Generate statistik dan laporan akhir
# 7. Bersihkan semua file sementara dan resource
#
# FILE SEMENTARA (otomatis dihapus):
# /tmp/sunat-trustpositif.XXXXXX/
# +-- iana_tlds.raw - TLD mentah dari IANA
# +-- iana_tlds.txt - TLD diproses (lowercase, komentar dihapus)
# +-- chunk_* - File split untuk pemrosesan paralel
# +-- *.processed - Hasil sementara per chunk
# +-- domains_pattern.txt - Pola regex untuk pembersihan manual
# +-- (semua file dihapus otomatis melalui trap handler)
#
# LOG OUTPUT STRUKTUR:
# [>] [PROSES] - Indikator aktivitas aktif
# [i] [INFO] - Informasi sistem dan konfigurasi
# [OK] [BERHASIL] - Operasi berhasil
# [!] [PERINGATAN] - Peringatan non-kritis
# [X] [ERROR] - Error kritis yang menghentikan eksekusi
# [SYS] - Pemantauan sumber daya sistem
# [REPORT] - Ringkasan statistik akhir
#
# ============================================================
# KEAMANAN DAN PENANGANAN ERROR
# ============================================================
#
# LAYER KEAMANAN:
# +-- Input Sanitization: Semua input divalidasi sebelum pemrosesan
# +-- Path Validation: Penggunaan parameter expansion untuk path safety
# +-- Error Handling: Set -euo pipefail untuk deteksi error ketat
# +-- Resource Limits: Batasan implisit melalui chunk sizing
# +-- File Permissions: Default permissions aman untuk file output
# +-- Process Isolation: Child processes terisolasi dengan baik
# +-- Signal Handling: Pembersihan pada SIGINT, SIGTERM, dan exit normal
# +-- Network Security: Timeout dan retry policy untuk operasi jaringan
#
# POLA PENANGANAN ERROR:
# +-- Early Validation: Pemeriksaan dependensi di awal eksekusi
# +-- Atomic Operations: Operasi file dengan temporary files + rename
# +-- Resource Cleanup: Trap handler untuk semua kondisi exit
# +-- Error Context: Pesan error dengan konteks lokasi dan penyebab
# +-- Graceful Degradation: Fallback ke metode alternatif saat gagal
# +-- Fail-Safe Defaults: Parameter default aman jika deteksi gagal
# +-- Comprehensive Logging: Semua error tercatat dengan timestamp
# +-- User Guidance: Solusi spesifik untuk setiap jenis error
#
# PRAKTIK KEAMANAN YANG DIREKOMENDASIKAN:
# +-- Jalankan sebagai user non-root dengan izin minimal
# +-- Gunakan dedicated direktori untuk output dengan izin 755
# +-- Batasi akses jaringan hanya ke endpoint yang diperlukan
# +-- Pantau penggunaan sumber daya secara real-time
# +-- Validasi checksum file output secara berkala
# +-- Backup file output sebelum eksekusi baru
# +-- Audit daftar pembersihan domain secara rutin
# +-- Simpan log eksekusi untuk analisis forensik jika diperlukan
#
# ============================================================
# PEMANTAUAN DAN PEMELIHARAAN
# ============================================================
#
# METRIK PEMANTAUAN REAL-TIME:
# +-- CPU Utilization: Diukur dengan nproc dan top integration
# +-- Memory Usage: Pemantauan RAM bebas dan terpakai
# +-- Disk I/O: Pengukuran throughput dan latency
# +-- Network Throughput: Kecepatan download dan retry rate
# +-- Processing Speed: Domain diproses per detik
# +-- Error Rate: Persentase domain gagal validasi
# +-- Resource Reclamation: Konfirmasi pembersihan sumber daya
#
# JADWAL PEMELIHARAAN:
# +-- Harian: Pemantauan otomatis hasil output
# +-- Mingguan: Eksekusi pembersihan paksa (--force-cleanup)
# +-- Bulanan: Update script dan dependensi sistem
# +-- Kuartalan: Review dan update daftar pembersihan manual
# +-- Tahunan: Audit komprehensif alur pemrosesan dan keamanan
#
# ALAT PEMANTAUAN TAMBAHAN:
# +-- System Monitoring:
#      htop                        # Pemantauan CPU/memori real-time
#      iotop -o                    # Pemantauan disk I/O aktif
#      nethogs eth0                # Pemantauan bandwidth per proses
# +-- File Monitoring:
#      inotifywait -m /var/www/html/trustpositif/
# +-- Log Analysis:
#      grep -E "\[(ERROR|WARNING)\]" eksekusi.log
#
# STRATEGI BACKUP OTOMATIS:
# #!/bin/bash
# OUTPUT_DIR="/var/www/html/trustpositif"
# BACKUP_DIR="/backup/trustpositif"
# mkdir -p "$BACKUP_DIR"
# cp "${OUTPUT_DIR}/sunat-trustpositif.txt" "${BACKUP_DIR}/$(date +%Y%m%d_%H%M%S).txt"
# find "$BACKUP_DIR" -name "*.txt" -mtime +30 -delete # Hapus backup >30 hari
#
# ============================================================
# CATATAN PERUBAHAN DAN RIWAYAT VERSI
# ============================================================
#
# VERSI 3.0 (03 JUNI 2026) - Multi-Source Domain Input, Environment Stabilization & Lint Fix:
# +-- [BARU] Menambahkan TRUSTPOSITIF_URLS sebagai daftar sumber domain multi-source
# +            yang lebih ringkas dan terkontrol: Komdigi, StevenBlack, Hagezi,
# +            serta blacklist pilihan Alsyundawy.
# +-- [COMPAT] KOMINFO_URL tetap dipertahankan sebagai konstanta kompatibilitas,
# +            dan dipakai sebagai elemen pertama TRUSTPOSITIF_URLS agar tidak terkena SC2034.
# +-- [ENV] Menambahkan PATH eksplisit, locale C, strict mode, serta clear yang aman
# +         untuk terminal maupun cron/non-interaktif.
# +-- [DATA] DOMAIN_FILE diubah menjadi domain_blacklist sesuai pipeline multi-source v3.0.
# +-- [HARDENING] Setiap URL sumber divalidasi ringan, diunduh ke file terpisah,
# +              dicek non-empty, dicek bukan HTML/error page, lalu baru digabung.
# +-- [HARDENING] Download memakai retry, connect-timeout, max-time, serta fallback
# +              curl/wget. CURL_INSECURE=1 tetap default legacy; set 0 untuk TLS strict.
# +-- [LINT] Memperbaiki ShellCheck SC2015 pada cleanup process dengan blok if eksplisit.
# +-- [COMPAT] Core validasi AWK, IANA TLD filter, sort -u, manual cleanup legacy,
# +            CUT_SUBDOMAINS default 0, dan output atomic tetap dijaga.
# +-- [DOC] Header, banner, --help, tutorial singkat, docnote, dan changelog disesuaikan
# +        ke versi 3.0 dan tanggal 03 JUNI 2026.
#
# VERSI 2.9 (24 MEI 2026) - Output-Compatible Optimization, AWK Fallback & Runtime Hardening:
# +-- [PRINSIP] v2.9 adalah optimasi internal dari v2.8; hasil default tetap dijaga
# +            kompatibel dengan pola produksi v2.8 agar jumlah baris, ukuran output,
# +            dan pola manual cleanup tidak berubah drastis.
# +-- [COMPAT] Default CUT_SUBDOMAINS=0; script tidak melakukan parent-domain collapse
# +            secara agresif. Mode agresif hanya aktif jika user menjalankan
# +            CUT_SUBDOMAINS=1 secara eksplisit.
# +-- [COMPAT] Sanitasi prefix legacy tetap dipertahankan sesuai perilaku v2.8,
# +            terutama pemotongan prefix umum seperti www., mail., 1., dan 0.
# +-- [COMPAT] Manual cleanup legacy tetap memakai pola sed + grep -v -f seperti v2.8
# +            supaya domain/subdomain turunan dari daftar manual tetap tersaring
# +            mengikuti hasil produksi sebelumnya.
# +-- [COMPAT] Formula performa default tetap mengikuti gaya v2.8: NUM_CORES dari nproc
# +            dengan batas aman 4-32 core dan CHUNK_SIZE=20000+(NUM_CORES*1000).
# +-- [OPTIMASI] AWK engine dibuat konsisten melalui AWK_CMD dengan prioritas deteksi
# +              mawk -> gawk -> awk, serta dapat dioverride manual oleh user.
# +-- [OPTIMASI] Jika AWK belum tersedia, script mencoba instalasi otomatis sesuai
# +              package manager sistem: apt/apt-get, dnf, yum, zypper, atau apk.
# +-- [OPTIMASI] Semua proses normalisasi TLD, validasi domain, dan helper AWK memakai
# +              satu AWK engine yang sama sehingga tidak lagi bercampur antara mawk,
# +              gawk, dan awk di lingkungan Debian/Ubuntu/RHEL.
# +-- [HARDENING] Proses unduhan diperkuat dengan curl -f/wget fallback, retry,
# +              timeout, validasi file kosong, dan deteksi HTML/error page.
# +-- [HARDENING] Output final dibuat atomik melalui temporary output lalu mv ke target
# +              akhir agar file produksi tidak rusak/setengah jadi saat gagal.
# +-- [HARDENING] Trap EXIT/INT/TERM diperbaiki agar cleanup tetap berjalan dan exit code
# +              benar dipertahankan, termasuk 130 untuk Ctrl+C dan 143 untuk TERM.
# +-- [HARDENING] --force-cleanup dibuat lebih aman dan tidak lagi bergantung pada
# +              pkill brutal yang berisiko membunuh proses lain.
# +-- [FIX] Tampilan status RAM diperbaiki agar Total RAM dan Tersedia tidak kosong
# +        pada Debian/Ubuntu tertentu.
# +-- [FIX] Duplikasi assignment dan inkonsistensi kecil pada blok AWK dibersihkan tanpa
# +        mengubah hasil validasi domain default.
# +-- [DOC] Header, banner, --help, docnote, dan changelog diperbarui agar jelas bahwa
# +        v2.9 mengoptimalkan mesin proses, bukan mengganti format hasil produksi.
#
# VERSI 2.8 (26 DESEMBER 2025) - Optimasi Komprehensif & Perbaikan ShellCheck:
# +-- [FIX] Semua peringatan ShellCheck diselesaikan (SC2155, SC2046, SC2086, SC2034)
# +-- [OPTIMASI] Konfigurasi performa dinamis dengan NUM_CORES adaptif (4-32 core)
# +-- [OPTIMASI] Penyesuaian CHUNK_SIZE otomatis sesuai kapasitas sistem
# +-- [FIX] Mekanisme pembersihan file sementara yang lebih komprehensif dan aman
# +-- [ENHANCE] Banner ASCII Art dengan alignment presisi dan informasi versi lengkap
# +-- [FIX] Penanganan error diperketat pada setiap fase kritis proses
# +-- [OPTIMASI] Penggunaan memori konstan melalui mekanisme smart chunking
# +-- [SECURITY] Validasi input dan sanitasi data diperketat untuk mencegah data invalid
# +-- [FIX] Perbaikan sintaks MAWK kritis untuk validasi domain RFC-compliant
# +-- [DOC] Dokumentasi lengkap dalam Bahasa Indonesia dengan contoh penggunaan praktis
#
# VERSI 2.7 (23 NOVEMBER 2025) - Optimization & Fixes:
# +-- [BARU] Opsi baris perintah (--help, --force-cleanup, --version)
# +-- [FIX] Perbaikan sintaks fatal pada MAWK
# +-- [FIX] Mekanisme unduhan dengan Bypass SSL (--insecure) untuk keandalan tinggi
# +-- [FIX] Filter IPv6 yang ditingkatkan untuk mencegah kebocoran alamat IP
# +-- [MOD] Integrasi dokumentasi lengkap ke dalam perintah --help
# +-- [MOD] Optimasi struktur kode untuk stabilitas eksekusi
# +-- [DITINGKATKAN] Penyaringan 95.000 domain
# VERSI 2.5 (31 AGUSTUS 2025) - Penulisan Ulang Lengkap:
# +-- [DITINGKATKAN] Penyaringan hingga 45.000 domain
# +-- [DITINGKATKAN] Pembersihan subdomain www dan mail
#
# VERSI 2.2 (22 AGUSTUS 2025) - Penulisan Ulang Lengkap:
# +-- [BARU] Penanganan error yang ditingkatkan dan mekanisme pemulihan
# +-- [BARU] Pemantauan performa dan statistik detail
# +-- [BARU] Pemantauan sumber daya sistem komprehensif
# +-- [BARU] Validasi TLD berdasarkan IANA & RFC
# +-- [DITINGKATKAN] Penyaringan 35 ribu domain
# +-- [DITINGKATKAN] Efisiensi pemrosesan paralel dengan GNU parallel
# +-- [DITINGKATKAN] Optimasi penggunaan memori dengan chunking cerdas
# +-- [DITINGKATKAN] Penanganan sinyal dan shutdown yang anggun
# +-- [DITINGKATKAN] Validasi domain canggih dengan optimasi AWK
# +-- [DOCS] Dokumentasi ekstensif dan panduan pemecahan masalah
#
# VERSI 1.8 (05 JUNI 2025) - Rilis Awal:
# +-- Perapihan kode agar mudah di-maintain
# +-- Penyaringan 2 ribu domain
# +-- Tampilan konsole yang berwarna dan informatif
# +-- Perbaikan kode error
#
# VERSI 1.0 (07 APRIL 2024) - Rilis Awal:
# +-- Fungsionalitas validasi domain dasar
# +-- Pengecekan TLD terhadap daftar resmi IANA
# +-- Implementasi pemrosesan paralel sederhana
# +-- Pembersihan dasar dan manajemen file sementara
# +-- Penyaringan dan deduplikasi domain inti
# +-- Output konsol sederhana dengan indikasi progres dasar
#
# ============================================================
# KONTRIBUSI DAN HAK CIPTA
# ============================================================
#
# INFORMASI PEMBUAT:
# +-- Nama: HARRY DERTIN SUTISNA ALSYUNDAWY
# +-- Spesialisasi: Full-Stack Development & Linux System Engineering
# +-- Keahlian: Shell Scripting Advanced, System Architecture, Performance Optimization
# +-- Pengalaman: >50 tahun pengalaman di industri teknologi (berdasarkan parameter user)
#
# PANDUAN KONTRIBUSI:
# +-- Ikuti standar koding yang ada (ShellCheck compliant)
# +-- Sertakan dokumentasi lengkap untuk setiap perubahan
# +-- Test pada minimal 3 distribusi Linux berbeda
# +-- Pertahankan kompatibilitas mundur jika memungkinkan
# +-- Sertakan benchmark performa untuk optimasi
# +-- Gunakan pull request dengan deskripsi jelas
# +-- Update riwayat versi untuk setiap perubahan signifikan
#
# HAK CIPTA DAN LISENSI:
# Hak Cipta (c) 2024-2026 HARRY DERTIN SUTISNA ALSYUNDAWY
# 
# Dengan ini diberikan izin, tanpa biaya, kepada siapa pun yang memperoleh
# salinan perangkat lunak ini dan file dokumentasi terkait untuk menggunakan,
# menyalin, memodifikasi, menggabungkan, menerbitkan, mendistribusikan,
# mensublisensikan, dan/atau menjual salinan perangkat lunak ini, dengan
# ketentuan sebagai berikut:
# 
# Pemberitahuan hak cipta di atas dan pemberitahuan izin ini harus disertakan
# dalam semua salinan atau bagian substansial dari Perangkat Lunak.
# 
# PERANGKAT LUNAK DISEDIAKAN "SEBAGAIMANA ADANYA", TANPA JAMINAN APA PUN,
# BAIK TERSURAT MAUPUN TERSIRAT, TERMASUK NAMUN TIDAK TERBATAS PADA JAMINAN
# DAPAT DIPERDAGANGKAN, KESESUAIAN UNTUK TUJUAN TERTENTU DAN NON-PELANGGARAN.
# 
# DALAM HAL APAPUN PENULIS ATAU PEMEGANG HAK CIPTA TIDAK BERTANGGUNG JAWAB
# ATAS KLAIM APA PUN, KERUSAKAN ATAU KEWAJIBAN LAINNYA, BAIK DALAM TINDAKAN
# KONTRAK, TORT ATAU LAINNYA, YANG TIMBUL DARI, DARI ATAU SEHUBUNGAN DENGAN
# PERANGKAT LUNAK ATAU PENGGUNAAN ATAU URUSAN LAIN DALAM PERANGKAT LUNAK.
#
# KONTAK RESMI:
# Untuk pertanyaan komersial atau dukungan profesional:
# Email			: ALSYUNDAWY@GMAIL.COM
# Telepon		: 08568515212
# Website		: ALSYUNDAWY.COM
#
# CATATAN AKHIR:
# Script ini dirancang untuk operasional enterprise dengan fokus pada:
# 1. Keandalan (tidak gagal pada kondisi edge case)
# 2. Performa (memanfaatkan sumber daya secara efisien tanpa memicu OOM)
# 3. Keamanan (tidak meninggalkan jejak atau kerentanan)
# 4. Maintainability (kode dan dokumentasi jelas)
# 5. Skalabilitas (menangani dataset dari ribuan hingga jutaan entri)
#
# ============================================================
# AKHIR DOKUMENTASI KOMPREHENSIF
# ============================================================
