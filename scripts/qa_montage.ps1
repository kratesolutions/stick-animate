<#
  qa_montage.ps1 — extract evenly spaced frames from a clip into one labeled QA sheet.
  Usage: powershell -ExecutionPolicy Bypass -File qa_montage.ps1 -Video "<clip.mp4>" -Out "<qa.png>" [-Frames 4]
#>
param([Parameter(Mandatory=$true)][string]$Video,[Parameter(Mandatory=$true)][string]$Out,[int]$Frames=4)
$ErrorActionPreference="Stop"
Add-Type -AssemblyName System.Drawing
$ci=[Globalization.CultureInfo]::InvariantCulture
$tmp=[System.IO.Path]::GetTempPath()
$dur=[double](& ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $Video)
$paths=@()
for($i=0;$i -lt $Frames;$i++){
  if($Frames -eq 1){ $pct=0.5 } else { $pct=0.08 + ($i/($Frames-1))*0.84 }
  $ts=($dur*$pct).ToString("0.000",$ci)
  $fp=Join-Path $tmp ("qa_" + [guid]::NewGuid().ToString('N') + "_$i.png")
  & ffmpeg -loglevel error -ss $ts -i $Video -frames:v 1 -y $fp | Out-Null
  $paths+=$fp
}
$first=[System.Drawing.Image]::FromFile($paths[0]);$fw=$first.Width;$fh=$first.Height;$first.Dispose()
$tw=360;$th=[int]($tw*$fh/$fw)
$cnv=New-Object System.Drawing.Bitmap(($tw*$Frames),$th,[System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$g=[System.Drawing.Graphics]::FromImage($cnv);$g.Clear([System.Drawing.Color]::White);$g.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
for($i=0;$i -lt $Frames;$i++){ $im=[System.Drawing.Image]::FromFile($paths[$i]);$g.DrawImage($im,(New-Object System.Drawing.Rectangle(($i*$tw),0,$tw,$th)));$im.Dispose();Remove-Item $paths[$i] -Force -ErrorAction SilentlyContinue }
$g.Dispose()
$dir=Split-Path $Out -Parent;if($dir -and -not(Test-Path $dir)){New-Item -ItemType Directory -Force -Path $dir|Out-Null}
$cnv.Save($Out,[System.Drawing.Imaging.ImageFormat]::Png);$cnv.Dispose()
Write-Output ("qa montage -> $Out ({0} frames, dur {1:N2}s)" -f $Frames,$dur)
