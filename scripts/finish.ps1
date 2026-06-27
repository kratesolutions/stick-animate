<#
  finish.ps1 — download (if a URL) and export a generated clip to the requested aspect
  ratios, padding to aspect with the brand background color so the figure is never cropped.
  Optional logo bug and exact-length trim.

  Usage:
    powershell -ExecutionPolicy Bypass -File finish.ps1 -Video "<url-or-local.mp4>" `
      -Out "<outdir>" -Slug "angel-float" [-Aspects "16:9,9:16,1:1"] [-BgColor "#D4D9E0"] `
      [-Logo "<logo.png>|none"] [-LogoCorner bottom-right] [-TrimSec 0]
#>
param(
  [Parameter(Mandatory=$true)][string]$Video,
  [Parameter(Mandatory=$true)][string]$Out,
  [Parameter(Mandatory=$true)][string]$Slug,
  [string]$Aspects="16:9,9:16,1:1",
  [string]$BgColor="#D4D9E0",
  [string]$Logo="none",
  [string]$LogoCorner="bottom-right",
  [double]$TrimSec=0
)
$ErrorActionPreference="Stop"
Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force -Path $Out | Out-Null
$srcMp4 = Join-Path $Out ("_src_" + $Slug + ".mp4")
if($Video -match '^https?://'){ Invoke-WebRequest -Uri $Video -OutFile $srcMp4 -UseBasicParsing } else { Copy-Item $Video $srcMp4 -Force }
# Seamless padding: sample the clip's own top-center background colour (falls back to BgColor)
$hex = "0x" + ($BgColor.TrimStart('#').ToUpper())
try {
  $probe = Join-Path $Out ("_probe_" + $Slug + ".png")
  & ffmpeg -loglevel error -ss 0.1 -i $srcMp4 -frames:v 1 -y $probe | Out-Null
  $pim=[System.Drawing.Image]::FromFile($probe); $pc=$pim.GetPixel([int]($pim.Width/2),2); $pim.Dispose(); Remove-Item $probe -Force
  $hex = ('0x{0:X2}{1:X2}{2:X2}' -f $pc.R,$pc.G,$pc.B)
} catch { }

$dims=@{ "16:9"=@(1280,720); "9:16"=@(720,1280); "1:1"=@(1024,1024) }
$trimArg=@(); if($TrimSec -gt 0){ $trimArg=@("-t","$TrimSec") }
$m=0.04
$pos=@{
  "bottom-right"="x=W-w-($m*W):y=H-h-($m*H)"; "bottom-left"="x=($m*W):y=H-h-($m*H)";
  "top-right"="x=W-w-($m*W):y=($m*H)"; "top-left"="x=($m*W):y=($m*H)"
}
$results=@()
foreach($a in ($Aspects -split ',')){
  $a=$a.Trim(); if(-not $dims.ContainsKey($a)){ continue }
  $W=$dims[$a][0];$H=$dims[$a][1]
  $outFile=Join-Path $Out ($Slug + "_" + ($a -replace ':','x') + ".mp4")
  $vf="scale=${W}:${H}:force_original_aspect_ratio=decrease,pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2:color=$hex,setsar=1"
  if($Logo -ne "none" -and (Test-Path $Logo)){
    $lw=[int]($W*0.14); $p=$pos[$LogoCorner]; if(-not $p){$p=$pos["bottom-right"]}
    $fc="[0:v]$vf[v];[1:v]scale=${lw}:-1[lg];[v][lg]overlay=$p"
    & ffmpeg -loglevel error -y -i $srcMp4 -i $Logo @trimArg -filter_complex $fc -c:v libx264 -pix_fmt yuv420p -an $outFile
  } else {
    & ffmpeg -loglevel error -y -i $srcMp4 @trimArg -vf $vf -c:v libx264 -pix_fmt yuv420p -an $outFile
  }
  $results+=$outFile
}
Remove-Item $srcMp4 -Force -ErrorAction SilentlyContinue
foreach($r in $results){ Write-Output ("exported -> $r") }
