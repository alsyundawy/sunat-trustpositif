#!/usr/bin/env bash
# ============================================================
# Script Name  : patch-sunat-trustpositif.sh
# Description  : All-in-one patch script untuk semua versi
#                sunat-trustpositif.sh (v2.5 s/d v3.2).
#                Menerapkan seluruh perbaikan hasil audit
#                komprehensif tanpa merusak fungsi yang ada.
# Author       : HARRY DERTIN SUTISNA ALSYUNDAWY
# Created Date : 03 AGUSTUS 2026
# Version      : 1.0
# Usage        : bash patch-sunat-trustpositif.sh [TARGET_DIR]
#
# PATCH YANG DITERAPKAN:
#   [P1] KRITIS  - Float arithmetic bug: 9.223372036854772e+18
#                  diganti integer 9223372036854775807 (INT64_MAX)
#                  Bash [[ -lt ]] tidak support notasi float → syntax error
#   [P2] KRITIS  - Trap order: trap EXIT/INT/TERM dipindah tepat
#                  setelah mktemp (menutup window kebocoran temp dir)
#   [P3] MAJOR   - set -euo → set -Eeuo pipefail (v2.5–v3.0)
#                  flag -E wajib agar ERR trap mewarisi ke fungsi/subshell
#   [P4] MAJOR   - Tambah trap EXIT/INT/TERM pada versi v2.5–v3.0
#                  yang sama sekali tidak punya cleanup otomatis
#   [P5] MINOR   - echo -e → printf '%s\n' (v2.5–v3.0, SC2039)
#   [P6] MINOR   - check_dependencies: tambah pengecekan 'date'
#   [P7] MINOR   - Komentar END korup (dua baris menyatu) diperbaiki
#   [P8] MINOR   - Typo DOCNOTE: peningkatam → peningkatan
#   [P9] MINOR   - Nomor telepon notasi saintifik → format standar
#   [P10] INFO   - CURL_INSECURE: tambah komentar peringatan SSL bypass
# ============================================================

set -Eeuo pipefail
IFS=$'\n\t'

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export LC_ALL=C
export LANG=C

# ============================================================
# KONSTANTA & KONFIGURASI
# ============================================================

readonly PATCH_VERSION="1.0"
readonly PATCH_DATE="03 AGUSTUS 2026"
readonly SCRIPT_SELF="$(basename "$0")"

# Warna output
declare -A C=(
    [RED]=$'\e[0;31m'   [GREEN]=$'\e[0;32m'  [YELLOW]=$'\e[1;33m'
    [CYAN]=$'\e[0;36m'  [BOLD]=$'\e[1m'      [DIM]=$'\e[2m'
    [NC]=$'\e[0m'
)

# Target files: "filename:versi_mulai_float_bug:has_trap_issue:has_set_E_issue"
# Kolom: nama_file | ada_float_bug | perlu_set_E | perlu_trap | ada_echo_e
declare -A FILE_META=(
    ["sunat-trustpositif-v2.5.sh"]="no_float|need_set_E|need_trap|has_echo_e"
    ["sunat-trustpositif-v2.7.sh"]="no_float|need_set_E|need_trap|has_echo_e"
    ["sunat-trustpositif-v2.8.sh"]="no_float|need_set_E|need_trap|has_echo_e"
    ["sunat-trustpositif-v2.9.sh"]="has_float|need_set_E|need_trap|has_echo_e"
    ["sunat-trustpositif-v3.0.sh"]="has_float|need_set_E|need_trap|has_echo_e"
    ["sunat-trustpositif-v3.1.sh"]="has_float|ok_set_E|need_trap_order|ok_echo"
    ["sunat-trustpositif-v3.2.sh"]="has_float|ok_set_E|need_trap_order|ok_echo"
    ["sunat-trustpositif.sh"]="has_float|ok_set_E|need_trap_order|ok_echo"
)

# ============================================================
# LOGGING
# ============================================================

