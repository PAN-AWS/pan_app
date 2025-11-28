# === Config percorsi ===
$ProjectRoot = "D:\dev\pan_app"
$SdkRoot     = "C:\Users\giuli\AppData\Local\Android\sdk"
$JbrHome     = "C:\Program Files\Android\Android Studio1\jbr"  # JDK 21 di Android Studio

# === Env per la sessione ===
$env:JAVA_HOME = $JbrHome
$env:ANDROID_SDK_ROOT = $SdkRoot
$env:PATH = "$SdkRoot\platform-tools;$SdkRoot\emulator;$SdkRoot\cmdline-tools\latest\bin;$env:PATH"

Write-Host "JAVA_HOME        = $env:JAVA_HOME"
Write-Host "ANDROID_SDK_ROOT = $env:ANDROID_SDK_ROOT"

# Verifica sdkmanager/cmdline-tools
if (-not (Test-Path "$SdkRoot\cmdline-tools\latest\bin\sdkmanager.exe")) {
  Write-Warning "Command-line tools (latest) mancanti. Apri Android Studio → SDK Manager → SDK Tools e installali."
}

# Verifica ADB
$adb = "$SdkRoot\platform-tools\adb.exe"
if (-not (Test-Path $adb)) {
  Write-Error "adb non trovato in $adb. Verifica l'installazione di Android SDK Platform-Tools."
  exit 1
}

# Avvia AVD se nessun device è connesso
$devices = & $adb devices | Select-String "device$"
if (-not $devices) {
  $avdList = & "$SdkRoot\emulator\emulator.exe" -list-avds
  if (-not $avdList) {
    Write-Error "Nessun AVD trovato. Crea un dispositivo da Android Studio → Device Manager."
    exit 1
  }
  $firstAvd = ($avdList | Select-Object -First 1).ToString().Trim()
  Write-Host "Avvio emulatore: $firstAvd"
  Start-Process -FilePath "$SdkRoot\emulator\emulator.exe" -ArgumentList "-avd `"$firstAvd`""

  Write-Host "Attendo che il device diventi disponibile..."
  & $adb wait-for-device

  $booted = "0"
  for ($i=0; $i -lt 120 -and $booted -ne "1"; $i++) {
    Start-Sleep -Seconds 2
    $booted = (& $adb shell getprop sys.boot_completed 2>$null).Trim()
  }
  if ($booted -ne "1") {
    Write-Warning "Il boot potrebbe non essere completo, continuo..."
  }
} else {
  Write-Host "Device/emulatore già attivo."
}

# Build & run Flutter
Set-Location $ProjectRoot

# Forza Flutter a usare il JDK 21 (evita JDK 23)
flutter config --jdk-dir="$JbrHome" | Out-Null

flutter clean
flutter pub get
flutter devices

# Se incontri warning di dependency validation, puoi usare:
# flutter run --android-skip-build-dependency-validation
flutter run
