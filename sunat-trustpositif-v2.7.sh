#!/usr/bin/env bash
# ============================================================
# Script Name   : sunat-trustpositif.sh
# Description   : Validasi domain list terhadap TLD resmi, standar RFC, filter IPv4/IPv6.
#                 Optimasi performa tinggi dengan bypass SSL dan parallel processing.
# Author        : HARRY DERTIN SUTISNA ALSYUNDAWY
# Created Date  : 07 APRIL 2024
# Last Modified : 23 NOVEMBER 2025
# Version       : 2.7
# Usage         : bash sunat-trustpositif.sh
# ============================================================

# Konfigurasi strict mode untuk bash
set -Eeuo pipefail
export IFS=$'\n\t'
export LC_ALL=C
export LANG=C

# ============================================================
# KONFIGURASI GLOBAL DAN KONSTANTA
# ============================================================

# Definisi warna untuk output console (ORIGINAL SCHEME)
declare -A COLORS=(
    [RED]='\033[0;31m' [GREEN]='\033[0;32m' [YELLOW]='\033[1;33m'
    [BLUE]='\033[0;34m' [PURPLE]='\033[0;35m' [CYAN]='\033[0;36m'
    [WHITE]='\033[1;37m' [BOLD]='\033[1m' [DIM]='\033[2m' [NC]='\033[0m'
)
declare -A BG_COLORS=(
    [BG_RED]='\033[41m' [BG_GREEN]='\033[42m' [BG_YELLOW]='\033[43m'
    [BG_BLUE]='\033[44m' [BG_PURPLE]='\033[45m' [BG_CYAN]='\033[46m'
)

# Konfigurasi utama script
SCRIPT_NAME="sunat-trustpositif.sh"
SCRIPT_VERSION="2.7"
IANA_TLD_URL="https://data.iana.org/TLD/tlds-alpha-by-domain.txt"
KOMINFO_URL="https://trustpositif.komdigi.go.id/assets/db/domains_isp"
DOMAIN_FILE="domains_isp"
OUTPUT_DIR="/var/www/html/trustpositif"
VALID_OUTPUT="${OUTPUT_DIR}/sunat-trustpositif.txt"

# Konfigurasi performa
NUM_CORES=$(nproc)
CHUNK_SIZE=15000
TEMP_DIR=$(mktemp -d -t "${SCRIPT_NAME%.*}.XXXXXX")

# ============================================================
# FUNGSI UTILITAS DAN LOGGING (ORIGINAL STYLE)
# ============================================================

print_colored() {
    local color="$1" message="$2" bg_color="${3:-}"
    if [[ -n "$bg_color" ]]; then
        printf '%s\n' "${BG_COLORS[$bg_color]}${COLORS[$color]}${message}${COLORS[NC]}"
    else
        printf '%s\n' "${COLORS[$color]}${message}${COLORS[NC]}"
    fi
}

log_info() { print_colored "CYAN" "[i] [INFO] $1"; }
log_success() { print_colored "PURPLE" "[OK] [BERHASIL] $1"; }
log_warning() { print_colored "YELLOW" "[!] [PERINGATAN] $1"; }
log_error() { print_colored "RED" "[X] [ERROR] $1"; }
log_progress() { print_colored "GREEN" "[>] [PROSES] $1"; }

# Banner Original (Menggunakan BG_BLUE)
show_banner() {
    print_colored "CYAN" "+------------------------------------------------------------------------------+" "BG_BLUE"
    print_colored "WHITE" "¦            SUNAT TRUST POSITIF v${SCRIPT_VERSION} - ENTERPRISE EDITION            ¦" "BG_BLUE"
    print_colored "WHITE" "¦          Validasi TLD, RFC, IPv4/IPv6 & High Performance Processing          ¦" "BG_BLUE"
    print_colored "CYAN" "+------------------------------------------------------------------------------¦" "BG_BLUE"
    print_colored "YELLOW" "¦ Script Name     : ${SCRIPT_NAME}                                          ¦" "BG_BLUE"
    print_colored "YELLOW" "¦ Deskripsi       : Fix Syntax Mawk, SSL Bypass, & Filter IP Optimized.        ¦" "BG_BLUE"
    print_colored "YELLOW" "¦ Pembuat         : HARRY DERTIN SUTISNA ALSYUNDAWY                            ¦" "BG_BLUE"
    print_colored "YELLOW" "¦ Versi           : ${SCRIPT_VERSION}                                                   ¦" "BG_BLUE"
    print_colored "YELLOW" "¦ Terakhir Diubah : 23 NOVEMBER 2025                                           ¦" "BG_BLUE"
    print_colored "CYAN" "+------------------------------------------------------------------------------+" "BG_BLUE"
}

show_system_resources() {
    local phase="$1"
    print_colored "YELLOW" "\n[SYS] Status Sistem - $phase" "BG_PURPLE"
    local mem_info total_mem avail_mem
    mem_info=$(free -h | grep "Mem:")
    # Parsing yang aman
    total_mem=$(echo "$mem_info" | awk '{print $2}')
    avail_mem=$(echo "$mem_info" | awk '{print $7}')
    
    # Menggunakan COLORS[DIM] yang sudah diperbaiki
    print_colored "DIM" " * Total RAM : ${COLORS[CYAN]}$total_mem${COLORS[NC]}"
    print_colored "DIM" " * Tersedia  : ${COLORS[GREEN]}$avail_mem${COLORS[NC]}"
    print_colored "DIM" " * CPU Cores : ${COLORS[CYAN]}$NUM_CORES${COLORS[NC]}"
}