log_info()    { printf '%s[i] [INFO]    %s%s\n'    "${C[CYAN]}"   "$1" "${C[NC]}"; }
log_ok()      { printf '%s[✓] [OK]      %s%s\n'    "${C[GREEN]}"  "$1" "${C[NC]}"; }
log_warn()    { printf '%s[!] [WARN]    %s%s\n'    "${C[YELLOW]}" "$1" "${C[NC]}"; }
log_error()   { printf '%s[✗] [ERROR]   %s%s\n'    "${C[RED]}"    "$1" "${C[NC]}" >&2; }
log_skip()    { printf '%s[-] [SKIP]    %s%s\n'    "${C[DIM]}"    "$1" "${C[NC]}"; }
log_patch()   { printf '%s[P] [PATCH]   %s%s\n'    "${C[BOLD]}"   "$1" "${C[NC]}"; }
log_section() { printf '\n%s══ %s %s%s\n'           "${C[CYAN]}"   "$1" "$(printf '═%.0s' {1..50})" "${C[NC]}"; }

# ============================================================
# UTILITAS
# ============================================================

# Cek apakah pola ada di file (return 0 jika ada)
file_contains() {
    local file="$1" pattern="$2"
    grep -qF "$pattern" "$file" 2>/dev/null
}

file_contains_re() {
    local file="$1" pattern="$2"
    grep -qE "$pattern" "$file" 2>/dev/null
}

# Backup file sebelum patch
backup_file() {
    local file="$1"
    local backup="${file}.bak.$(date +%Y%m%d_%H%M%S)"
    cp -- "$file" "$backup" || { log_error "Gagal backup: $file"; return 1; }
    log_info "Backup: $backup"
}

# Hitung jumlah baris
count_lines() { wc -l < "$1" 2>/dev/null || echo 0; }

# Verifikasi patch berhasil diterapkan
verify_patch() {
    local file="$1" pattern="$2" desc="$3"
    if file_contains_re "$file" "$pattern"; then
        log_ok "Verified: $desc"
        return 0
    else
        log_warn "Verify GAGAL: $desc — cek manual: $file"
        return 1
    fi
}

# ============================================================
# FUNGSI PATCH INDIVIDUAL
# ============================================================

# [P1] Perbaiki float arithmetic bug di get_mem_mib
# Bash tidak support notasi saintifik float di [[ -lt ]]
patch_p1_float_bug() {
    local file="$1"
    local float_pat="9\.223372036854772e+18"
    local int_val="9223372036854775807"

    if ! file_contains_re "$file" "$float_pat"; then
        log_skip "P1 float bug: tidak ditemukan di $file"
        return 0
    fi

    log_patch "P1 float bug → INT64_MAX: $file"
    sed -i "s/${float_pat}/${int_val}/g" "$file" \
        || { log_error "P1 sed gagal: $file"; return 1; }
    verify_patch "$file" "$int_val" "P1 INT64_MAX terapasang"
}

# [P2] Perbaiki trap order: pindah trap tepat setelah mktemp
# Hanya untuk v3.1 dan v3.2 yang sudah punya trap tapi di urutan salah
patch_p2_trap_order() {
    local file="$1"

    # Cek apakah ada masalah: trap didefinisikan JAUH setelah mktemp
    # Kita cari baris mktemp TEMP_DIR dan baris trap, hitung selisih
    local mktemp_line trap_line
    mktemp_line=$(grep -n 'mktemp -d' "$file" 2>/dev/null | grep 'TEMP_DIR' | head -n1 | cut -d: -f1 || true)
    trap_line=$(grep -n "^trap " "$file" 2>/dev/null | head -n1 | cut -d: -f1 || true)

    if [[ -z "$mktemp_line" || -z "$trap_line" ]]; then
        log_skip "P2 trap order: mktemp/trap tidak ditemukan di $file"
        return 0
    fi

    local gap=$(( trap_line - mktemp_line ))
    if (( gap <= 5 )); then
        log_skip "P2 trap order: sudah OK (gap=${gap} baris) di $file"
        return 0
    fi

    log_patch "P2 trap order (gap=${gap} baris): $file"
    log_warn "P2: Trap order memerlukan patch manual — gap terlalu besar untuk sed otomatis aman."
    log_warn "    mktemp @ line ${mktemp_line}, trap @ line ${trap_line}"
    log_warn "    FIX MANUAL: Pindahkan blok trap (3 baris) dari line ${trap_line}"
    log_warn "    ke tepat setelah blok mktemp di line ${mktemp_line}."
    log_warn "    Blok trap yang perlu dipindah:"
    sed -n "${trap_line},$((trap_line+2))p" "$file" | while IFS= read -r ln; do
        log_warn "      $ln"
    done
    return 0
}

