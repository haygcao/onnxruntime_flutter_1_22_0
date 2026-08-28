param (
    [string]$TargetVersion = ""
)

$ErrorActionPreference = "Stop"

Write-Host "=========================================="
Write-Host "🤖 ONNX Runtime Auto-Upgrade & Sync Tool"
Write-Host "=========================================="

# 1. 获取最新 Release 版本
if ($TargetVersion -ne "") {
    $tag = if ($TargetVersion.StartsWith("v")) { $TargetVersion } else { "v$TargetVersion" }
    $apiUrl = "https://api.github.com/repos/microsoft/onnxruntime/releases/tags/$tag"
} else {
    $apiUrl = "https://api.github.com/repos/microsoft/onnxruntime/releases/latest"
}

Write-Host "🔍 Querying Microsoft GitHub Releases: $apiUrl..."
$response = Invoke-RestMethod -Uri $apiUrl -Headers @{ "User-Agent" = "PowerShell-AutoSync" }
$versionTag = $response.tag_name
$cleanVersion = $versionTag.TrimStart('v')

Write-Host "🎯 Target Version: $cleanVersion ($versionTag)"

# 2. 下载并更新 Windows DLL
$zipUrl = "https://github.com/microsoft/onnxruntime/releases/download/v$cleanVersion/onnxruntime-win-x64-$cleanVersion.zip"
Write-Host "📥 Downloading Windows x64 binaries: $zipUrl..."

$tempDir = Join-Path $env:TEMP "ort_sync_$cleanVersion"
$zipFile = "$tempDir.zip"

if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
Invoke-WebRequest -Uri $zipUrl -OutFile $zipFile
Expand-Archive -Path $zipFile -DestinationPath $tempDir -Force

$extractedFolder = Get-ChildItem -Path $tempDir -Directory | Select-Object -First 1
$dllSource = Join-Path $extractedFolder.FullName "lib\onnxruntime.dll"
$headerSource = Join-Path $extractedFolder.FullName "include\onnxruntime_c_api.h"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent $scriptDir

# 覆盖 windows 动态库
Copy-Item $dllSource "$rootDir\windows\onnxruntime.dll" -Force
Write-Host "✅ Updated $rootDir\windows\onnxruntime.dll"

# 覆盖 C API 头文件
if (Test-Path $headerSource) {
    Copy-Item $headerSource "$rootDir\src\onnxruntime\onnxruntime_c_api.h" -Force
    Write-Host "✅ Updated $rootDir\src\onnxruntime\onnxruntime_c_api.h"
}

# 3. 运行 ffigen 自动重新生成 Dart 绑定
Write-Host "⚙️ Regenerating Dart FFI bindings via ffigen..."
Push-Location $rootDir
try {
    flutter pub get
    dart run ffigen --config ffigen_onnxruntime.yaml
    Write-Host "✅ FFI bindings successfully regenerated!"
} finally {
    Pop-Location
}

# 4. 清理临时下载文件
Remove-Item $zipFile -Force -ErrorAction SilentlyContinue
Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "🎉 ONNX Runtime upgraded to $cleanVersion successfully!"
