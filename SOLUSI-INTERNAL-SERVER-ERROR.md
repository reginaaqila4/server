# 🔧 SOLUSI: Internal Server Error - Richdocuments Issue

## 📋 DIAGNOSIS MASALAH

Berdasarkan log error yang Anda berikan:

```
file_get_contents(/var/www/html/data/appdata_oc9lwdroe2ww/richdocuments/remoteData/capabilities): Failed to open stream: No such file or directory
```

**ROOT CAUSE**: Aplikasi **Richdocuments** (LibreOffice Online) mencoba mengakses file capabilities yang tidak ada, menyebabkan "Internal Server Error".

## 🚀 SOLUSI CEPAT

### Method 1: Disable Richdocuments App

```bash
# 1. Masuk ke container dan disable app
docker exec nextcloud-app php /var/www/html/occ app:disable richdocuments

# 2. Clear cache
docker exec nextcloud-app php /var/www/html/occ maintenance:repair

# 3. Test akses web
curl -I http://184.105.238.243:8081
```

### Method 2: Fix Missing Capabilities File

```bash
# 1. Buat direktori yang hilang
docker exec nextcloud-app mkdir -p /var/www/html/data/appdata_oc9lwdroe2ww/richdocuments/remoteData/

# 2. Buat file capabilities dummy
docker exec nextcloud-app bash -c 'echo "{}" > /var/www/html/data/appdata_oc9lwdroe2ww/richdocuments/remoteData/capabilities'

# 3. Set permissions
docker exec nextcloud-app chown -R www-data:www-data /var/www/html/data/appdata_oc9lwdroe2ww/
```

## 📁 VERIFIKASI GOOGLE DRIVE UPLOAD

Setelah memperbaiki error, test upload ke Google Drive:

```bash
# 1. Test manual file creation
docker exec nextcloud-app touch /var/www/html/data/test-dashboard-upload.txt

# 2. Cek apakah muncul di Google Drive
ls -la /mnt/gdrive/nextcloud-uploads/test-dashboard-upload.txt

# 3. Test dari dashboard web
# - Login ke http://184.105.238.243:8081
# - Upload file via web interface
# - Cek apakah muncul di /mnt/gdrive/nextcloud-uploads/
```

## 🔍 TROUBLESHOOTING TAMBAHAN

### Jika masih error setelah disable richdocuments:

```bash
# 1. Cek log error terbaru
docker exec nextcloud-app tail -20 /var/www/html/data/nextcloud.log

# 2. Restart containers
docker compose restart

# 3. Cek permissions data directory
docker exec nextcloud-app ls -la /var/www/html/data/
```

### Jika upload dashboard tidak masuk Google Drive:

```bash
# 1. Cek mount status
mountpoint /mnt/gdrive

# 2. Cek permissions Google Drive
ls -ld /mnt/gdrive/nextcloud-uploads/

# 3. Test write access
docker exec nextcloud-app touch /var/www/html/data/test-write-$(date +%s).txt

# 4. Cek di Google Drive
ls -la /mnt/gdrive/nextcloud-uploads/test-write-*
```

## ✅ HASIL YANG DIHARAPKAN

Setelah menjalankan solusi:

1. ✅ Web interface accessible tanpa "Internal Server Error"
2. ✅ Dashboard login normal
3. ✅ File upload via dashboard masuk ke Google Drive
4. ✅ Database tetap di VPS (tidak di Google Drive)
5. ✅ Google Drive hanya untuk user uploads

## 🎯 LANGKAH SELANJUTNYA

1. **Jalankan salah satu method di atas**
2. **Test akses web interface**  
3. **Test upload file via dashboard**
4. **Verifikasi file masuk ke Google Drive**

## ⚠️ CATATAN PENTING

- **Richdocuments** = LibreOffice Online untuk edit dokumen di browser
- Menonaktifkan richdocuments **TIDAK** mempengaruhi upload/download file normal
- Anda tetap bisa upload file, hanya tidak bisa edit dokumen Office di browser
- Jika perlu LibreOffice Online, install ulang setelah sistem stabil