# [P3] Perbaiki set -euo pipefail → set -Eeuo pipefail
patch_p3_set_e() {
    local file="$1"

    # Cek apakah sudah pakai -Eeuo (sudah benar)
    if file_contains_re "$file" 'set -Eeuo'; then
        log_skip "P3 set -Eeuo: sudah benar di $file"
        return 0
    fi

    # Cek apakah ada set -euo yang perlu diperbaiki
    if ! file_contains_re "$file" 'set -euo'; then
        log_skip "P3 set -euo: tidak ditemukan di $file"
        return 0
    fi

    log_patch "P3 set -euo → set -Eeuo pipefail: $file"
    sed -i 's/^set -euo pipefail$/set -Eeuo pipefail/' "$file" \
        || { log_error "P3 sed gagal: $file"; return 1; }
    verify_patch "$file" 'set -Eeuo pipefail' "P3 set -Eeuo terpasang"
}

# [P4] Tambah trap EXIT/INT/TERM pada versi yang belum punya sama sekali
patch_p4_add_trap() {
    local file="$1"

    # Jika sudah ada trap, skip
    if file_contains_re "$file" '^trap '; then
        log_skip "P4 add trap: sudah ada trap di $file"
        return 0
    fi

    # Cari baris TEMP_DIR=...mktemp... untuk insert setelah baris itu
    local mktemp_line
    mktemp_line=$(grep -n 'mktemp -d' "$file" 2>/dev/null | grep 'TEMP_DIR' | head -n1 | cut -d: -f1 || true)

    if [[ -z "$mktemp_line" ]]; then
        log_warn "P4 add trap: baris mktemp TEMP_DIR tidak ditemukan di $file"
        return 0
    fi

    log_patch "P4 add trap setelah mktemp (line ${mktemp_line}): $file"

    # Sisipkan blok trap setelah baris mktemp menggunakan awk
    local trap_block
    trap_block='_cleanup_tmp() { local ec="${1:-$?}"; [[ -n "${TEMP_DIR:-}" && -d "${TEMP_DIR}" ]] && rm -rf -- "${TEMP_DIR:?}" 2>/dev/null || true; [[ -n "${VALID_OUTPUT_TMP:-}" && -f "${VALID_OUTPUT_TMP}" ]] && rm -f -- "${VALID_OUTPUT_TMP:?}" 2>/dev/null || true; exit "${ec}"; }\ntrap '"'"'_cleanup_tmp "$?"'"'"' EXIT\ntrap '"'"'_cleanup_tmp 130'"'"' INT\ntrap '"'"'_cleanup_tmp 143'"'"' TERM'

    awk -v ln="$mktemp_line" -v blk="$trap_block" '
        NR == ln { print; print blk; next }
        { print }
    ' "$file" > "${file}.p4.tmp" \
        && mv -f -- "${file}.p4.tmp" "$file" \
        || { rm -f -- "${file}.p4.tmp" 2>/dev/null; log_error "P4 awk gagal: $file"; return 1; }

    verify_patch "$file" '^trap ' "P4 trap EXIT/INT/TERM terpasang"
}

