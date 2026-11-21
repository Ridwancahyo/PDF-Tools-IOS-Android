import 'package:cupertino_ui/cupertino_ui.dart';
import '../models/tool_item.dart';
import '../theme/app_theme.dart';

const List<String> kCategories = [
  'Semua Alat',
  'AI Background',
  'Alat Gambar',
  'Kelola PDF',
  'Optimalkan',
  'Konversi ke PDF',
  'Konversi dari PDF',
  'Edit & Keamanan',
];

const List<ToolSection> kToolSections = [
  ToolSection(
    number: '01',
    title: 'AI Studio Background',
    subtitle:
        'Hapus & ganti latar belakang foto secara otomatis 100% offline dengan tepi halus studio.',
    categoryKey: 'AI Background',
    accentColor: AppTheme.gold,
  ),
  ToolSection(
    number: '02',
    title: 'Alat Gambar & Konversi',
    subtitle:
        'Ubah format JPG/PNG/JPEG, konversi HEIC iPhone, tingkatkan resolusi HD, dan ubah ukuran presisi.',
    categoryKey: 'Alat Gambar',
    accentColor: AppTheme.navy,
  ),
  ToolSection(
    number: '03',
    title: 'Kelola Halaman PDF',
    subtitle:
        'Gabungkan, pisahkan, hapus, ekstrak, atur ulang urutan, dan putar halaman dokumen PDF.',
    categoryKey: 'Kelola PDF',
    accentColor: AppTheme.pdfRed,
  ),
  ToolSection(
    number: '04',
    title: 'Optimalkan & Perbaiki PDF',
    subtitle:
        'Perkecil ukuran file PDF secara cerdas atau rekonstruksi struktur dokumen bermasalah.',
    categoryKey: 'Optimalkan',
    accentColor: AppTheme.emerald,
  ),
  ToolSection(
    number: '05',
    title: 'Konversi ke PDF',
    subtitle:
        'Ubah gambar, Word (.docx), Excel (.xlsx/.csv), PowerPoint (.pptx), dan HTML menjadi PDF rapi.',
    categoryKey: 'Konversi ke PDF',
    accentColor: AppTheme.officeBlue,
  ),
  ToolSection(
    number: '06',
    title: 'Konversi dari PDF',
    subtitle:
        'Ekspor halaman PDF ke gambar JPG/PNG HD, dokumen Word (.docx), Excel (.xlsx), dan PowerPoint (.pptx).',
    categoryKey: 'Konversi dari PDF',
    accentColor: AppTheme.officeOrange,
  ),
  ToolSection(
    number: '07',
    title: 'Edit, Tanda Tangan & Keamanan',
    subtitle:
        'Penomoran halaman, watermark, crop margin, anotasi, tanda tangan digital, sensor rahasia, kunci/buka password, metadata, dan perbandingan PDF.',
    categoryKey: 'Edit & Keamanan',
    accentColor: AppTheme.studioViolet,
  ),
];

