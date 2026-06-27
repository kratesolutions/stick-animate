<#
  chroma_key.ps1 — remove the green-screen background, leaving the figure ONLY on a transparent
  background. Output is a ProRes 4444 .mov with alpha (reliable everywhere; VP9/WebM alpha is flaky
  in many ffmpeg builds). Keep the source green-screen MP4 too (small, universal) so the client can
  also key it in their own editor.

  HOW (robust to AI green screens, which are NOT flat -- they have a clouded/two-tone gradient):
  we do NOT match an exact green. Instead we key by GREEN DOMINANCE: a pixel becomes transparent in
  proportion to how much its green channel exceeds BOTH red and blue. This ignores the green's exact
  shade entirely, and it protects the art for free -- navy is blue-dominant and warm accents
  (red/gold/yellow) are red-dominant, so only the green background is removed. No color sampling,
  no per-clip tuning, no despill, and gold/yellow accents survive (unlike a colorkey + despill).

  Usage:
    powershell -ExecutionPolicy Bypass -File chroma_key.ps1 -Video "<greenscreen.mp4>" -Out "<figure.mov>" `
      [-Strength 10]
  -Strength: higher = tighter/harder edge (more aggressive green removal); lower = softer edge. 8-14 is the useful range.
#>
param(
  [Parameter(Mandatory=$true)][string]$Video,
  [Parameter(Mandatory=$true)][string]$Out,
  [double]$Strength=10
)
$ErrorActionPreference="Stop"
$ci=[Globalization.CultureInfo]::InvariantCulture
$dir=Split-Path $Out -Parent; if($dir -and -not(Test-Path $dir)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
$s=$Strength.ToString($ci)
# alpha = clip(255 - (how much green beats the larger of red/blue) * Strength)
$vf="format=rgba,geq=r='r(X,Y)':g='g(X,Y)':b='b(X,Y)':a='clip(255-(min(g(X,Y)-r(X,Y)\,g(X,Y)-b(X,Y)))*${s}\,0\,255)',format=yuva444p10le"
& ffmpeg -loglevel error -y -i $Video -vf $vf -c:v prores_ks -profile:v 4444 -pix_fmt yuva444p10le -an $Out
Write-Output ("keyed -> $Out  (transparent ProRes 4444 MOV; green-dominance key, strength=$s)")