# [P5] Ganti echo -e dengan printf '%s\n' (di luar heredoc/AWK)
patch_p5_echo_e() {
    local file="$1"

    if ! file_contains_re "$file" '^[[:space:]]*echo -e '; then
        log_skip "P5 echo -e: tidak ditemukan di $file"
        return 0
    fi

    local count
    count=$(grep -cE '^[[:space:]]*echo -e ' "$file" 2>/dev/null || true)
    log_patch "P5 echo -e → printf (${count} baris): $file"

    # Ganti pola: echo -e "..." → printf '%s\n' "..."
    # Hanya baris yang dimulai dengan spasi/tab opsional lalu echo -e
    sed -i -E "s/^([[:space:]]*)echo -e (\".*\")$/\1printf '%s\\\\n' \2/" "$file" \
        || { log_error "P5 sed gagal: $file"; return 1; }

    local remaining
    remaining=$(grep -cE '^[[:space:]]*echo -e ' "$file" 2>/dev/null || true)
    if (( remaining > 0 )); then
        log_warn "P5: Masih ada ${remaining} echo -e yang tidak ter-patch (mungkin multi-line atau dalam subshell) — cek manual"
    else
        log_ok "P5 echo -e: semua diganti printf"
    fi
}

# [P6] Tambah pengecekan 'date' di check_dependencies
patch_p6_date_dep() {
    local file="$1"

    # Cek apakah check_dependencies ada
    if ! file_contains "$file" 'check_dependencies()'; then
        log_skip "P6 date dep: check_dependencies tidak ada di $file"
        return 0
    fi

    # Cek apakah 'date' sudah ada di check_dependencies
    if file_contains_re "$file" 'install_missing_command.*"date"'; then
        log_skip "P6 date dep: sudah ada di $file"
        return 0
    fi

    log_patch "P6 tambah 'date' ke check_dependencies: $file"

    # Sisipkan baris date setelah baris install_missing_command "head"
    sed -i '/install_missing_command "head".*coreutils.*exit 1/a\    install_missing_command "date"   "coreutils" "coreutils" "coreutils" || { log_error "Dependency hilang: date";    exit 1; }' "$file" \
        || { log_error "P6 sed gagal: $file"; return 1; }

    verify_patch "$file" 'install_missing_command.*"date"' "P6 date dependency terpasang"
}

# [P7] Perbaiki komentar END korup (dua baris menyatu)
patch_p7_end_comment() {
    local file="$1"
    local corrupt_pat='=======================================#'

    if ! file_contains "$file" '=======================================#'; then
        log_skip "P7 end comment: tidak ada pola korup di $file"
        return 0
    fi

    log_patch "P7 end comment korup: $file"
    sed -i 's/=======================================#[[:space:]]*/=======================================================\n#/' "$file" \
        || { log_error "P7 sed gagal: $file"; return 1; }
    log_ok "P7 end comment diperbaiki"
}

# [P8] Perbaiki typo: peningkatam → peningkatan
patch_p8_typo() {
    local file="$1"

    if ! file_contains "$file" 'peningkatam'; then
        log_skip "P8 typo: tidak ditemukan di $file"
        return 0
    fi

    log_patch "P8 typo peningkatam → peningkatan: $file"
    sed -i 's/peningkatam/peningkatan/g' "$file" \
        || { log_error "P8 sed gagal: $file"; return 1; }
    verify_patch "$file" 'peningkatan' "P8 typo diperbaiki"
}

# [P9] Perbaiki nomor telepon notasi saintifik di banner dan komentar
patch_p9_phone() {
    local file="$1"
    local sci_pat='8\.568515212e+09'
    local std_num='+6285685152120'

    if ! file_contains_re "$file" "$sci_pat"; then
        log_skip "P9 phone number: tidak ditemukan di $file"
        return 0
    fi

    log_patch "P9 nomor telepon notasi saintifik → standar: $file"
    sed -i "s/${sci_pat}/${std_num}/g" "$file" \
        || { log_error "P9 sed gagal: $file"; return 1; }
    verify_patch "$file" "$std_num" "P9 nomor telepon diperbaiki"
}

