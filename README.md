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

-

*Waktu Eksekusi*
*[INFO] Waktu Selesai: 19 July 2025 - 15:58:05*
*[INFO] Durasi Total: 25 detik*

<img width="653" height="526" alt="image" src="https://github.com/user-attachments/assets/a61d2750-be83-4d48-a335-fdcc95c79119" />

-

Selama ini saya membuat dns filter trustpositif berdasarkan dengan list domain dari kominfo / komdigi yang sudah disunat. agar ketika list tersebut dibuat rpz hasilnya kecil dan optimal, karena versi bind9 sampai dengan maks versi 9.18.xx boros resourse untuk penggunaan rpz.  Beberapa list buah karya saya antara lain sudah saya upload ke https://github.com/alsyundawy/TrustPositif

Maka dari itu setahun lalu mungkin lebih (ide dan trial & error) saya membuat bash script sunat list domain dari database kominfo / komdigi dari size 145mb lebih (ongoing) menjadi kecil. yang mana script ini akan memvalidasi domain, character dan tld yang valid ditambah validasi domain tld dari iana. 

script ini juga mempunyai kumpulan list domain (hasil research lebih dari 5-10 subdomain, silahkan tambahkan) yang mana logikanya apabila ada subdomain berdasarkan domain list domain induk tersebut maka cukup domain tld induknya saja.

script ini berjalan dengan menggunakan metode dan logika sesuai perintah unix styles, namun tenang saja apabila perintah tersebut tidak ada muncul pesan mesti bagaimana. Oh iya, script ini ketika dijalankan membutuhkan resourse besar minimal 4 core dan ram 8gb, namun disarankan dedicated server dan perbanyak core cpu sesuai mesin agar hasilnya lebih cepat optimal.

Setelah hampir setahun, sudah waktunya saya share source code dan bersifat opensource yang saya share pada github. Mungkin tidak sempurna terkesan script ini berjalan lambat, silahkan modifikasi & optimalkan tanpa harus ijin. 

Terima Kasih masukan dan inspirasinya kepada semua yang tak bisa saya sebut satu persatu. 
Jangan semangat tetap putus asa, tetap mengeluh dan rebahan. Ketika orang lain bisa kenapa harus saya.

-

*Perhatian, domain list hanya bisa digunakan untuk wilcard saja*



