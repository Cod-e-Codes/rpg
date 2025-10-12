$ErrorActionPreference = 'Stop'

$love = 'C:\Program Files\LOVE\love.exe'
if (!(Test-Path $love)) {
  Write-Error "LOVE executable not found at: $love"
}

${gameDir} = $PSScriptRoot
Start-Process -FilePath $love -ArgumentList @("${gameDir}") -WorkingDirectory ${gameDir} -Wait


