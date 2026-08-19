# Play Store AAB uretimi
if (-not (Test-Path .env)) {
  Write-Host ".env yok. .env.example dosyasini kopyalayip doldur."
  exit 1
}
if (-not (Test-Path android\key.properties)) {
  Write-Host "UYARI: android\key.properties yok - release DEBUG imzasi ile uretilebilir."
  Write-Host "android\key.properties.example dosyasina bak."
}
flutter build appbundle --dart-define-from-file=.env --release @args
