# === Config ===
$SdkRoot = "C:\Users\giuli\AppData\Local\Android\sdk"

# Metti i tool Android nel PATH per la sessione corrente
$env:PATH = "$SdkRoot\platform-tools;$SdkRoot\emulator;$SdkRoot\cmdline-tools\latest\bin;$env:PATH"

# Verifica emulator.exe
if (-not (Test-Path "$SdkRoot\emulator\emulator.exe")) {
    Write-Error "Emulatore non trovato in $SdkRoot\emulator. Installa 'Android Emulator' da Android Studio → SDK Manager → SDK Tools."
    exit 1
}

# Mostra la lista di AVD disponibili
$avdList = & "$SdkRoot\emulator\emulator.exe" -list-avds
if (-not $avdList) {
    Write-Error "Nessun emulatore trovato. Creane uno in Android Studio → Device Manager."
    exit 1
}

Write-Host "Emulatori disponibili:" -ForegroundColor Cyan
$avdList

# Usa il primo emulatore trovato (o cambia il nome se vuoi un AVD specifico)
$firstAvd = ($avdList | Select-Object -First 1).ToString().Trim()

Write-Host "Avvio emulatore: $firstAvd" -ForegroundColor Green
Start-Process -FilePath "$SdkRoot\emulator\emulator.exe" -ArgumentList "-avd `"$firstAvd`""