# [P10] Perkuat komentar peringatan CURL_INSECURE
patch_p10_curl_insecure_doc() {
    local file="$1"

    if ! file_contains "$file" 'CURL_INSECURE'; then
        log_skip "P10 CURL_INSECURE: tidak ada di $file"
        return 0
    fi

    # Cek apakah komentar keamanan sudah ada
    if file_contains "$file" 'PERINGATAN KEAMANAN'; then
        log_skip "P10 CURL_INSECURE doc: komentar sudah lengkap di $file"
        return 0
    fi

    log_patch "P10 CURL_INSECURE tambah peringatan keamanan: $file"

    # Tambahkan komentar peringatan setelah baris CURL_INSECURE default
    sed -i '/CURL_INSECURE=.*:-1/a\# [PERINGATAN KEAMANAN] CURL_INSECURE=1 menonaktifkan verifikasi SSL/TLS.\n# Aman untuk jaringan internal/cron terkontrol. Untuk strict SSL:\n#   CURL_INSECURE=0 bash '"$(basename "$file")"'' "$file" \
        || { log_error "P10 sed gagal: $file"; return 1; }
    log_ok "P10 komentar CURL_INSECURE ditambahkan"
}

# ============================================================
# FUNGSI UTAMA PATCH PER FILE
# ============================================================

patch_file() {
    local file="$1"
    local meta="${FILE_META[$(basename "$file")]:-}"

    log_section "Memproses: $(basename "$file")"

    if [[ ! -f "$file" ]]; then
        log_warn "File tidak ditemukan, dilewati: $file"
        return 0
    fi

    if [[ ! -r "$file" || ! -w "$file" ]]; then
        log_error "Permission denied: $file"
        return 1
    fi

    local lines_before
    lines_before=$(count_lines "$file")
    log_info "Ukuran awal: ${lines_before} baris"

    # Backup wajib sebelum patch
    backup_file "$file" || return 1

    local patch_count=0

    # Terapkan semua patch sesuai meta
    # [P1] Float bug — hanya versi yang punya get_mem_mib dengan float
    if [[ "$meta" == *"has_float"* ]]; then
        patch_p1_float_bug "$file" && (( patch_count++ )) || true
    fi

    # [P2] Trap order — versi yang sudah punya trap tapi urutan salah
    if [[ "$meta" == *"need_trap_order"* ]]; then
        patch_p2_trap_order "$file" || true
    fi

    # [P3] set -Eeuo — versi yang masih pakai set -euo
    if [[ "$meta" == *"need_set_E"* ]]; then
        patch_p3_set_e "$file" && (( patch_count++ )) || true
    fi

    # [P4] Tambah trap — versi yang belum punya trap sama sekali
    if [[ "$meta" == *"need_trap"* ]]; then
        patch_p4_add_trap "$file" && (( patch_count++ )) || true
    fi

    # [P5] echo -e → printf
    if [[ "$meta" == *"has_echo_e"* ]]; then
        patch_p5_echo_e "$file" && (( patch_count++ )) || true
    fi

    # [P6] date dependency — semua versi dengan check_dependencies
    patch_p6_date_dep "$file" && (( patch_count++ )) || true

    # [P7] End comment korup — hanya v3.2
    patch_p7_end_comment "$file" && (( patch_count++ )) || true

    # [P8] Typo — hanya versi yang punya DOCNOTE v3.2
    patch_p8_typo "$file" && (( patch_count++ )) || true

    # [P9] Nomor telepon — semua versi
    patch_p9_phone "$file" && (( patch_count++ )) || true

    # [P10] CURL_INSECURE doc — v3.0+
    if [[ "$meta" != *"no_float"* ]] || [[ "$meta" == *"has_float"* ]]; then
        patch_p10_curl_insecure_doc "$file" && (( patch_count++ )) || true
    fi

    local lines_after
    lines_after=$(count_lines "$file")
    log_info "Ukuran akhir: ${lines_after} baris (delta: +$(( lines_after - lines_before )))"
    log_ok "Selesai: ${patch_count} patch kategori diterapkan pada $(basename "$file")"
}

# ============================================================
# BANNER
# ============================================================