const List<ToolItem> kAllTools = [
  // =========================================================================
  // 01. AI Studio Background (2 alat)
  // =========================================================================
  ToolItem(
    id: 'ai_remove_bg',
    title: 'AI Hapus Background',
    shortTitle: 'Hapus BG',
    description:
        'Hapus latar belakang foto otomatis oleh AI lokal dengan penghalusan tepi (PNG transparan HD).',
    category: 'AI Background',
    icon: CupertinoIcons.wand_stars,
    accentColor: AppTheme.gold,
    inputKind: ToolInputKind.singleImage,
    allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'heic'],
    badge: 'AI',
    isFeatured: true,
  ),
  ToolItem(
    id: 'ai_replace_bg',
    title: 'AI Ganti Background',
    shortTitle: 'Ganti BG',
    description:
        'Ganti background ke warna pas foto merah/biru, gradien studio, atau foto custom + efek bokeh.',
    category: 'AI Background',
    icon: CupertinoIcons.photo_on_rectangle,
    accentColor: AppTheme.gold,
    inputKind: ToolInputKind.singleImage,
    allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'heic'],
    badge: 'AI',
    isFeatured: true,
  ),

  // =========================================================================
  // 02. Alat Gambar & Konversi (4 alat)
  // =========================================================================
  ToolItem(
    id: 'img_convert',
    title: 'Konversi JPG / PNG / JPEG',
    shortTitle: 'Konversi Img',
    description:
        'Ubah format gambar JPG, PNG, JPEG, atau WebP secara instan dengan kontrol kualitas & warna latar.',
    category: 'Alat Gambar',
    icon: CupertinoIcons.arrow_2_squarepath,
    accentColor: AppTheme.navy,
    inputKind: ToolInputKind.singleImage,
    allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp'],
  ),
  ToolItem(
    id: 'heic_convert',
    title: 'HEIC ke JPG / PNG / PDF',
    shortTitle: 'HEIC Convert',
    description:
        'Konversi foto HEIC / HEIF dari iPhone & iPad menjadi JPG, PNG, atau langsung dokumen PDF.',
    category: 'Alat Gambar',
    icon: CupertinoIcons.device_phone_portrait,
    accentColor: AppTheme.navy,
    inputKind: ToolInputKind.singleImage,
    allowedExtensions: ['heic', 'heif', 'jpg', 'jpeg', 'png'],
    badge: 'iOS',
  ),
  ToolItem(
    id: 'img_upscale',
    title: 'Upscale Gambar HD',
    shortTitle: 'Upscale HD',
    description:
        'Perbesar resolusi foto hingga 2×, 3×, atau 4× dengan interpolasi kubik dan penajaman tepi adaptif.',
    category: 'Alat Gambar',
    icon: CupertinoIcons.sparkles,
    accentColor: AppTheme.navy,
    inputKind: ToolInputKind.singleImage,
    allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
    badge: 'HD',
  ),
  ToolItem(
    id: 'img_resize',
    title: 'Resize Gambar',
    shortTitle: 'Resize Img',
    description:
        'Ubah dimensi gambar berdasarkan piksel presisi, persentase, atau preset Full HD & pas foto 3×4/4×6.',
    category: 'Alat Gambar',
    icon: CupertinoIcons.crop,
    accentColor: AppTheme.navy,
    inputKind: ToolInputKind.singleImage,
    allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
  ),

  // =========================================================================
  // 03. Kelola Halaman PDF (6 alat)
  // =========================================================================
  ToolItem(
    id: 'pdf_merge',
    title: 'Gabungkan PDF',
    shortTitle: 'Gabung PDF',
    description:
        'Satukan beberapa file PDF menjadi satu dokumen utuh dengan kontrol urutan file yang fleksibel.',
    category: 'Kelola PDF',
    icon: CupertinoIcons.doc_on_doc_fill,
    accentColor: AppTheme.pdfRed,
    inputKind: ToolInputKind.multiPdf,
    allowedExtensions: ['pdf'],
    isFeatured: true,
  ),
  ToolItem(
    id: 'pdf_split',
    title: 'Pisahkan PDF',
    shortTitle: 'Pisah PDF',
    description:
        'Pecah dokumen PDF berdasarkan rentang halaman (misal 1-3, 5) atau pisah semua halaman ke ZIP.',
    category: 'Kelola PDF',
    icon: CupertinoIcons.scissors,
    accentColor: AppTheme.pdfRed,
    inputKind: ToolInputKind.singlePdf,
    allowedExtensions: ['pdf'],
  ),
  ToolItem(
    id: 'pdf_delete_pages',
    title: 'Hapus Halaman',
    shortTitle: 'Hapus Hal.',
    description:
        'Pilih halaman yang tidak diperlukan dari dokumen PDF dan simpan sisanya secara rapi.',
    category: 'Kelola PDF',
    icon: CupertinoIcons.trash_fill,
    accentColor: AppTheme.pdfRed,
    inputKind: ToolInputKind.singlePdf,
    allowedExtensions: ['pdf'],
  ),
  ToolItem(
    id: 'pdf_extract',
    title: 'Ekstrak Halaman',
    shortTitle: 'Ekstrak Hal.',
    description:
        'Ambil halaman tertentu dari dokumen PDF menjadi satu PDF baru atau file terpisah dalam arsip ZIP.',
    category: 'Kelola PDF',
    icon: CupertinoIcons.square_arrow_up_on_square_fill,
    accentColor: AppTheme.pdfRed,
    inputKind: ToolInputKind.singlePdf,
    allowedExtensions: ['pdf'],
  ),
  ToolItem(
    id: 'pdf_organize',
    title: 'Atur Halaman PDF',
    shortTitle: 'Atur Hal.',
    description:
        'Urutkan ulang posisi halaman, duplikasi, putar per halaman, atau hapus halaman secara interaktif.',
    category: 'Kelola PDF',
    icon: CupertinoIcons.square_grid_2x2_fill,
    accentColor: AppTheme.pdfRed,
    inputKind: ToolInputKind.singlePdf,
    allowedExtensions: ['pdf'],
    badge: 'Pro',
  ),
  ToolItem(
    id: 'pdf_rotate',
    title: 'Putar PDF',
    shortTitle: 'Putar PDF',
    description:
        'Putar orientasi halaman PDF 90°, 180°, atau 270° untuk seluruh dokumen atau halaman tertentu.',
    category: 'Kelola PDF',
    icon: CupertinoIcons.rotate_right_fill,
    accentColor: AppTheme.pdfRed,
    inputKind: ToolInputKind.singlePdf,
    allowedExtensions: ['pdf'],
  ),

  // =========================================================================
  // 04. Optimalkan & Perbaiki PDF (2 alat)
  // =========================================================================
  ToolItem(
    id: 'pdf_compress',
    title: 'Kompres PDF',
    shortTitle: 'Kompres PDF',
    description:
        'Perkecil ukuran file PDF dengan 3 mode optimasi (Ringan, Seimbang, Maksimal) dan laporan hemat ukuran.',
    category: 'Optimalkan',
    icon: CupertinoIcons.arrow_down_right_arrow_up_left,
    accentColor: AppTheme.emerald,
    inputKind: ToolInputKind.singlePdf,
    allowedExtensions: ['pdf'],
    isFeatured: true,
  ),
  ToolItem(
    id: 'pdf_repair',
    title: 'Perbaiki PDF',
    shortTitle: 'Perbaiki PDF',
    description:
        'Rekonstruksi struktur objek dan tabel referensi PDF bermasalah menjadi dokumen baru yang bersih.',
    category: 'Optimalkan',
    icon: CupertinoIcons.wrench_fill,
    accentColor: AppTheme.emerald,
    inputKind: ToolInputKind.singlePdf,
    allowedExtensions: ['pdf'],
  ),

  // =========================================================================
  // 05. Konversi ke PDF (5 alat)
  // =========================================================================
  ToolItem(
    id: 'jpg_to_pdf',
    title: 'JPG / Foto ke PDF',
    shortTitle: 'Foto → PDF',
    description:
        'Ubah satu atau banyak gambar JPG/PNG/WebP menjadi PDF rapi dengan pengaturan kertas & margin.',
    category: 'Konversi ke PDF',
    icon: CupertinoIcons.photo_fill_on_rectangle_fill,
    accentColor: AppTheme.navy,
    inputKind: ToolInputKind.multiImage,
    allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'heic'],
    isFeatured: true,
  ),
  ToolItem(
    id: 'word_to_pdf',
    title: 'Word ke PDF',
    shortTitle: 'Word → PDF',
    description:
        'Konversi dokumen Word (.docx) atau file teks (.txt/.md) menjadi dokumen PDF berformat rapi.',
    category: 'Konversi ke PDF',
    icon: CupertinoIcons.doc_text_fill,
    accentColor: AppTheme.officeBlue,
    inputKind: ToolInputKind.officeDoc,
    allowedExtensions: ['docx', 'txt', 'md'],
  ),
  ToolItem(
    id: 'excel_to_pdf',
    title: 'Excel ke PDF',
    shortTitle: 'Excel → PDF',
    description:
        'Ubah lembar kerja Excel (.xlsx) atau CSV (.csv) menjadi tabel PDF lanskap yang mudah dibaca.',
    category: 'Konversi ke PDF',
    icon: CupertinoIcons.table_fill,
    accentColor: AppTheme.officeGreen,
    inputKind: ToolInputKind.officeDoc,
    allowedExtensions: ['xlsx', 'csv'],
  ),
  ToolItem(
    id: 'ppt_to_pdf',
    title: 'PowerPoint ke PDF',
    shortTitle: 'PPT → PDF',
    description:
        'Konversi slide presentasi PowerPoint (.pptx) menjadi halaman PDF lanskap yang konsisten.',
    category: 'Konversi ke PDF',
    icon: CupertinoIcons.tv_fill,
    accentColor: AppTheme.officeOrange,
    inputKind: ToolInputKind.officeDoc,
    allowedExtensions: ['pptx'],
  ),
  ToolItem(
    id: 'html_to_pdf',
    title: 'HTML ke PDF',
    shortTitle: 'HTML → PDF',
    description:
        'Ubah file HTML (.html/.htm) atau tempel kode HTML langsung menjadi dokumen PDF terstruktur.',
    category: 'Konversi ke PDF',
    icon: CupertinoIcons.chevron_left_slash_chevron_right,
    accentColor: AppTheme.navy,
    inputKind: ToolInputKind.htmlOrText,
    allowedExtensions: ['html', 'htm'],
  ),

  // =========================================================================
  // 06. Konversi dari PDF (4 alat)
  // =========================================================================
  ToolItem(
    id: 'pdf_to_jpg',
    title: 'PDF ke JPG / PNG',
    shortTitle: 'PDF → JPG',
    description:
        'Ekspor halaman PDF menjadi gambar JPG atau PNG resolusi tinggi (150–300 DPI) dengan galeri pratinjau.',
    category: 'Konversi dari PDF',
    icon: CupertinoIcons.photo_fill,
    accentColor: AppTheme.pdfRed,
    inputKind: ToolInputKind.singlePdf,
    allowedExtensions: ['pdf'],
    isFeatured: true,
  ),
  ToolItem(
    id: 'pdf_to_word',
    title: 'PDF ke Word (.docx)',
    shortTitle: 'PDF → Word',
    description:
        'Ekstrak teks dan struktur halaman PDF menjadi file Microsoft Word (.docx) asli yang siap disunting.',
    category: 'Konversi dari PDF',
    icon: CupertinoIcons.doc_plaintext,
    accentColor: AppTheme.officeBlue,
    inputKind: ToolInputKind.singlePdf,
    allowedExtensions: ['pdf'],
  ),
  ToolItem(
    id: 'pdf_to_excel',
    title: 'PDF ke Excel (.xlsx)',
    shortTitle: 'PDF → Excel',
    description:
        'Ekstrak baris data dan teks terstruktur dari PDF langsung ke file spreadsheet Excel (.xlsx) asli.',
    category: 'Konversi dari PDF',
    icon: CupertinoIcons.table,
    accentColor: AppTheme.officeGreen,
    inputKind: ToolInputKind.singlePdf,
    allowedExtensions: ['pdf'],
  ),
  ToolItem(
    id: 'pdf_to_ppt',
    title: 'PDF ke PowerPoint (.pptx)',
    shortTitle: 'PDF → PPT',
    description:
        'Ubah setiap halaman PDF menjadi slide visual HD dalam file PowerPoint (.pptx) siap presentasi.',
    category: 'Konversi dari PDF',
    icon: CupertinoIcons.rectangle_on_rectangle_angled,
    accentColor: AppTheme.officeOrange,
    inputKind: ToolInputKind.singlePdf,
    allowedExtensions: ['pdf'],
  ),

  // =========================================================================
  // 07. Edit, Tanda Tangan & Keamanan (10 alat)
  // =========================================================================
  ToolItem(
    id: 'pdf_page_number',
    title: 'Nomor Halaman',
    shortTitle: 'No. Halaman',
    description:
        'Tambahkan penomoran halaman otomatis dengan pilihan posisi, format teks, dan ukuran huruf.',
    category: 'Edit & Keamanan',
    icon: CupertinoIcons.number_square_fill,
    accentColor: AppTheme.navy,
    inputKind: ToolInputKind.singlePdf,
    allowedExtensions: ['pdf'],
  ),
  ToolItem(
    id: 'pdf_watermark',
    title: 'Watermark PDF',
    shortTitle: 'Watermark',
    description:
        'Sematkan tanda air teks pada setiap halaman PDF dengan pengaturan sudut, transparansi, dan warna.',
    category: 'Edit & Keamanan',
    icon: CupertinoIcons.drop_fill,
    accentColor: AppTheme.navy,
    inputKind: ToolInputKind.singlePdf,
    allowedExtensions: ['pdf'],
  ),
  ToolItem(
    id: 'pdf_crop',
    title: 'Potong Margin PDF',
    shortTitle: 'Crop Margin',
    description:
        'Pangkas ruang tepi atas, kanan, bawah, dan kiri halaman PDF secara presisi dalam milimeter.',
    category: 'Edit & Keamanan',
    icon: CupertinoIcons.crop_rotate,
    accentColor: AppTheme.navy,
    inputKind: ToolInputKind.singlePdf,
    allowedExtensions: ['pdf'],
  ),
  ToolItem(
    id: 'pdf_annotate',
    title: 'Edit & Anotasi PDF',
    shortTitle: 'Anotasi PDF',
    description:
        'Tambahkan catatan teks, kotak info, atau sorotan warna langsung di atas halaman PDF pilihan.',
    category: 'Edit & Keamanan',
    icon: CupertinoIcons.pencil_ellipsis_rectangle,
    accentColor: AppTheme.studioViolet,
    inputKind: ToolInputKind.singlePdf,
    allowedExtensions: ['pdf'],
  ),
  ToolItem(
    id: 'pdf_sign',
    title: 'Tanda Tangan PDF',
    shortTitle: 'Tanda Tangan',
    description:
        'Buat tanda tangan digital dengan goresan jari atau teks, lalu tempel langsung ke halaman PDF.',
    category: 'Edit & Keamanan',
    icon: CupertinoIcons.signature,
    accentColor: AppTheme.pdfRed,
    inputKind: ToolInputKind.singlePdf,
    allowedExtensions: ['pdf'],
    badge: 'Pro',
    isFeatured: true,
  ),
  ToolItem(
    id: 'pdf_redact',
    title: 'Sensor PDF (Redact)',
    shortTitle: 'Sensor PDF',
    description:
        'Tutup kata rahasia (NIK, email, alamat) otomatis atau blok area tertentu dengan hitam permanen.',
    category: 'Edit & Keamanan',
    icon: CupertinoIcons.eye_slash_fill,
    accentColor: AppTheme.navy,
    inputKind: ToolInputKind.singlePdf,
    allowedExtensions: ['pdf'],
  ),
  ToolItem(
    id: 'pdf_lock',
    title: 'Kunci PDF (Password)',
    shortTitle: 'Kunci PDF',
    description:
        'Enkripsi dokumen PDF dengan kata sandi AES 128-bit serta atur izin cetak dan penyalinan teks.',
    category: 'Edit & Keamanan',
    icon: CupertinoIcons.lock_fill,
    accentColor: AppTheme.pdfRed,
    inputKind: ToolInputKind.singlePdf,
    allowedExtensions: ['pdf'],
  ),
  ToolItem(
    id: 'pdf_unlock',
    title: 'Buka Kunci PDF',
    shortTitle: 'Buka PDF',
    description:
        'Hapus proteksi kata sandi dari dokumen PDF terenkripsi dengan memasukkan kata sandi yang benar.',
    category: 'Edit & Keamanan',
    icon: CupertinoIcons.lock_open_fill,
    accentColor: AppTheme.gold,
    inputKind: ToolInputKind.singlePdf,
    allowedExtensions: ['pdf'],
  ),
  ToolItem(
    id: 'pdf_metadata',
    title: 'Lindungi & Metadata',
    shortTitle: 'Metadata',
    description:
        'Sunting judul, penulis, subjek, tambahkan cap klasifikasi, atau bersihkan metadata pribadi PDF.',
    category: 'Edit & Keamanan',
    icon: CupertinoIcons.shield_lefthalf_fill,
    accentColor: AppTheme.studioViolet,
    inputKind: ToolInputKind.singlePdf,
    allowedExtensions: ['pdf'],
  ),
  ToolItem(
    id: 'pdf_compare',
    title: 'Bandingkan PDF',
    shortTitle: 'Bandingkan',
    description:
        'Bandingkan dua versi dokumen PDF untuk menemukan perubahan teks per halaman + ekspor laporan PDF.',
    category: 'Edit & Keamanan',
    icon: CupertinoIcons.doc_text_search,
    accentColor: AppTheme.navy,
    inputKind: ToolInputKind.twoPdfs,
    allowedExtensions: ['pdf'],
  ),
];

ToolItem findToolById(String id) =>
    kAllTools.firstWhere((t) => t.id == id, orElse: () => kAllTools.first);
