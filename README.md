# PDF Studio Pro (iOS `.ipa` & Android `.apk`)

Aplikasi **33 Alat PDF, Konversi Dokumen Office, Alat Gambar & AI Studio Background** yang berjalan **100% Offline** langsung di perangkat iPhone/iPad (iOS) dan Android.

## Daftar Lengkap 33 Fitur
1. **AI Studio Background (2 alat — 100% On-Device ML Kit)**
   - **AI Hapus Background** (PNG Transparan HD + kontrol sensitivitas & penghalusan tepi rambut + pratinjau checkerboard)
   - **AI Ganti Background** (Pas Foto Merah/Biru, 8 warna studio, 6 gradien studio, atau foto custom + efek bokeh blur, ekspor PNG/JPG/PDF)
2. **Alat Gambar & Konversi (4 alat)**
   - Konversi JPG / PNG / JPEG, HEIC iPhone ke JPG/PNG/PDF, Upscale Gambar HD (2×/3×/4× + sharpening), Resize Gambar (Preset Pas Foto & Full HD / Piksel / Persentase)
3. **Kelola Halaman PDF (6 alat)**
   - Gabungkan PDF, Pisahkan PDF (rentang atau ZIP), Hapus Halaman, Ekstrak Halaman (PDF/ZIP), Atur Halaman Interaktif (urutan, duplikasi, putar per halaman, hapus), Putar PDF (90°/180°/270°)
4. **Optimalkan & Perbaiki PDF (2 alat)**
   - Kompres PDF (Ringan / Seimbang / Maksimal), Perbaiki PDF
5. **Konversi ke PDF (5 alat)**
   - JPG/Foto ke PDF, Word (`.docx`/`.txt`/`.md`) ke PDF, Excel (`.xlsx`/`.csv`) ke PDF, PowerPoint (`.pptx`) ke PDF, HTML ke PDF
6. **Konversi dari PDF (4 alat)**
   - PDF ke JPG/PNG HD, PDF ke Word (`.docx` asli), PDF ke Excel (`.xlsx` asli), PDF ke PowerPoint (`.pptx` asli)
7. **Edit, Tanda Tangan & Keamanan (10 alat)**
   - Nomor Halaman, Watermark PDF, Potong Margin (mm), Edit & Anotasi, Tanda Tangan Digital (kanvas jari & teks), Sensor PDF (Redact kata rahasia otomatis + blok manual), Kunci PDF (AES 128-bit), Buka Kunci PDF, Metadata & Cap Klasifikasi, Bandingkan 2 PDF

## Cara Build `.ipa` (iOS) dan `.apk` (Android) via GitHub Actions

Workflow otomatis tersedia di `.github/workflows/build_release.yml`:

1. Push perubahan ke branch `main`.
2. Buka tab **Actions** di GitHub → tunggu workflow **Build iOS (.ipa) & Android (.apk)** selesai (~5–8 menit).
3. Unduh kedua file hasil build di bagian **Artifacts**:
   - `PDFStudioPro-iOS-IPA` → `PDFStudioPro-iOS-unsigned.ipa` (install di iPhone/iPad via **AltStore**, **SideStore**, **Sideloadly**, atau **TrollStore**).
   - `PDFStudioPro-Android-APK` → `app-release.apk` (langsung install di HP Android).
