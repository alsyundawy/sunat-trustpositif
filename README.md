# SUNAT TRUSTPOSITIF


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

Validates domain lists against official TLDs.  Downloads, cleans, and processes domain data trustpositif. 

**Anda bebas untuk mengubah, mendistribusikan script ini untuk keperluan anda**

**If you find this project helpful and would like to support it, please consider donating via https://www.paypal.me/alsyundawy. Thank you for your support!**

**Jika Anda merasa terbantu dan ingin mendukung proyek ini, pertimbangkan untuk berdonasi melalui https://www.paypal.me/alsyundawy. Terima kasih atas dukungannya!**

**Jika Anda merasa terbantu dan ingin mendukung proyek ini, pertimbangkan untuk berdonasi melalui QRIS. Terima kasih atas dukungannya!**

<img width="508" height="574" alt="image" src="https://github.com/user-attachments/assets/a0126f28-6dde-43da-ba14-d7c9a27de0df" />

-

*Waktu Eksekusi*
*[INFO] Waktu Selesai: 19 July 2025 - 15:58:05*
*[INFO] Durasi Total: 25 detik*

<img width="653" height="526" alt="image" src="https://github.com/user-attachments/assets/a61d2750-be83-4d48-a335-fdcc95c79119" />

-

### =========================================================
#  DOKUMENTASI LENGKAP DAN PANDUAN PENGGUNAAN
### =========================================================
## ๐�“� RINGKASAN PERBAIKAN DAN OPTIMASI SCRIPT

Script ini telah mengalami perbaikan dan optimasi menyeluruh untuk meningkatkan performa, keamanan, dan maintainability.

### ๐��€ OPTIMASI PERFORMA
- **Chunk Size Dinamis**: Ukuran chunk dihitung berdasarkan memori tersedia  
- **Pemrosesan AWK Dioptimalkan**: Pre-compiled regex dan hash table O(1)  
- **Resource Management**: Pemanfaatan optimal semua core CPU dan memori  
- **Parallel Processing**: GNU parallel dengan progress monitoring  
- **Memory Optimization**: Adaptive resource allocation berdasarkan sistem  

### ๐�”’ PENINGKATAN KEAMANAN & RELIABILITAS
- **Dependency Checking**: Validasi otomatis semua tool yang diperlukan  
- **Error Recovery**: Sistem retry dengan exponential backoff  
- **Input Validation**: Validasi ketat untuk semua input dan file  
- **Safe File Handling**: Penanganan file aman dengan proper locking  
- **Process Management**: Deteksi dan cleanup process zombie/orphan  

### ๐�งน PEMBERSIHAN & MANAJEMEN RESOURCE
- **Auto Cleanup**: Pembersihan otomatis semua file temporary  
- **Trap Handlers**: Signal handling untuk cleanup saat interrupt  
- **Memory Monitoring**: Monitor penggunaan memori real-time  
- **Zero Trace**: Tidak meninggalkan jejak file setelah selesai  
- **PID Management**: Deteksi dan cleanup PID file lama otomatis  

### ๐�“� PENINGKATAN MONITORING & LOGGING
- **Timestamped Logging**: Log dengan timestamp dan level yang jelas  
- **System Resource Monitoring**: Monitor CPU, memory, dan disk usage  
- **Progress Tracking**: Progress bar untuk operasi parallel  
- **Performance Metrics**: Throughput dan statistik performa  
- **Debug Mode**: Mode troubleshooting dengan logging detail  

### ๐�“� DOKUMENTASI & MAINTAINABILITY
- **Comprehensive Comments**: Dokumentasi lengkap dalam Bahasa Indonesia  
- **Modular Functions**: Fungsi terorganisir dengan separation of concerns  
- **Error Messages**: Pesan error jelas dan actionable  
- **Usage Examples**: Contoh penggunaan dan troubleshooting  
- **Version Control**: Sistem versioning untuk tracking changes  

### โ�• FITUR TAMBAHAN
- **Command Line Options**: Berbagai opsi untuk maintenance dan debug  
- **Configuration Management**: Konfigurasi terpusat mudah diubah  
- **Concurrent Safety**: Thread-safe operations untuk parallel processing  
- **Resource Optimization**: Adaptive resource allocation  
- **Status Monitoring**: Real-time monitoring status script  

---

##  โ�ก CARA PENGGUNAAN SCRIPT

### ๐�”ง Penggunaan Dasar
```bash
bash sunat-trustpositif.sh
```

###  ๐�“� Opsi Command Line
```bash
bash sunat-trustpositif.sh --help           # Tampilkan bantuan lengkap
bash sunat-trustpositif.sh --version        # Tampilkan versi script
bash sunat-trustpositif.sh --status         # Cek status script berjalan
bash sunat-trustpositif.sh --force-cleanup  # Paksa bersihkan file temporary
bash sunat-trustpositif.sh --debug          # Mode debug untuk troubleshooting
```

###  Troubleshooting Umum
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

---

