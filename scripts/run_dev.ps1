# Geliştirme: anahtarları APK asset'i yapmadan yükler
if (-not (Test-Path .env)) {
  Write-Host ".env yok. .env.example dosyasini kopyalayip doldur."
  exit 1
}
flutter run --dart-define-from-file=.env @args
