# actualizar-android.ps1
#
# Sube Gradle a 8.14.3, AGP a 8.11.1 y Kotlin a 2.2.20, y quita las dependencias
# local_auth y android_intent_plus (no se usan en lib/).
#
# Guardalo en la RAIZ del proyecto y ejecutalo desde CMD:
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\actualizar-android.ps1

$ErrorActionPreference = 'Stop'
$raiz   = $PSScriptRoot
$utf8   = New-Object System.Text.UTF8Encoding $false   # UTF-8 sin BOM
$fallos = 0
Set-Location $raiz

function Reemplazar([string]$ruta, [string]$patron, [string]$nuevo, [string]$que) {
    $archivo = Join-Path $raiz $ruta
    if (-not (Test-Path $archivo)) {
        Write-Host "  [FALTA EL ARCHIVO] $ruta   ($que)" -ForegroundColor Red
        $script:fallos++
        return
    }
    $texto = [IO.File]::ReadAllText($archivo)
    if (-not [regex]::IsMatch($texto, $patron)) {
        Write-Host "  [NO ENCONTRADO] $que   en $ruta (quizas ya estaba actualizado)" -ForegroundColor Yellow
        $script:fallos++
        return
    }
    $texto = [regex]::Replace($texto, $patron, $nuevo)
    [IO.File]::WriteAllText($archivo, $texto, $utf8)
    Write-Host "  [OK] $que" -ForegroundColor Green
}

Write-Host ""
Write-Host "Actualizando Gradle / AGP / Kotlin..."
Reemplazar 'android\gradle\wrapper\gradle-wrapper.properties' 'gradle-8\.11\.1-' 'gradle-8.14.3-' 'Gradle 8.11.1 -> 8.14.3'
Reemplazar 'android\settings.gradle' '(com\.android\.application"\s+version\s+")8\.9\.1"' '${1}8.11.1"' 'AGP 8.9.1 -> 8.11.1'
Reemplazar 'android\settings.gradle' '(org\.jetbrains\.kotlin\.android"\s+version\s+")2\.1\.0"' '${1}2.2.20"' 'Kotlin 2.1.0 -> 2.2.20'

Write-Host "Quitando dependencias sin uso..."
Reemplazar 'pubspec.yaml' '(?m)^[ \t]*android_intent_plus:.*\r?\n' '' 'android_intent_plus'
Reemplazar 'pubspec.yaml' '(?m)^[ \t]*local_auth:.*\r?\n' '' 'local_auth'

Write-Host ""
if ($fallos -gt 0) {
    Write-Host "$fallos cambio(s) NO se aplicaron. Copia los avisos de arriba y mandamelos." -ForegroundColor Yellow
} else {
    Write-Host "Listo. Cambios aplicados:" -ForegroundColor Green
}
Write-Host ""
git --no-pager diff -U0 -- android pubspec.yaml
Write-Host ""
if ($fallos -eq 0) {
    Write-Host "Siguiente:  flutter pub get   y luego   flutter build apk" -ForegroundColor Green
}
