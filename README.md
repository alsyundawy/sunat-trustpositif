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


<a href="https://www.star-history.com/#alsyundawy/sunat-trustpositif&Date">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=alsyundawy/sunat-trustpositif&type=Date&theme=dark" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=alsyundawy/sunat-trustpositif&type=Date" />
   <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=alsyundawy/sunat-trustpositif&type=Date" />
 </picture>
</a>

Validates domain lists against official TLDs.  Downloads, cleans, and processes domain data trustpositif. 

-

*Waktu Eksekusi*
*[INFO] Waktu Selesai: 19 July 2025 - 15:58:05*
*[INFO] Durasi Total: 25 detik*

<img width="653" height="526" alt="image" src="https://github.com/user-attachments/assets/a61d2750-be83-4d48-a335-fdcc95c79119" />

-

# ============================================================
# ๐�“– DOKUMENTASI LENGKAP DAN PANDUAN PENGGUNAAN
# ============================================================

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

## โ�ก CARA PENGGUNAAN SCRIPT

### ๐�”ง Penggunaan Dasar
```bash
bash sunat-trustpositif.sh
```

### ๐�“� Opsi Command Line
```bash
bash sunat-trustpositif.sh --help           # Tampilkan bantuan lengkap
bash sunat-trustpositif.sh --version        # Tampilkan versi script
bash sunat-trustpositif.sh --status         # Cek status script berjalan
bash sunat-trustpositif.sh --force-cleanup  # Paksa bersihkan file temporary
bash sunat-trustpositif.sh --debug          # Mode debug untuk troubleshooting
```

### ๐��� Troubleshooting Umum
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

## ๐�–ฅ๏ธ� INFORMASI SISTEM REQUIREMENTS

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

## โ��๏ธ� KONFIGURASI PERFORMA DAN TUNING

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

## ๐�“� STRUKTUR OUTPUT DAN FILE HASIL

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

## ๐�”� KEAMANAN DAN BEST PRACTICES

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

## ๐�“ก MONITORING DAN MAINTENANCE

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

## โ�“ FAQ DAN TROUBLESHOOTING LANJUTAN

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

## ๐�“� CHANGELOG DAN VERSION HISTORY

### Version 2.0 (31 Agustus 2025)
- [NEW] Command line options (--help, --status, dll.)  
- [NEW] Automatic PID management & cleanup  
- [NEW] Enhanced error handling  
- [NEW] Performance monitoring  
- [NEW] Validasi TLD IANA & RFC  
- [IMPROVED] Filter 35k domain  
- [IMPROVED] Parallel processing efficiency  
- [IMPROVED] Memory optimization  
- [FIXED] PID file cleanup issues  
- [FIXED] Zombie process detection  
- [DOCS] Dokumentasi lengkap  

### Version 1.0 (07 April 2024)
- Initial release  
- Basic domain validation  
- TLD checking IANA  
- Simple parallel processing  
- Basic cleanup  

---

## ๐�‘จโ€�๐�’ป KONTRIBUSI DAN SUPPORT

**Author**: Harry Dertin Sutisna Alsyundawy  
**Email**: _(isi sesuai kebutuhan)_  
**GitHub**: _(link repository)_  

### Kontribusi
- Bug reports & feature requests welcome  
- Pull requests harus include tests  
- Update dokumentasi untuk perubahan  

### Support
- Baca dokumentasi ini  
- Gunakan `--debug`  
- Review system requirements  

---

## โ�–๏ธ� COPYRIGHT DAN LICENSE

```
Copyright (c) 2024-2025 
Harry Dertin Sutisna Alsyundawy

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files...
```

_Lisensi: MIT License_  

---

## ๐�”� END OF SCRIPT

*Perhatian, domain list hanya bisa digunakan untuk wilcard saja*



