<#
  caption.ps1 — burn a branded caption bar onto a clip (navy bar + white bold text).
  Optional polish step; the client can also caption in their own editor.
  Uses ffmpeg drawtext with `textfile=` (robust against commas/colons/apostrophes in the text).

  Usage:
    powershell -ExecutionPolicy Bypass -File caption.ps1 -Video "<in.mp4>" -Out "<out.mp4>" `
      -Text "When you finally let go." [-Position bottom|top] [-BoxColor 0x1A2238] [-BoxOpacity 0.85] [-FontColor white]
#>
param(
  [Parameter(Mandatory=$true)][string]$Video,
  [Parameter(Mandatory=$true)][string]$Out,
  [Parameter(Mandatory=$true)][string]$Text,
  [ValidateSet("bottom","top")][string]$Position="bottom",
  [string]$BoxColor="0x1A2238",
  [double]$BoxOpacity=0.85,
  [string]$FontColor="white",
  [string]$FontFile="C:\Windows\Fonts\arialbd.ttf"
)
$ErrorActionPreference="Stop"
# Encode a Windows path for an ffmpeg filtergraph: forward slashes, and the drive colon
# double-escaped (\\: survives the outer filtergraph pass to arrive as \: for the filter args).
function FilterPath([string]$p){ return (($p -replace '\\','/') -replace ':','\\:') }

$dir=Split-Path $Out -Parent; if($dir -and -not(Test-Path $dir)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
$capFile = Join-Path $dir ("_caption_" + [guid]::NewGuid().ToString('N') + ".txt")
[System.IO.File]::WriteAllText($capFile, $Text, (New-Object System.Text.UTF8Encoding($false)))

$font = FilterPath $FontFile
$tf   = FilterPath $capFile
$opacity = $BoxOpacity.ToString([Globalization.CultureInfo]::InvariantCulture)
$ypos = if($Position -eq "top"){ "(h*0.05)" } else { "h-th-(h*0.05)" }
$vf = "drawtext=fontfile=${font}:textfile=${tf}:fontcolor=${FontColor}:fontsize=h/20:x=(w-tw)/2:y=${ypos}:box=1:boxcolor=${BoxColor}@${opacity}:boxborderw=22"

try {
  & ffmpeg -loglevel error -y -i $Video -vf $vf -c:v libx264 -pix_fmt yuv420p -an $Out
} finally {
  Remove-Item $capFile -Force -ErrorAction SilentlyContinue
}
Write-Output ("captioned -> $Out")