##  ๐�–ฅ๏ธ� INFORMASI SISTEM REQUIREMENTS

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
sudo apt-get update && sudo apt-get install -y curl mawk parallel coreutils
```

**CentOS/RHEL:**
```bash
sudo yum install -y curl gawk parallel coreutils
```

---

##  โ��๏ธ� KONFIGURASI PERFORMA DAN TUNING

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
- 3-5x lebih cepat dari versi asli  
- 50-70% lebih efisien memori  
- Optimal CPU utilization  
- Smart buffering untuk minimal I/O  

---

##  ๐�“� STRUKTUR OUTPUT DAN FILE HASIL

### Output Utama
```
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

##  ๐�”� KEAMANAN DAN BEST PRACTICES

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

##  ๐�“ก MONITORING DAN MAINTENANCE

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
- Weekly: `--force-cleanup`  
- Monthly: Review log patterns  
- Quarterly: Update script  
- Yearly: Review domain list  

### Backup Strategy
- Simpan 3-5 versi historical  
- Archive old files  
- Monitor ukuran file  

---

##  FAQ DAN TROUBLESHOOTING LANJUTAN

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

# ๐�“� Catatan Perubahan dan Riwayat Versi

## ๐�“� Catatan Perubahan dan Riwayat Versi

---

### **VERSI 2.8 — 26 Desember 2025 — Optimasi Komprehensif & Perbaikan ShellCheck**
- **[FIX]** Semua peringatan **ShellCheck** diselesaikan _(SC2155, SC2046, SC2086, SC2034)_
- **[OPTIMASI]** Konfigurasi performa dinamis dengan `NUM_CORES` adaptif (4–32 core)
- **[OPTIMASI]** Penyesuaian `CHUNK_SIZE` otomatis sesuai kapasitas sistem
- **[FIX]** Mekanisme pembersihan file sementara yang lebih komprehensif dan aman
- **[ENHANCE]** Banner **ASCII Art** dengan alignment presisi dan informasi versi lengkap
- **[FIX]** Penanganan error diperketat pada setiap fase kritis proses
- **[OPTIMASI]** Penggunaan memori konstan melalui mekanisme *smart chunking*
- **[SECURITY]** Validasi input dan sanitasi data diperketat untuk mencegah data invalid
- **[FIX]** Perbaikan sintaks **MAWK** kritis untuk validasi domain **RFC-compliant**
- **[DOC]** Dokumentasi lengkap dalam Bahasa Indonesia dengan contoh penggunaan praktis


### **VERSI 2.7 โ€” 23 November 2025 โ€” Optimization & Fixes**
- **[BARU]** Opsi baris perintah (`--help`, `--force-cleanup`, `--version`)
- **[FIX]** Perbaikan sintaks fatal pada MAWK
- **[FIX]** Mekanisme unduhan dengan Bypass SSL (`--insecure`) untuk keandalan tinggi
- **[FIX]** Filter IPv6 yang ditingkatkan untuk mencegah kebocoran alamat IP
- **[MOD]** Integrasi dokumentasi lengkap ke dalam perintah `--help`
- **[MOD]** Optimasi struktur kode untuk stabilitas eksekusi
- **[DITINGKATKAN]** Penyaringan **95.000** domain

---

### **VERSI 2.5 โ€” 31 Agustus 2025 โ€” Penulisan Ulang Lengkap**
- **[DITINGKATKAN]** Penyaringan hingga **45.000** domain  
- **[DITINGKATKAN]** Penyunyatan subdomain `www` dan `mail`

---

### **VERSI 2.2 โ€” 22 Agustus 2025 โ€” Penulisan Ulang Lengkap**
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

### **VERSI 1.8 โ€” 05 Juni 2025 โ€” Rilis Lanjutan**
- Perapihan kode agar mudah di-maintenance  
- Penyaringan **2.000** domain  
- Tampilan konsol berwarna dan informatif  
- Pembaruan kode yang error

---

### **VERSI 1.0 โ€” 07 April 2024 โ€” Rilis Awal**
- Fungsionalitas validasi domain dasar  
- Pengecekan TLD terhadap daftar resmi **IANA**  
- Implementasi pemrosesan paralel sederhana  
- Pembersihan dasar dan manajemen file sementara  
- Penyaringan dan deduplikasi domain inti  
- Output konsol sederhana dengan indikator progres dasar

---

# ๐�“� Kontribusi dan Hak Cipta

Hak Cipta ยฉ **2024โ€“2025 HARRY DERTIN SUTISNA ALSYUNDAWY**  
Script ini disediakan **"SEBAGAIMANA ADANYA"**. Penggunaan sepenuhnya menjadi risiko pengguna.



##  KONTRIBUSI DAN SUPPORT

**Author**: Harry Dertin Sutisna Alsyundawy  
**Email**: harry@alsyundawy.com  
**GitHub**: https://github.com/alsyundawy 

### Kontribusi
- Bug reports & feature requests welcome  
- Pull requests harus include tests  
- Update dokumentasi untuk perubahan  

### Support
- Baca dokumentasi ini  
- Gunakan `--debug`  
- Review system requirements  

---

##  COPYRIGHT DAN LICENSE

```
Copyright (c) 2024-2025 
Harry Dertin Sutisna Alsyundawy

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files...
```

_Lisensi: MIT License_  

---


*Perhatian, domain list hanya bisa digunakan untuk wilcard saja*