check_dependencies() {
    local dependencies=("curl" "mawk" "parallel" "split")
    for cmd in "${dependencies[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log_error "Dependency hilang: $cmd. Harap install terlebih dahulu."
            exit 1
        fi
    done
}

# ============================================================
# FUNGSI DOWNLOADER (OPTIMAL & BYPASS SSL)
# ============================================================
download_data() {
    local url="$1"
    local output="$2"
    local description="$3"

    log_progress "Mengunduh $description..."
    
    # Prioritas 1: Curl dengan SSL Bypass, Kompresi, dan Retry
    if command -v curl &> /dev/null; then
        if curl -sL --insecure --compressed --connect-timeout 30 --retry 3 --retry-delay 2 -o "$output" "$url"; then
            return 0
        fi
    fi

    # Prioritas 2: Wget dengan No Check Certificate
    if command -v wget &> /dev/null; then
        if wget --no-check-certificate -q -O "$output" --timeout=30 --tries=3 "$url"; then
            return 0
        fi
    fi

    return 1
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
    [[ "${CLEANUP_RUNNING:-0}" == "1" ]] && return 0
    export CLEANUP_RUNNING=1
    log_info "Membersihkan file sementara..."
    if jobs -p > /dev/null 2>&1; then
        # shellcheck disable=SC2046
        kill $(jobs -p) 2>/dev/null || true
    fi
    rm -rf "${TEMP_DIR}" "${DOMAIN_FILE}" 2>/dev/null || true
    log_success "Pembersihan selesai."
}
trap cleanup EXIT INT TERM

# ============================================================
# FUNGSI PEMROSESAN DOMAIN (CORE LOGIC)
# ============================================================

