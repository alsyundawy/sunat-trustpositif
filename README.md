# SUNAT TRUSTPOSITIF BY HARRY DS ALSYUNDAWY

[![Latest Version](https://img.shields.io/github/v/release/alsyundawy/sunat-trustpositif)](https://github.com/alsyundawy/sunat-trustpositif/releases)
[![Maintenance Status](https://img.shields.io/maintenance/yes/9999)](https://github.com/alsyundawy/sunat-trustpositif/)
[![License](https://img.shields.io/github/license/alsyundawy/sunat-trustpositif)](https://github.com/alsyundawy/sunat-trustpositif/blob/master/LICENSE)
[![GitHub Issues](https://img.shields.io/github/issues/alsyundawy/sunat-trustpositif)](https://github.com/alsyundawy/sunat-trustpositif/issues)
[![GitHub Pull Requests](https://img.shields.io/github/issues-pr/alsyundawy/sunat-trustpositif)](https://github.com/alsyundawy/sunat-trustpositif/pulls)
[![Donate with PayPal](https://img.shields.io/badge/PayPal-donate-orange)](https://www.paypal.me/alsyundawy)
[![Sponsor with GitHub](https://img.shields.io/badge/GitHub-sponsor-orange)](https://github.com/sponsors/alsyundawy)
[![GitHub Stars](https://img.shields.io/github/stars/alsyundawy/sunat-trustpositif?style=social)](https://github.com/alsyundawy/sunat-trustpositif/stargazers)
[![GitHub Forks](https://img.shields.io/github/forks/alsyundawy/sunat-trustpositif?style=social)](https://github.com/alsyundawy/sunat-trustpositif/network/members)
[![GitHub Contributors](https://img.shields.io/github/contributors/alsyundawy/sunat-trustpositif?style=social)](https://github.com/alsyundawy/sunat-trustpositif/graphs/contributors)

## Stargazers over time

[![Stargazers over time](https://starchart.cc/alsyundawy/sunat-trustpositif.svg?variant=adaptive)](https://starchart.cc/alsyundawy/sunat-trustpositif)

**Sunat TrustPositif** adalah script Bash untuk mengunduh database domain TrustPositif/Komdigi, memangkas domain dan subdomain yang tidak diperlukan, menyaring entri tidak valid, membuang IPv4/IPv6, memvalidasi TLD resmi IANA, menghapus duplikat, dan menghasilkan file **plain text** yang siap digunakan sebagai database **DNS blacklist**, **RPZ**, blocklist resolver, atau sistem filtering berbasis DNS.

Script ini dirancang agar daftar domain TrustPositif menjadi lebih bersih, ringan, valid, dan efektif untuk pemblokiran DNS. Mode paling efektif untuk deployment DNS adalah menggunakan blokir berbasis **wildcard domain**, sehingga domain utama dan seluruh subdomain turunannya dapat ikut terblokir melalui konfigurasi DNS/RPZ.

## ✨ Fitur Utama

- Mengunduh database domain TrustPositif/Komdigi secara otomatis.
- Memangkas domain dan subdomain yang tidak diperlukan agar daftar lebih bersih.
- Menyaring domain tidak valid, data rusak, karakter ilegal, dan entri kosong.
- Membuang alamat IPv4 dan IPv6 agar output fokus hanya pada domain.
- Memvalidasi TLD menggunakan daftar resmi IANA.
- Menghapus duplikat agar hasil akhir lebih ringan dan efisien.
- Menghasilkan output **plain text** satu domain per baris.
- Siap digunakan sebagai **DNS blacklist**, **RPZ database**, resolver blocklist, atau feed filtering DNS.
- Mendukung penggunaan paling efektif dengan pola **wildcard domain blocking** untuk memblokir domain utama beserta seluruh subdomain turunannya.



### Anda bebas untuk mengubah, mendistribusikan script ini untuk keperluan anda

**If you find this project helpful and would like to support it, please consider donating via <https://www.paypal.me/alsyundawy>. Thank you for your support!**

**Jika Anda merasa terbantu dan ingin mendukung proyek ini, pertimbangkan untuk berdonasi melalui <https://www.paypal.me/alsyundawy>. Terima kasih atas dukungannya!**

**Jika Anda merasa terbantu dan ingin mendukung proyek ini, pertimbangkan untuk berdonasi melalui QRIS. Terima kasih atas dukungannya!**

![image](https://github.com/user-attachments/assets/a0126f28-6dde-43da-ba14-d7c9a27de0df)

---

#### Waktu Proses & Eksekusi

*[INFO] Waktu Mulai: 24 May 2026 - 19:54:13*

*[INFO] Durasi Total: 50 detik*

<img width="710" height="906" alt="image" src="https://github.com/user-attachments/assets/ef89b456-0448-4c26-8f17-a5f0bfa6411f" />


---

#### Anda dapat mengunduh dan mengeksekusi skrip instalasi secara otomatis dengan menggunakan salah satu perintah di bawah ini (silakan pilih salah satu, `curl` atau `wget`).

**Menggunakan `curl` (Rekomendasi):** 📥

```bash
curl -fsSL https://github.com/alsyundawy/sunat-trustpositif/raw/refs/heads/main/sunat-trustpositif.sh | bash
```

**Menggunakan `wget` (Alternative):** 📥

```bash
wget -qO- https://github.com/alsyundawy/sunat-trustpositif/raw/refs/heads/main/sunat-trustpositif.sh | bash
```

---

## DOKUMENTASI LENGKAP DAN PANDUAN PENGGUNAAN

### 📌 RINGKASAN PERBAIKAN DAN OPTIMASI SCRIPT

Script ini telah mengalami perbaikan dan optimasi menyeluruh untuk meningkatkan performa, keamanan, dan maintainability.

### 🚀 OPTIMASI PERFORMA

- **Chunk Size Dinamis**: Ukuran chunk dihitung secara adaptif: `20000 + (NUM_CORES * 1000)`
- **Pemrosesan AWK Dioptimalkan**: Pre-compiled regex dan hash table O(1) untuk pemrosesan hingga 35.000 domain/detik
- **Resource Management**: Pemanfaatan optimal semua core CPU (4-32 core) dan penggunaan memori konstan
- **Parallel Processing**: GNU parallel dengan manajemen job stabil dan progress monitoring
- **Bypass SSL Aman**: Mekanisme unduhan dengan `--insecure` untuk keandalan di lingkungan terbatas

### 🏗️ ARSITEKTUR PEMROSESAN

1. **Phase Unduhan**: Download TLD IANA & Database Kominfo dengan bypass SSL.
2. **Phase Splitting**: Membagi file domain menjadi chunk kecil berdasarkan sumber daya sistem.
3. **Phase Parallel**: Memproses setiap chunk secara bersamaan menggunakan `mawk` (validasi RFC & TLD).
4. **Phase Merging**: Menggabungkan hasil, deduplikasi (sort -u), dan pembersihan manual.
5. **Phase Reporting**: Menampilkan statistik detail dan penggunaan sumber daya akhir.

### 🔒 PENINGKATAN KEAMANAN & RELIABILITAS

- **Dependency Checking**: Validasi otomatis semua tool yang diperlukan
- **Error Recovery**: Sistem retry dengan exponential backoff
- **Input Validation**: Validasi ketat untuk semua input dan file
- **Safe File Handling**: Penanganan file aman dengan proper locking
- **Process Management**: Deteksi dan cleanup process zombie/orphan

### 🧹 PEMBERSIHAN & MANAJEMEN RESOURCE

- **Auto Cleanup**: Pembersihan otomatis semua file temporary
- **Trap Handlers**: Signal handling untuk cleanup saat interrupt
- **Memory Monitoring**: Monitor penggunaan memori real-time
- **Zero Trace**: Tidak meninggalkan jejak file setelah selesai
- **PID Management**: Deteksi dan cleanup PID file lama otomatis

### 📊 PENINGKATAN MONITORING & LOGGING

- **Timestamped Logging**: Log dengan timestamp dan level yang jelas
- **System Resource Monitoring**: Monitor CPU, memory, dan disk usage
- **Progress Tracking**: Progress bar untuk operasi parallel
- **Performance Metrics**: Throughput dan statistik performa
- **Debug Mode**: Mode troubleshooting dengan logging detail

### 📝 DOKUMENTASI & MAINTAINABILITY

- **Comprehensive Comments**: Dokumentasi lengkap dalam Bahasa Indonesia
- **Modular Functions**: Fungsi terorganisir dengan separation of concerns
- **Error Messages**: Pesan error jelas dan actionable
- **Usage Examples**: Contoh penggunaan dan troubleshooting
- **Version Control**: Sistem versioning untuk tracking changes

### ➕ FITUR TAMBAHAN

- **Command Line Options**: Berbagai opsi untuk maintenance dan debug
- **Configuration Management**: Konfigurasi terpusat mudah diubah
- **Concurrent Safety**: Thread-safe operations untuk parallel processing
- **Resource Optimization**: Adaptive resource allocation
- **Status Monitoring**: Real-time monitoring status script

---

## ⚡ CARA PENGGUNAAN SCRIPT

### 🔧 Penggunaan Dasar

```bash
bash sunat-trustpositif.sh
```

### 📌 Opsi Command Line

```bash
bash sunat-trustpositif.sh --help           # Tampilkan bantuan lengkap
bash sunat-trustpositif.sh --version        # Tampilkan versi script
bash sunat-trustpositif.sh --status         # Cek status script berjalan
bash sunat-trustpositif.sh --force-cleanup  # Paksa bersihkan file temporary
bash sunat-trustpositif.sh --debug          # Mode debug untuk troubleshooting
```

### Troubleshooting Umum

1. **Script terjebak/hang**

   ```bash
   bash sunat-trustpositif.sh --force-cleanup
   ```

   Kemudian jalankan kembali normal.

2. **Error: "Script sudah berjalan"**

   ```bash
   bash sunat-trustpositif.sh --status
   bash sunat-trustpositif.sh --force-cleanup
   bash sunat-trustpositif.sh
   ```

3. **Debugging/Troubleshoot**

   ```bash
   bash sunat-trustpositif.sh --debug
   ```

4. **Memori tidak cukup**

   - Script otomatis menyesuaikan `chunk size`.
   - Tingkatkan swap atau kurangi aplikasi lain.

5. **Download gagal**

   - Script retry otomatis 3x dengan delay.
   - Periksa koneksi internet/firewall.
   - Gunakan `--insecure` (default aktif) untuk bypass sertifikat SSL yang bermasalah.

6. **I/O Bottleneck**

   - Gunakan SSD untuk `TEMP_DIR` jika memproses >1M domain.
   - Pastikan RAM cukup agar sistem tidak melakukan berlebihan swap.

---

## 🖥️ INFORMASI SISTEM REQUIREMENTS

### Minimum System Requirements

- OS: Linux (Ubuntu/Debian/CentOS/RHEL)
- RAM: **512MB** (Rekomendasi: 2GB+)
- Storage: **100MB** free space
- CPU: **1 core** (Optimal: 4+ cores)
- Network: Internet connection

### Required Packages

- bash (4.0+)
- curl
- mawk atau gawk
- parallel (GNU parallel)
- coreutils (sort, uniq, wc, etc.)
- procps (ps, kill, etc.)

### Install Dependencies

**Ubuntu/Debian:**

```bash
sudo apt update && sudo apt install -y curl mawk parallel coreutils procps
```

**RHEL/CentOS/Fedora:**

```bash
sudo dnf install -y curl gawk parallel coreutils procps-ng
```

---

## ⚙️ KONFIGURASI PERFORMA DAN TUNING

### Automatic Performance Tuning

Script otomatis menyesuaikan konfigurasi berdasarkan:

- Jumlah CPU cores
- Memory yang tersedia
- Load average sistem
- Ruang disk

### Manual Tuning

```bash
readonly CHUNK_SIZE=15000
readonly NUM_CORES=$(nproc)
readonly OUTPUT_DIR="/path/to/dir"
```

### Performance Benchmarks

Sistem referensi: 8 core, 16GB RAM, SSD

#### Throughput

25.000 - 35.000 domain/detik

#### Dataset 1.5M

Selesai dalam 1.5 - 2.5 menit

#### Memori

Stabil di 300-600MB (constant profiling)

#### CPU

95-100% utilization di semua core yang dialokasikan

---

## 📂 STRUKTUR OUTPUT DAN FILE HASIL

### Output Utama

```text
/var/www/html/trustpositif/sunat-trustpositif.txt
```

- Satu domain per baris
- UTF-8 encoding
- Alphabetical order sorting
- Valid TLD resmi IANA

### File Temporary

- `/tmp/sunat-trustpositif.XXXXXX/`
- `chunk_*`, `*.processed`, `iana_tlds.txt`, `script.pid`

### Log Output

- `[INFO]` : Informasi umum
- `[OK]` : Operasi berhasil
- `[WARN]` : Peringatan non-fatal
- `[ERR]` : Error penting
- `[PROC]` : Status progress

---

## 🔐 KEAMANAN DAN BEST PRACTICES

### Security Measures

- Input sanitization
- Path traversal protection
- Resource limits
- Atomic file operations
- Process isolation
- Clean exit

### Recommended Practices

- Jalankan dengan user **non-root**
- Set **file permissions** dengan benar
- Backup file penting sebelum run
- Monitor log untuk deteksi anomali

### File Permissions

```bash
chmod 755 sunat-trustpositif.sh
chmod 755 /var/www/html/trustpositif/
chown user:group /var/www/html/trustpositif/
```

---

## 📡 MONITORING DAN MAINTENANCE

### Monitoring Real-time

- CPU usage & load average
- Memory consumption
- Disk space usage
- Processing throughput
- Error rate & retry statistics

### Log Analysis

```bash
bash sunat-trustpositif.sh --debug 2>&1 | tee debug.log
```

### Maintenance Tasks

- **Harian**: Pemantauan otomatis hasil output di `${OUTPUT_DIR}`.
- **Mingguan**: Eksekusi pembersihan paksa (`--force-cleanup`) untuk reset state.
- **Bulanan**: Update script dan dependensi sistem (`apt upgrade`).
- **Tahunan**: Audit komprehensif alur pemrosesan dan keamanan.

### Backup Strategy

- **Automated Copy**: `cp ${OUTPUT}.txt ${BACKUP}/$(date +%Y%m%d).txt`
- **Retention**: Simpan 3-5 versi historical terakhir.
- **Cleanup**: Hapus backup yang lebih tua dari 30 hari secara otomatis.

---

## FAQ DAN TROUBLESHOOTING LANJUTAN

**Q: Script lambat?**
A: Cek koneksi, CPU/memory (`htop`), run `--debug`.

**Q: Output kosong?**
A: Periksa log error, source download, permissions.

**Q: Script crash?**
A: Jalankan `--status`, gunakan `--force-cleanup`, cek `/var/log/syslog`.

**Q: Custom domain cleanup list?**
A: Edit `DOMAINS_TO_CLEAN` di script.

**Q: Multiple instances?**
A: Tidak disarankan (single instance protection).

---

## 📌 Catatan Perubahan dan Riwayat Versi

---

**SELAMAT ULANG TAHUN WAHAI TAURUS MEI !!!** 🥳🥳🥳🥳

### **VERSI 2.9 — 24 Mei 2026 — Output-Compatible Optimization, AWK Fallback & Runtime Hardening**

- **[PRINSIP]** v2.9 adalah optimasi internal dari v2.8; hasil default tetap dijaga kompatibel dengan pola produksi v2.8 agar jumlah baris, ukuran output, dan pola manual cleanup tidak berubah drastis.
- **[COMPAT]** Default `CUT_SUBDOMAINS=0`; script tidak melakukan *parent-domain collapse* secara agresif. Mode agresif hanya aktif jika user menjalankan `CUT_SUBDOMAINS=1` secara eksplisit.
- **[COMPAT]** Sanitasi prefix legacy tetap dipertahankan sesuai perilaku v2.8, terutama pemotongan prefix umum seperti `www.`, `mail.`, `1.`, dan `0.`.
- **[COMPAT]** Manual cleanup legacy tetap memakai pola `sed + grep -v -f` seperti v2.8 supaya domain/subdomain turunan dari daftar manual tetap tersaring mengikuti hasil produksi sebelumnya.
- **[COMPAT]** Formula performa default tetap mengikuti gaya v2.8: `NUM_CORES` dari `nproc` dengan batas aman 4–32 core dan `CHUNK_SIZE=20000+(NUM_CORES*1000)`.
- **[OPTIMASI]** AWK engine dibuat konsisten melalui `AWK_CMD` dengan prioritas deteksi `mawk -> gawk -> awk`, serta dapat dioverride manual oleh user.
- **[OPTIMASI]** Jika AWK belum tersedia, script mencoba instalasi otomatis sesuai package manager sistem: `apt/apt-get`, `dnf`, `yum`, `zypper`, atau `apk`.
- **[OPTIMASI]** Semua proses normalisasi TLD, validasi domain, dan helper AWK memakai satu AWK engine yang sama sehingga tidak lagi bercampur antara `mawk`, `gawk`, dan `awk` di lingkungan Debian/Ubuntu/RHEL.
- **[HARDENING]** Proses unduhan diperkuat dengan `curl -f`/`wget` fallback, retry, timeout, validasi file kosong, dan deteksi HTML/error page.
- **[HARDENING]** Output final dibuat atomik melalui temporary output lalu `mv` ke target akhir agar file produksi tidak rusak/setengah jadi saat gagal.
- **[HARDENING]** Trap `EXIT/INT/TERM` diperbaiki agar cleanup tetap berjalan dan exit code benar dipertahankan, termasuk `130` untuk Ctrl+C dan `143` untuk TERM.
- **[HARDENING]** `--force-cleanup` dibuat lebih aman dan tidak lagi bergantung pada `pkill` brutal yang berisiko membunuh proses lain.
- **[FIX]** Tampilan status RAM diperbaiki agar **Total RAM** dan **Tersedia** tidak kosong pada Debian/Ubuntu tertentu.
- **[FIX]** Duplikasi assignment dan inkonsistensi kecil pada blok AWK dibersihkan tanpa mengubah hasil validasi domain default.
- **[DOC]** Header, banner, `--help`, docnote, dan changelog diperbarui agar jelas bahwa v2.9 mengoptimalkan mesin proses, bukan mengganti format hasil produksi.
- **[DITINGKATKAN]** Penyaringan **91.000** domain

### **VERSI 2.8 — 26 Desember 2025 — Optimasi Komprehensif & Perbaikan ShellCheck**

- **[FIX]** Semua peringatan **ShellCheck** diselesaikan (SC2155, SC2046, SC2086, SC2034)
- **[OPTIMASI]** Konfigurasi performa dinamis dengan `NUM_CORES` adaptif (4–32 core)
- **[OPTIMASI]** Penyesuaian `CHUNK_SIZE` otomatis sesuai kapasitas sistem
- **[FIX]** Mekanisme pembersihan file sementara yang lebih komprehensif dan aman
- **[ENHANCE]** Banner **ASCII Art** dengan alignment presisi dan informasi versi lengkap
- **[FIX]** Penanganan error diperketat pada setiap fase kritis proses
- **[OPTIMASI]** Penggunaan memori konstan melalui mekanisme *smart chunking*
- **[SECURITY]** Validasi input dan sanitasi data diperketat untuk mencegah data invalid
- **[FIX]** Perbaikan sintaks **MAWK** kritis untuk validasi domain **RFC-compliant**
- **[DOC]** Dokumentasi lengkap dalam Bahasa Indonesia dengan contoh penggunaan praktis

### **VERSI 2.7 — 23 November 2025 — Optimization & Fixes**

- **[BARU]** Opsi baris perintah (`--help`, `--force-cleanup`, `--version`)
- **[FIX]** Perbaikan sintaks fatal pada MAWK
- **[FIX]** Mekanisme unduhan dengan Bypass SSL (`--insecure`) untuk keandalan tinggi
- **[FIX]** Filter IPv6 yang ditingkatkan untuk mencegah kebocoran alamat IP
- **[MOD]** Integrasi dokumentasi lengkap ke dalam perintah `--help`
- **[MOD]** Optimasi struktur kode untuk stabilitas eksekusi
- **[DITINGKATKAN]** Penyaringan **95.000** domain

---

### **VERSI 2.5 ( Agustus 2025 ) Penulisan Ulang Lengkap**

- **[DITINGKATKAN]** Penyaringan hingga **45.000** domain
- **[DITINGKATKAN]** Penyunyatan subdomain `www` dan `mail`

---

### **VERSI 2.2 ( 22 Agustus 2025 ) Penulisan Ulang Lengkap**

- **[BARU]** Penanganan error yang ditingkatkan dan mekanisme pemulihan
- **[BARU]** Pemantauan performa dan statistik detail
- **[BARU]** Pemantauan sumber daya sistem komprehensif
- **[BARU]** Validasi TLD berdasarkan **IANA & RFC**
- **[DITINGKATKAN]** Penyaringan **35.000** domain
- **[DITINGKATKAN]** Efisiensi pemrosesan paralel dengan **GNU parallel**
- **[DITINGKATKAN]** Optimasi penggunaan memori dengan **chunking cerdas**
- **[DITINGKATKAN]** Penanganan sinyal dan shutdown yang anggun
- **[DITINGKATKAN]** Validasi domain canggih dengan optimasi **AWK**
- **[DOCS]** Dokumentasi ekstensif dan panduan pemecahan masalah

---

### **VERSI 1.8 ( 05 Juni 2025 ) Rilis Lanjutan**

- Perapihan kode agar mudah di-maintenance
- Penyaringan **2.000** domain
- Tampilan konsol berwarna dan informatif
- Pembaruan kode yang error

---

### **VERSI 1.0 — 07 April 2024 — Rilis Awal**

- Fungsionalitas validasi domain dasar
- Pengecekan TLD terhadap daftar resmi **IANA**
- Implementasi pemrosesan paralel sederhana
- Pembersihan dasar dan manajemen file sementara
- Penyaringan dan deduplikasi domain inti
- Output konsol sederhana dengan indikator progres dasar

---

## 📜 Kontribusi dan Hak Cipta

Hak Cipta © **2024–2025 HARRY DERTIN SUTISNA ALSYUNDAWY**
Script ini disediakan **"SEBAGAIMANA ADANYA"**. Penggunaan sepenuhnya menjadi risiko pengguna.

## KONTRIBUSI DAN SUPPORT

**Author**: Harry Dertin Sutisna Alsyundawy
**Email**: <harry@alsyundawy.com>
**GitHub**: <https://github.com/alsyundawy>

### Kontribusi

- Bug reports & feature requests welcome
- Pull requests harus include tests
- Update dokumentasi untuk perubahan

### Support

- Baca dokumentasi ini
- Gunakan `--debug`
- Review system requirements

---

**Jika Anda merasa terbantu dan ingin mendukung proyek ini, pertimbangkan untuk berdonasi melalui <https://www.paypal.me/alsyundawy>. Terima kasih atas dukungannya!** ☕

**Jika Anda merasa terbantu dan ingin mendukung proyek ini, pertimbangkan untuk berdonasi melalui QRIS. Terima kasih atas dukungannya!** ☕

![image](https://github.com/user-attachments/assets/a0126f28-6dde-43da-ba14-d7c9a27de0df)

**Anda bebas untuk mengubah, mendistribusikan script ini untuk keperluan anda** 📝

**Jangan semangat tetap putus asa, tetaplah mengeluh meski gak ada yang pedulikan. Ketika yang lain bisa kenapa harus saya, ketika yang lain tidak bisa apalagi saya. Tetaplah hidup meski tidak berguna, maju tak gentar membela yang bayar !!!! Yoi, ya begitulah .....** 🤣

### ✨ Anda Memang Luar Biasa | Harry DS Alsyundawy | Kaum Rebahan Garis Keras & Militan ✨

---

## COPYRIGHT DAN LICENSE

```text
Copyright (c) 2023-2026
Harry Dertin Sutisna Alsyundawy

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files...
```

### Lisensi: MIT License

---

#### Perhatian, domain list hanya bisa digunakan untuk wilcard saja

![Alt](https://repobeats.axiom.co/api/embed/06cb45618374fd127021d7c32321a60acabd626e.svg "Repobeats analytics image")