show_banner() {
    printf '\n%s' "${C[CYAN]}"
    printf '╔══════════════════════════════════════════════════════════════╗\n'
    printf '║         SUNAT-TRUSTPOSITIF ALL-IN-ONE PATCH SCRIPT          ║\n'
    printf '║                    Versi %-6s | %-20s       ║\n' "$PATCH_VERSION" "$PATCH_DATE"
    printf '╠══════════════════════════════════════════════════════════════╣\n'
    printf '║  Patch: P1-Float P2-TrapOrder P3-SetE P4-Trap P5-EchoE      ║\n'
    printf '║         P6-Date  P7-EndCmt    P8-Typo P9-Phone P10-SSL      ║\n'
    printf '╚══════════════════════════════════════════════════════════════╝\n'
    printf '%s\n\n' "${C[NC]}"
}

# ============================================================
# CEK DEPENDENCY PATCH SCRIPT
# ============================================================

check_patch_deps() {
    local missing=()
    for cmd in sed awk grep wc cp mv date basename; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    if (( ${#missing[@]} > 0 )); then
        log_error "Dependency patch hilang: ${missing[*]}"
        exit 1
    fi
    log_ok "Semua dependency patch tersedia"
}

# ============================================================
# MAIN
# ============================================================

main() {
    show_banner
    check_patch_deps

    local target_dir="${1:-.}"

    if [[ ! -d "$target_dir" ]]; then
        log_error "Target directory tidak ditemukan: $target_dir"
        exit 1
    fi

    target_dir="$(cd "$target_dir" && pwd)"
    log_info "Target directory: $target_dir"
    log_info "Patch script versi: $PATCH_VERSION ($PATCH_DATE)"

    # Daftar file target yang akan di-patch
    local files=(
        "${target_dir}/sunat-trustpositif-v2.5.sh"
        "${target_dir}/sunat-trustpositif-v2.7.sh"
        "${target_dir}/sunat-trustpositif-v2.8.sh"
        "${target_dir}/sunat-trustpositif-v2.9.sh"
        "${target_dir}/sunat-trustpositif-v3.0.sh"
        "${target_dir}/sunat-trustpositif-v3.1.sh"
        "${target_dir}/sunat-trustpositif-v3.2.sh"
        "${target_dir}/sunat-trustpositif.sh"
    )

    local total=0 patched=0 skipped=0 failed=0

    for file in "${files[@]}"; do
        total=$(( total + 1 ))
        if [[ ! -f "$file" ]]; then
            log_warn "Tidak ada: $(basename "$file") — dilewati"
            skipped=$(( skipped + 1 ))
            continue
        fi
        if patch_file "$file"; then
            patched=$(( patched + 1 ))
        else
            failed=$(( failed + 1 ))
            log_error "GAGAL patch: $(basename "$file")"
        fi
    done

    # ── Ringkasan ──────────────────────────────────────────
    printf '\n%s══ RINGKASAN PATCH %s%s\n' "${C[CYAN]}" "$(printf '═%.0s' {1..44})" "${C[NC]}"
    printf '%s  Total file  : %d%s\n'     "${C[BOLD]}"   "$total"   "${C[NC]}"
    printf '%s  Di-patch    : %d%s\n'     "${C[GREEN]}"  "$patched" "${C[NC]}"
    printf '%s  Dilewati    : %d%s\n'     "${C[DIM]}"    "$skipped" "${C[NC]}"
    printf '%s  Gagal       : %d%s\n'     "${C[RED]}"    "$failed"  "${C[NC]}"
    printf '\n'

    if (( failed > 0 )); then
        log_error "Ada ${failed} file yang gagal di-patch. Cek log di atas."
        exit 1
    fi

    log_ok "Semua patch berhasil diterapkan."
    printf '\n%s  CATATAN:%s\n' "${C[YELLOW]}" "${C[NC]}"
    printf '  - File backup tersimpan sebagai *.bak.YYYYMMDD_HHMMSS\n'
    printf '  - Patch P2 (trap order) memerlukan pengecekan manual\n'
    printf '    karena perpindahan blok multi-baris tidak aman via sed otomatis.\n'
    printf '  - Jalankan ShellCheck untuk verifikasi akhir:\n'
    printf '    shellcheck -S warning sunat-trustpositif*.sh\n'
    printf '\n'
}

main "$@"

# ============================================================
# AKHIR SCRIPT - patch-sunat-trustpositif.sh
# ============================================================