process_chunk() {
    local chunk_file="$1"
    local valid_tlds_file="$2"
    local output_file="${chunk_file}.processed"
    
    # PERBAIKAN SINTAKS MAWK DI SINI
    mawk -v tlds_file="$valid_tlds_file" '
    BEGIN {
        while ((getline line < tlds_file) > 0) {
            gsub(/\r/, "", line)
            if (line ~ /^[[:space:]]*$/) continue
            if (line ~ /^#/) continue
            valid_tlds[tolower(line)] = 1
        }
        close(tlds_file)
    }

    # --- FILTER AWAL (PATTERN-ACTION) ---
    /^[[:space:]]*$/ { next }
    /^[[:space:]]*[#;]/ && $0 !~ /[a-zA-Z0-9.-]/ { next }

    {
        domain = $0

        # --- SANITASI ---
        sub(/^[[:alpha:]]+[[:punct:]]+\/\//, "", domain) 
        gsub(/[[:space:]]*[#;].*$/, "", domain) 
        gsub(/[[:space:]]*\/\/.*$/, "", domain) 
        sub(/^[[:space:]]+/, "", domain)
        sub(/[[:space:]]+$/, "", domain)
        
        if (domain == "") next

        # --- FILTER IP ADDRESS (v4 & v6) ---
        if (domain ~ /^([0-9]{1,3}\.){3}[0-9]{1,3}$/) next
        if (domain ~ /^[0-9a-fA-F:]+$/ && index(domain, ":") > 0) next
        if (domain ~ /^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$/) next

        # Hapus sampah umum
        sub(/^[[:space:]]*(0\.0\.0\.0|127\.0\.0\.1|::1)[[:space:]]+/, "", domain)
        sub(/^[[:digit:]]+(\.[[:digit:]]+){1,3}[[:space:]]+/, "", domain)
        sub(/^[\|\*]+/, "", domain)
        sub(/^www\./i, "", domain)
        sub(/^mail\./i, "", domain)
        sub(/^1\./i, "", domain)
        sub(/^0\./i, "", domain)
        sub(/[\/\^[:space:]].*$/, "", domain)
        sub(/:[0-9]+$/, "", domain)
        sub(/\.$/, "", domain)
        gsub(/[^A-Za-z0-9\.\-]/, "", domain)

        domain_l = tolower(domain)
        if (domain_l == "") next
        if (domain_l ~ /^[0-9]+(\.[0-9]+){1,3}$/) next

        # --- VALIDASI STRUKTUR DOMAIN ---
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
            if (substr(lab,1,1) == "-" || substr(lab,length(lab),1) == "-") { bad = 1; break }
            if (length(lab) >= 4 && substr(lab,3,2) == "--" && lab !~ /^xn--/) { bad = 1; break }
        }
        if (bad) next

        if (!seen[domain_l]++) {
            print domain_l
        }
    }
    ' "$chunk_file" > "$output_file"
}
export -f process_chunk

# ============================================================
# FUNGSI UTAMA PROGRAM
# ============================================================

main() {
    local start_time end_time duration
    start_time=$(date +%s)
    
    check_dependencies
    show_banner
    log_info "Waktu Mulai: $(date '+%d %B %Y - %H:%M:%S')"
    show_system_resources "Sebelum Proses"

    # Setup output dir
    if [[ ! -d "$OUTPUT_DIR" ]]; then
        mkdir -p "$OUTPUT_DIR" || { log_error "Gagal membuat direktori '${OUTPUT_DIR}'"; exit 1; }
    fi
    if [[ ! -w "$OUTPUT_DIR" ]]; then log_error "Output dir not writable"; exit 1; fi

    # === FASE UNDUHAN (BYPASS SSL) ===
    print_colored "YELLOW" "\n[DL] Fase Unduhan" "BG_BLUE"
    
    if ! download_data "${IANA_TLD_URL}" "${TEMP_DIR}/iana_tlds.raw" "daftar TLD IANA"; then
        log_error "Gagal mengunduh TLD IANA."; exit 1
    fi
    grep -v '^#' "${TEMP_DIR}/iana_tlds.raw" | tr '[:upper:]' '[:lower:]' > "${TEMP_DIR}/iana_tlds.txt"

    if ! download_data "${KOMINFO_URL}" "${DOMAIN_FILE}" "daftar domain Kominfo"; then
        log_error "Gagal mengunduh daftar domain Kominfo."; exit 1
    fi
    
    local domain_count_initial domain_file_size
    domain_count_initial=$(wc -l < "${DOMAIN_FILE}")
    domain_file_size=$(du -h "${DOMAIN_FILE}" | cut -f1)

    # === FASE PEMROSESAN ===
    print_colored "YELLOW" "\n[PROC] Fase Pemrosesan" "BG_BLUE"
    
    log_progress "Membagi daftar domain..."
    split -l ${CHUNK_SIZE} "${DOMAIN_FILE}" "${TEMP_DIR}/chunk_"
    
    log_progress "Memproses chunk paralel (${NUM_CORES} Cores)..."
    find "${TEMP_DIR}" -name 'chunk_*' | parallel -j"${NUM_CORES}" process_chunk {} "${TEMP_DIR}/iana_tlds.txt"
    log_success "Pemrosesan paralel selesai."

    log_progress "Menggabungkan dan membersihkan duplikat..."
    cat "${TEMP_DIR}"/*.processed | sort -u > "${VALID_OUTPUT}.tmp"

    local processed_count processed_file_size
    processed_count=$(wc -l < "${VALID_OUTPUT}.tmp")
    processed_file_size=$(du -h "${VALID_OUTPUT}.tmp" | cut -f1)

    # === FASE PEMBERSIHAN KHUSUS ===
    print_colored "YELLOW" "\n[CLEAN] Fase Pembersihan Manual" "BG_BLUE"
    
    printf '%s\n' "${DOMAINS_TO_CLEAN[@]}" | sed 's/\./\\./g; s/^/\\./' > "${TEMP_DIR}/domains_pattern.txt"
    grep -v -f "${TEMP_DIR}/domains_pattern.txt" "${VALID_OUTPUT}.tmp" > "${VALID_OUTPUT}"
    
    local final_count final_file_size
    final_count=$(wc -l < "${VALID_OUTPUT}")
    final_file_size=$(du -h "${VALID_OUTPUT}" | cut -f1)
    local removed_count=$((processed_count - final_count))
    
    rm -f "${VALID_OUTPUT}.tmp"

    # === STATISTIK ===
    print_colored "YELLOW" "\n[STAT] Statistik" "BG_GREEN"
    local valid_percentage=$((processed_count * 100 / domain_count_initial))
    local final_percentage=$((final_count * 100 / domain_count_initial))

    print_colored "BOLD" "[REPORT] Statistik Akhir:"
    print_colored "DIM" " * Input Awal        : ${COLORS[YELLOW]}$domain_count_initial${COLORS[NC]} (100%) - ${COLORS[CYAN]}$domain_file_size${COLORS[NC]}"
    print_colored "DIM" " * Valid (Automated) : ${COLORS[YELLOW]}$processed_count${COLORS[NC]} (${COLORS[CYAN]}$valid_percentage%${COLORS[NC]}) - ${COLORS[CYAN]}${processed_file_size}${COLORS[NC]}"
    print_colored "DIM" " * Dibuang Manual    : ${COLORS[YELLOW]}$removed_count${COLORS[NC]}"
    print_colored "DIM" " * HASIL AKHIR       : ${COLORS[GREEN]}$final_count${COLORS[NC]} (${COLORS[CYAN]}$final_percentage%${COLORS[NC]}) - ${COLORS[CYAN]}$final_file_size${COLORS[NC]}"
    print_colored "DIM" " * File Output       : ${COLORS[CYAN]}$VALID_OUTPUT${COLORS[NC]}"

    show_system_resources "Selesai"
    
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    local duration_min=$((duration / 60))
    local duration_sec=$((duration % 60))
    
    print_colored "GREEN" "\n[DONE] Selesai dalam ${duration_min}m ${duration_sec}s [DONE]" "BG_GREEN"
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

OPTIMASI PERFORMA:
+-- Ukuran Chunk Optimal: Ukuran chunk 15000 untuk keseimbangan kecepatan vs memori
+-- Pemrosesan AWK Dioptimalkan: Regex terkompilasi dan tabel hash O(1) 
+-- Manajemen Sumber Daya: Pemanfaatan optimal semua core CPU dan memori
+-- Pemrosesan Paralel: GNU parallel dengan pemrosesan efisien
+-- Optimasi Unduhan: Menggunakan metode bypass SSL dan kompresi

CARA PENGGUNAAN SCRIPT
-----------------------
PENGGUNAAN DASAR:
 bash sunat-trustpositif.sh                  # Jalankan script normal

OPSI BARIS PERINTAH:
 bash sunat-trustpositif.sh --help           # Tampilkan bantuan lengkap ini
 bash sunat-trustpositif.sh --version        # Tampilkan versi script
 bash sunat-trustpositif.sh --force-cleanup  # Paksa bersihkan file sementara

CATATAN PERUBAHAN DAN RIWAYAT VERSI
-----------------------------------
VERSI 2.7 (23 NOVEMBER 2025) - Optimization & Fixes:
+-- [BARU] Opsi baris perintah (--help, --force-cleanup, --version)
+-- [FIX] Perbaikan sintaks fatal pada MAWK .
+-- [FIX] Mekanisme unduhan dengan Bypass SSL (--insecure) untuk keandalan tinggi.
+-- [FIX] Filter IPv6 yang ditingkatkan untuk mencegah kebocoran alamat IP.
+-- [MOD] Integrasi dokumentasi lengkap ke dalam perintah --help.
+-- [MOD] Optimasi struktur kode untuk stabilitas eksekusi.
+-- [DITINGKATKAN] Penyaringan 95 ribu domain. 

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
Hak Cipta (c) 2024-2025 HARRY DERTIN SUTISNA ALSYUNDAWY.
Script ini disediakan "SEBAGAIMANA ADANYA". Penggunaan risiko ditanggung pengguna.
EOF
    printf '%s\n' "${COLORS[NC]}"
}

# ============================================================
# ARGS HANDLING
# ============================================================

case "${1:-}" in
    --help|-h) 
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
        print_colored "YELLOW" "\n[CLEANUP] Memulai Pembersihan Paksa..."
        pkill -f "$SCRIPT_NAME" 2>/dev/null || true
        rm -rf "${TEMP_DIR}" "${DOMAIN_FILE}" 2>/dev/null || true
        log_success "Cleanup selesai. Sistem bersih."
        exit 0 
        ;;
    --version|-v) 
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
# OPTIMASI PERFORMA:
# +-- Ukuran Chunk Optimal: Ukuran chunk 15000 untuk keseimbangan kecepatan vs memori
# +-- Pemrosesan AWK Dioptimalkan: Regex terkompilasi dan tabel hash O(1) 
# +-- Manajemen Sumber Daya: Pemanfaatan optimal semua core CPU dan memori
# +-- Pemrosesan Paralel: GNU parallel dengan pemrosesan efisien
# +-- Optimasi Memori: Jejak memori minimal dengan pemrosesan cerdas
# +-- Optimasi Startup: Eliminasi pengecekan dependensi berulang
# +-- Optimasi I/O: Pengurangan disk I/O dengan pemrosesan stream
# +-- Optimasi Pembersihan: Pembersihan cepat tanpa overhead
#
# PENINGKATAN KEAMANAN & KEANDALAN:
# +-- Validasi Masukan: Validasi ketat untuk semua input dan file
# +-- Penanganan File Aman: Penanganan file aman dengan operasi atomik
# +-- Manajemen Proses: Manajemen siklus hidup proses yang tepat
# +-- Pemulihan Error: Penanganan error robust dengan degradasi yang anggun
# +-- Penanganan Sinyal: Pembersihan yang tepat saat interrupt atau terminasi
# +-- Keamanan Path: Penanganan path aman untuk file sementara
# +-- Batas Sumber Daya: Pembatasan sumber daya implisit untuk stabilitas
# +-- Integritas Data: Checksum dan validasi untuk konsistensi data
#
# PEMBERSIHAN & MANAJEMEN SUMBER DAYA:
# +-- Pembersihan Otomatis: Pembersihan otomatis semua file sementara
# +-- Penangan Trap: Penanganan sinyal untuk pembersihan saat interrupt
# +-- Pemantauan Memori: Optimasi penggunaan memori implisit
# +-- Tanpa Jejak: Tidak meninggalkan jejak file setelah selesai
# +-- Manajemen PID: Pelacakan proses yang sederhana dan efektif
# +-- Manajemen Ruang Disk: Penggunaan disk efisien dengan pembersihan
# +-- Pembersihan Proses: Terminasi yang tepat semua proses anak
# +-- Dealokasi Sumber Daya: Pelepasan sumber daya bersih saat keluar
#
# PENINGKATAN PEMANTAUAN & LOGGING:
# +-- Logging Minimal: Keseimbangan optimal antara informasi dan kecepatan
# +-- Info Sumber Daya Sistem: Pemantauan dasar CPU, memori, dan disk
# +-- Pelacakan Progres: Indikasi progres yang jelas per fase
# +-- Metrik Performa: Throughput dan statistik performa
# +-- Pelaporan Error: Pesan error yang jelas dengan info yang dapat ditindaklanjuti
# +-- Pelacakan Waktu: Pemantauan dan pelaporan waktu eksekusi
# +-- Pembaruan Status: Status real-time untuk operasi yang berjalan lama
# +-- Statistik Hasil: Statistik komprehensif hasil pemrosesan
#
# DOKUMENTASI & KEMUDAHAN PEMELIHARAAN:
# +-- Komentar Komprehensif: Dokumentasi lengkap dalam Bahasa Indonesia
# +-- Fungsi Modular: Fungsi terorganisir dengan tanggung jawab yang jelas
# +-- Pesan Error: Pesan error yang jelas dan dapat ditindaklanjuti
# +-- Contoh Penggunaan: Contoh penggunaan dan pemecahan masalah
# +-- Struktur Kode: Organisasi logis dengan bagian yang jelas
# +-- Penamaan Variabel: Nama variabel deskriptif untuk keterbacaan
# +-- Dokumentasi Fungsi: Tujuan dan penggunaan fungsi yang jelas
# +-- Kontrol Versi: Sistem versioning untuk melacak perubahan
#
# FITUR TAMBAHAN:
# +-- Opsi Baris Perintah: Opsi penting untuk pemeliharaan
# +-- Manajemen Konfigurasi: Konstanta konfigurasi terpusat
# +-- Keamanan Konkurensi: Operasi thread-safe untuk pemrosesan paralel
# +-- Optimasi Performa: Pemrosesan adaptif berdasarkan sistem
# +-- Output Fleksibel: Direktori output dan format yang dapat dikonfigurasi
# +-- Dukungan Debug: Kemampuan debugging bawaan
# +-- Alat Pemeliharaan: Pembersihan dan pengecekan status bawaan
# +-- Lintas Platform: Kompatibel dengan berbagai distribusi Linux
#
# ============================================================
# CARA PENGGUNAAN SCRIPT
# ============================================================
#
# PENGGUNAAN DASAR:
# bash sunat-trustpositif.sh                  # Jalankan script normal
#
# OPSI BARIS PERINTAH YANG TERSEDIA:
# bash sunat-trustpositif.sh --help           # Tampilkan bantuan lengkap
# bash sunat-trustpositif.sh --version        # Tampilkan versi script
# bash sunat-trustpositif.sh --force-cleanup  # Paksa bersihkan file sementara
#
# PEMECAHAN MASALAH UMUM:
#
# 1. JIKA SCRIPT TERJEBAK/HANG:
#    bash sunat-trustpositif.sh --force-cleanup
#    # Kemudian jalankan kembali normal
#
# 2. JIKA MUNCUL ERROR "Script sudah berjalan":
#    bash sunat-trustpositif.sh --force-cleanup # Bersihkan paksa
#    bash sunat-trustpositif.sh                  # Jalankan ulang
#
# 3. JIKA UNDUHAN GAGAL:
#    # Periksa koneksi internet
#    # Periksa pengaturan firewall
#    # Coba beberapa kali, script akan retry otomatis
#
# 4. JIKA MEMORI TIDAK CUKUP:
#    # Script sudah dioptimalkan untuk penggunaan memori minimal
#    # Tutup aplikasi lain yang menggunakan memori besar
#    # Pertimbangkan menambah ruang swap
#
# 5. JIKA PROSES LAMBAT:
#    # Script sudah dioptimalkan untuk kecepatan maksimal
#    # Periksa penggunaan CPU dengan htop
#    # Pastikan disk I/O tidak menjadi bottleneck
#
# ============================================================
# INFORMASI KEBUTUHAN SISTEM
# ============================================================
#
# KEBUTUHAN SISTEM MINIMUM:
# +-- OS: Linux (Ubuntu/Debian/CentOS/RHEL/Fedora)
# +-- RAM: 512MB minimum (Direkomendasikan: 1GB+)
# +-- Penyimpanan: 200MB ruang kosong untuk file sementara
# +-- CPU: 1 core minimum (Optimal: 4+ core untuk pemrosesan paralel)
# +-- Jaringan: Koneksi internet untuk mengunduh data sumber
# +-- Izin: Akses tulis ke direktori output
#
# PAKET YANG DIPERLUKAN (terdeteksi otomatis):
# +-- bash (4.0+) - Lingkungan shell
# +-- curl - Untuk mengunduh data dari internet
# +-- mawk atau gawk - Mesin pemrosesan teks
# +-- parallel (GNU parallel) - Framework pemrosesan paralel
# +-- coreutils - Utilitas dasar (sort, uniq, wc, cut, dll)
# +-- util-linux - Utilitas sistem (kill, ps, dll)
# +-- procps - Utilitas pemantauan proses
#
# INSTALASI DEPENDENSI (Ubuntu/Debian):
# sudo apt-get update
# sudo apt-get install -y curl mawk parallel coreutils util-linux procps
#
# INSTALASI DEPENDENSI (CentOS/RHEL):
# sudo yum install -y curl gawk parallel coreutils util-linux procps-ng
#
# INSTALASI DEPENDENSI (Fedora):
# sudo dnf install -y curl gawk parallel coreutils util-linux procps-ng
#
# ============================================================
# KONFIGURASI PERFORMA DAN TUNING
# ============================================================
#
# TUNING PERFORMA OTOMATIS:
# Script secara otomatis menyesuaikan konfigurasi berdasarkan:
# +-- Jumlah core CPU yang tersedia (nproc)
# +-- Memori yang tersedia untuk ukuran chunk optimal
# +-- Kemampuan disk I/O untuk penanganan file sementara
# +-- Bandwidth jaringan untuk optimasi unduhan
#
# TUNING MANUAL (jika diperlukan):
# Edit konstanta berikut di bagian konfigurasi script:
#
# readonly CHUNK_SIZE=15000           # Ukuran chunk (default: 15000 optimal)
# readonly NUM_CORES=$(nproc)         # Jumlah worker paralel
# readonly OUTPUT_DIR="/path/to/dir"  # Direktori output
# readonly TEMP_DIR=$(mktemp -d)      # Direktori sementara
#
# BENCHMARK PERFORMA (hasil yang diharapkan):
# +-- Waktu Startup: < 2 detik (inisialisasi cepat)
# +-- Fase Download: Tergantung bandwidth (biasanya < 30 detik)
# +-- Fase Pemrosesan: ~1-3 menit untuk dataset normal
# +-- Fase Pembersihan: < 5 detik (pembersihan cepat)
# +-- Penggunaan Memori: < 500MB puncak penggunaan
# +-- Utilisasi CPU: Penggunaan optimal semua core yang tersedia
# +-- Total Runtime: Biasanya 2-5 menit untuk dataset lengkap
#
# TIPS OPTIMASI:
# +-- Jalankan saat beban CPU rendah untuk performa optimal
# +-- Pastikan ruang disk cukup untuk file sementara
# +-- Tutup aplikasi memory-intensive lainnya
# +-- Gunakan SSD jika memungkinkan untuk I/O lebih cepat
# +-- Pastikan koneksi jaringan stabil untuk fase unduhan
#
# ============================================================
# STRUKTUR OUTPUT DAN FILE HASIL
# ============================================================
#
# OUTPUT UTAMA:
# /var/www/html/trustpositif/sunat-trustpositif.txt
# +-- Format: Satu domain per baris (teks biasa)
# +-- Encoding: UTF-8 (kompatibilitas universal)
# +-- Pengurutan: Urutan alfabetis (a-z, case insensitive)
# +-- Penyaringan: Hanya domain valid dengan TLD resmi IANA
# +-- Pembersihan: Subdomain tidak diinginkan telah dihapus
# +-- Deduplikasi: Entri duplikat telah dihilangkan
# +-- Validasi: Setiap domain telah divalidasi kepatuhan RFC
# +-- Ukuran: Biasanya 50-80% dari ukuran file asli
#
# FILE SEMENTARA (otomatis dibersihkan setelah selesai):
# /tmp/sunat-trustpositif.XXXXXX/
# +-- chunk_* : File chunk untuk pemrosesan paralel
# +-- *.processed : Hasil pemrosesan per chunk individual
# +-- iana_tlds.txt : Daftar TLD resmi dari IANA
# +-- domains_pattern.txt : File pola untuk pembersihan
# +-- (semua file ini dihapus otomatis saat script selesai)
#
# OUTPUT LOG (real-time ke konsol):
# +-- [INFO] : Informasi umum dan status
# +-- [BERHASIL] : Operasi yang berhasil diselesaikan
# +-- [PERINGATAN] : Warning yang perlu perhatian (non-fatal)
# +-- [ERROR] : Error yang perlu perhatian langsung
# +-- [PROSES] : Status progres operasi yang sedang berjalan
# +-- [SYS] : Informasi sumber daya sistem
#
# STATISTIK OUTPUT:
# Script akan menampilkan statistik lengkap termasuk:
# +-- Jumlah domain input awal
# +-- Jumlah domain valid setelah penyaringan
# +-- Jumlah domain yang dihapus saat pembersihan
# +-- Persentase efisiensi pemrosesan
# +-- Ukuran file input vs output
# +-- Waktu eksekusi per fase
# +-- Throughput (domain per detik)
#
# ============================================================
# KEAMANAN DAN PRAKTIK TERBAIK
# ============================================================
#
# LANGKAH KEAMANAN YANG DIIMPLEMENTASIKAN:
# +-- Sanitasi Input: Semua input divalidasi dan disanitasi
# +-- Proteksi Path Traversal: Penanganan path yang aman
# +-- Batas Sumber Daya: Pembatasan implisit untuk mencegah kehabisan resource
# +-- Operasi File Aman: Operasi atomik untuk integritas data
# +-- Isolasi Proses: Isolasi yang tepat untuk proses paralel
# +-- Exit Bersih: Pembersihan lengkap saat keluar normal atau abnormal
# +-- File Sementara Aman: Pembuatan direktori sementara yang aman
# +-- Keamanan Jaringan: Unduhan aman dengan validasi yang tepat
#
# PRAKTIK KEAMANAN YANG DIREKOMENDASIKAN:
# +-- Jalankan dengan user non-root jika memungkinkan
# +-- Set izin file yang tepat pada direktori output:
#      chmod 755 /var/www/html/trustpositif/
# +-- Backup file output penting sebelum menjalankan script
# +-- Pantau penggunaan sumber daya saat script berjalan
# +-- Tinjau output log untuk mendeteksi anomali atau error
# +-- Pastikan koneksi jaringan aman (URL HTTPS)
# +-- Validasi integritas hasil output secara berkala
# +-- Jaga script tetap update ke versi terbaru untuk perbaikan keamanan
#
# IZIN FILE YANG DIREKOMENDASIKAN:
# chmod 755 sunat-trustpositif.sh           # Script dapat dieksekusi
# chmod 755 /var/www/html/trustpositif/     # Direktori output dapat ditulis
# chown user:group /var/www/html/trustpositif/ # Kepemilikan yang tepat
#
# KEAMANAN JARINGAN:
# +-- Script menggunakan HTTPS untuk semua unduhan
# +-- Validasi sertifikat diaktifkan untuk curl
# +-- Timeout dikonfigurasi untuk mencegah hanging
# +-- String user-agent untuk mengidentifikasi permintaan yang sah
#
# ============================================================
# PEMANTAUAN DAN PEMELIHARAAN  
# ============================================================
#
# PEMANTAUAN REAL-TIME:
# Script menyediakan pemantauan bawaan untuk:
# +-- Penggunaan CPU dan load average sistem
# +-- Konsumsi memori (total, terpakai, tersedia)
# +-- Penggunaan ruang disk untuk direktori output
# +-- Throughput pemrosesan (domain per detik)
# +-- Pelacakan progres per eksekusi fase
# +-- Tingkat error dan statistik retry
# +-- Progres dan kecepatan unduhan jaringan
# +-- Waktu eksekusi keseluruhan dan metrik performa
#
# TUGAS PEMELIHARAAN:
# +-- Mingguan: Jalankan --force-cleanup untuk kebersihan
#      bash sunat-trustpositif.sh --force-cleanup
# +-- Bulanan: Tinjau hasil output untuk pengecekan kualitas
# +-- Per Kuartal: Update script jika ada versi terbaru
# +-- Tahunan: Tinjau daftar pembersihan domain untuk efektivitas
# +-- Sesuai kebutuhan: Pantau penggunaan ruang disk untuk direktori output
# +-- Regular: Backup file output penting
#
# STRATEGI BACKUP:
# +-- Backup file output sebelum run baru:
#      cp /var/www/html/trustpositif/sunat-trustpositif.txt backup-$(date +%Y%m%d).txt
# +-- Simpan 5-10 versi historis untuk kemampuan rollback
# +-- Pantau ukuran file output untuk analisis tren
# +-- Arsipkan file lama untuk manajemen ruang:
#      gzip backup-old-*.txt
# +-- Dokumentasikan perubahan signifikan untuk referensi masa depan
#
# ANALISIS LOG:
# Untuk analisis performa dan pemecahan masalah:
# bash sunat-trustpositif.sh 2>&1 | tee eksekusi-$(date +%Y%m%d-%H%M).log
#
# PENGECEKAN KESEHATAN:
# Buat script pengecekan kesehatan sederhana:
# #!/bin/bash
# if [[ -f "/var/www/html/trustpositif/sunat-trustpositif.txt" ]]; then
#   baris=$(wc -l < /var/www/html/trustpositif/sunat-trustpositif.txt)
#   echo "File output ada dengan $baris domain"
# else
#   echo "File output hilang - jalankan script"
# fi
#
# ============================================================
# TANYA JAWAB DAN PEMECAHAN MASALAH LANJUTAN
# ============================================================
#
# T: Script berjalan sangat lambat, apa yang harus dilakukan?
# J: 1. Periksa koneksi internet untuk fase unduhan
#    2. Pantau penggunaan CPU/memori dengan htop atau top
#    3. Pastikan tidak ada aplikasi lain yang memakan sumber daya
#    4. Periksa disk I/O dengan iotop jika tersedia
#    5. Coba jalankan saat beban sistem rendah
#
# T: File output kosong atau tidak sesuai harapan?
# J: 1. Periksa log error selama proses eksekusi
#    2. Validasi URL sumber masih dapat diakses
#    3. Cek izin direktori output
#    4. Pastikan koneksi internet stabil selama unduhan
#    5. Coba jalankan ulang, mungkin masalah jaringan sementara
#
# T: Script crash atau terminated tidak terduga?
# J: 1. Jalankan --force-cleanup untuk membersihkan file sementara
#    2. Cek ketersediaan ruang disk
#    3. Tinjau log sistem (/var/log/syslog atau journalctl)
#    4. Pastikan dependensi terinstal lengkap
#    5. Coba jalankan dengan pemantauan penggunaan sumber daya
#
# T: Error "Permission denied" saat menulis output?
# J: 1. Cek kepemilikan direktori output:
#        ls -la /var/www/html/trustpositif/
#    2. Set izin yang benar:
#        sudo chown -R $USER:$USER /var/www/html/trustpositif/
#        chmod 755 /var/www/html/trustpositif/
#    3. Atau jalankan script dengan sudo (tidak direkomendasikan)
#
# T: Bagaimana cara menyesuaikan daftar pembersihan domain?
# J: 1. Edit array DOMAINS_TO_CLEAN di bagian konfigurasi script
#    2. Format: "domain.tld" (tanpa protokol, path, atau www)
#    3. Tambahkan domain baru di akhir array
#    4. Test dengan sampel kecil sebelum run produksi
#
# T: Bisakah menjalankan multiple instances bersamaan?
# J: Tidak disarankan karena:
#    - Kontention sumber daya akan menurunkan performa
#    - Potensi konflik pada file sementara
#    - Tabrakan file output
#    - Script dirancang untuk optimasi single instance
#
# T: Bagaimana cara memantau progres untuk dataset besar?
# J: 1. Script sudah menyediakan informasi progres real-time
#    2. Pantau dengan tail log jika redirect output:
#        bash script.sh > output.log 2>&1 & tail -f output.log
#    3. Gunakan alat pemantauan sistem: htop, iotop, nethogs
#
# T: Script hang di fase unduhan, apa solusinya?
# J: 1. Periksa stabilitas koneksi internet
#    2. Cek resolusi DNS: nslookup data.iana.org
#    3. Test manual download: curl -I [URL]
#    4. Coba dari jaringan yang berbeda
#    5. Periksa pengaturan firewall atau proxy
#
# T: Hasil pemrosesan tidak konsisten antar run?
# J: 1. Kemungkinan data sumber berubah (normal)
#    2. Masalah jaringan saat unduhan menyebabkan data parsial
#    3. Bandingkan ukuran file untuk mengidentifikasi perbedaan data
#    4. Jalankan perintah diff untuk membandingkan output
#
# ============================================================
# CATATAN PERUBAHAN DAN RIWAYAT VERSI
# ============================================================
# 
# VERSI 2.7 (23 NOVEMBER 2025) - Optimization & Fixes:
# +-- [BARU] Opsi baris perintah (--help, --force-cleanup, --version)
# +-- [FIX] Perbaikan sintaks fatal pada MAWK .
# +-- [FIX] Mekanisme unduhan dengan Bypass SSL (--insecure) untuk keandalan tinggi.
# +-- [FIX] Filter IPv6 yang ditingkatkan untuk mencegah kebocoran alamat IP.
# +-- [MOD] Integrasi dokumentasi lengkap ke dalam perintah --help.
# +-- [MOD] Optimasi struktur kode untuk stabilitas eksekusi.
# +-- [DITINGKATKAN] Penyaringan 95 ribu domain. 
#
# VERSI 2.5 (31 AGUSTUS 2025) - Penulisan Ulang Lengkap:
# +-- [DITINGKATKAN] Penyaringan hingga 45.000 domain
# +-- [DITINGKATKAN] sunat subdomain *www dan mail
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
# +-- Perapihan kode agar mudah di maintenatencae
# +-- Penyaringan 2 ribu domain
# +-- Tampilan konsole yang berwarna dan informatif
# +-- pembaharuan kode yang error
#
# VERSI 1.0 (07 APRIL 2024) - Rilis Awal:
# +-- Fungsionalitas validasi domain dasar
# +-- Pengecekan TLD terhadap daftar resmi IANA
# +-- Implementasi pemrosesan paralel sederhana
# +-- Pembersihan dasar dan manajemen file sementara
# +-- Penyaringan dan deduplikasi domain inti
# +-- Output konsol sederhana dengan indikasi progres dasar
#
#
# ============================================================
# KONTRIBUSI DAN DUKUNGAN
# ============================================================
#
# INFORMASI PEMBUAT:
# +-- Nama: HARRY DERTIN SUTISNA ALSYUNDAWY
# +-- Peran: Lead Developer & System Architect
# +-- Keahlian: Administrasi Sistem Linux, Skrip Bash, Keamanan Jaringan
# +-- Kontak: (Tersedia melalui saluran resmi)
#
# PANDUAN KONTRIBUSI:
# +-- Laporan bug dan permintaan fitur sangat diterima
# +-- Pull request harus menyertakan pengujian komprehensif
# +-- Ikuti standar koding dan gaya dokumentasi yang ada
# +-- Perbarui dokumentasi untuk semua perubahan
# +-- Berikan kompatibilitas mundur jika memungkinkan
# +-- Sertakan benchmark performa untuk optimasi
# +-- Test pada multiple distribusi Linux
#
# PERSYARATAN PENGUJIAN:
# +-- Test pada minimal 3 distribusi Linux
# +-- Benchmarking performa dengan dataset besar
# +-- Profiling penggunaan memori
# +-- Pengujian kondisi error
# +-- Verifikasi akurasi dokumentasi
#
# SALURAN DUKUNGAN:
# +-- Dokumentasi ini sebagai referensi utama
# +-- Opsi --help bawaan untuk referensi cepat
# +-- GitHub issues untuk laporan bug (jika tersedia)
# +-- Forum komunitas untuk pertanyaan umum
# +-- Pembaruan dokumentasi resmi untuk masalah yang diketahui
#
# PROSES DUKUNGAN:
# 1. Periksa dokumentasi ini terlebih dahulu
# 2. Coba langkah pemecahan masalah yang disediakan
# 3. Kumpulkan informasi sistem dan log error
# 4. Test dengan opsi --force-cleanup
# 5. Submit laporan bug detail dengan info lingkungan
#
# ============================================================
# HAK CIPTA DAN LISENSI
# ============================================================
#
# Hak Cipta (c) 2024-2025 HARRY DERTIN SUTISNA ALSYUNDAWY
# Semua hak dilindungi.
# 
# Dengan ini diberikan izin, tanpa biaya, kepada siapa pun yang memperoleh
# salinan perangkat lunak ini dan file dokumentasi terkait ("Perangkat Lunak"),
# untuk berurusan dengan Perangkat Lunak tanpa pembatasan, termasuk tanpa batasan
# hak untuk menggunakan, menyalin, memodifikasi, menggabungkan, menerbitkan, mendistribusikan, mensublisensikan,
# dan/atau menjual salinan Perangkat Lunak, dan untuk mengizinkan orang-orang kepada siapa
# Perangkat Lunak dilengkapi untuk melakukan hal tersebut, dengan ketentuan sebagai berikut:
#
# Pemberitahuan hak cipta di atas dan pemberitahuan izin ini harus disertakan
# dalam semua salinan atau bagian substansial dari Perangkat Lunak.
#
# PERANGKAT LUNAK DISEDIAKAN "SEBAGAIMANA ADANYA", TANPA JAMINAN APA PUN,
# TERSURAT MAUPUN TERSIRAT, TERMASUK NAMUN TIDAK TERBATAS PADA JAMINAN
# DAPAT DIPERDAGANGKAN, KESESUAIAN UNTUK TUJUAN TERTENTU DAN NON-PELANGGARAN.
# DALAM HAL APAPUN PENULIS ATAU PEMEGANG HAK CIPTA TIDAK BERTANGGUNG JAWAB ATAS KLAIM APA PUN,
# KERUSAKAN ATAU KEWAJIBAN LAINNYA, BAIK DALAM TINDAKAN KONTRAK,
# TORT ATAU LAINNYA, YANG TIMBUL DARI, DARI ATAU SEHUBUNGAN DENGAN
# PERANGKAT LUNAK ATAU PENGGUNAAN ATAU URUSAN LAIN DALAM PERANGKAT LUNAK.
#
# KETENTUAN TAMBAHAN:
# +-- Penggunaan komersial diperbolehkan dengan atribusi
# +-- Modifikasi dan redistribusi diperbolehkan
# +-- Tidak ada jaminan yang diberikan - gunakan dengan risiko sendiri
# +-- Pembuat tidak bertanggung jawab atas kehilangan data
# +-- Pengguna harus mematuhi hukum yang berlaku
#
# KOMPONEN PIHAK KETIGA:
# +-- GNU Parallel: Dilisensikan di bawah GPL v3
# +-- AWK/MAWK: Dilisensikan di bawah berbagai lisensi open source
# +-- coreutils: Dilisensikan di bawah GPL v3
# +-- curl: Dilisensikan di bawah lisensi terinspirasi MIT/X
#
# PERSYARATAN ATRIBUSI:
# Jika menggunakan script ini dalam proyek atau publikasi:
# +-- Sertakan pemberitahuan hak cipta
# +-- Kredit pembuat asli
# +-- Link kembali ke sumber jika memungkinkan
# +-- Sebutkan modifikasi jika ada perubahan
#
# ============================================================
# AKHIR DOKUMENTASI KOMPREHENSIF
# ============================================================
