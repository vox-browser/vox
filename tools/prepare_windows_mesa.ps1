# Native CI bootstrap for the same dependency manifest as the V build helper.
param([string]$Destination = "$PSScriptRoot/../Build/deps/windows/mesa")
$ErrorActionPreference = 'Stop'
$config = Get-Content "$PSScriptRoot/windows_mesa.json" -Raw | ConvertFrom-Json
New-Item -ItemType Directory -Force $Destination | Out-Null
foreach ($kind in @('devel-mingw', 'release-mingw')) {
    $name = "mesa3d-$($config.version)-$kind.7z"
    $archive = Join-Path $Destination $name
    if (!(Test-Path $archive)) {
        Invoke-WebRequest "https://github.com/pal1000/mesa-dist-win/releases/download/$($config.version)/$name" -OutFile $archive
    }
    if ((Get-FileHash $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $config.$kind) {
        throw "Mesa archive checksum mismatch: $name"
    }
    & 7z x -y "-o$Destination/$kind" $archive | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Mesa extraction failed: $name" }
}
foreach ($dll in @('libEGL.dll', 'libGLESv2.dll', 'libgallium_wgl.dll', 'opengl32.dll')) {
    if (!(Test-Path "$Destination/release-mingw/x64/$dll")) {
        throw "Mesa runtime is missing $dll"
    }
}
