# sunat-trustpositif
Validates domain lists against official TLDs.  Downloads, cleans, and processes domain data trustpositif. 



Selama ini saya membuat dns filter trustpositif berdasarkan dengan list domain dari kominfo / komdigi yang sudah disunat. agar ketika list tersebut dibuat rpz hasilnya kecil dan optimal, karena versi bind9  sampai dengan maks 9.18.xx boros resourse untuk penggunaan rpz.

Maka dari itu setahun lalu mungkin lebih saya membuat bash script sunat list domain dari database kominfo / komdigi dari size 145mb lebih (ongoing) menjadi kecil. yang mana script ini akan memvalidasi domain, character dan tld yang valid ditambah validasi domain tld dari iana. 

script ini juga mempunyai kumpulan list domain (hasil research lebih dari 5-10 subdomain) yang mana logikanya apabila ada subdomain berdasarkan domain list domain induk tersebut maka cukup domain tld induknya saja.

script ini berjalan dengan menggunakan metode dan logika sesuai perintah unix styles, namun tenang saja apabila perintah tersebut tidak ada muncul pesan mesti bagaimana. Oh iya, script ini ketika dijalankan membutuhkan resourse besar minimal 4 core dan ram 8gb, namun disarankan perbanyak core cpu sesuai mesin agar hasilnya lebih cepat optimal.

setelah setahun, sudah waktunya saya share source code dan bersifat opensource yang mana  saya share pada github. Mungkin tidak sempurna terkesan script ini berjalan lambat, silahkan modifikasi tanpa harus ijin. 
