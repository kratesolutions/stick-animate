<#
  prep_plate.ps1 — build a branded start frame from ONE figure on a normalized sheet.
  Crops the figure box, recolors it to the brand color (soft edges preserved via alpha),
  trims to the figure, then centers it on the brand backdrop (or a scene image) at the
  chosen aspect ratio. Costs nothing (no Higgsfield call).

  Usage:
    powershell -ExecutionPolicy Bypass -File prep_plate.ps1 -Norm "<normalized.png>" `
      -Bbox "x,y,w,h" -Out "<start.png>" [-FigureColor "#1A2238"] [-BgColor "#D4D9E0"] `
      [-Aspect 16:9|9:16|1:1] [-Scene "<scene.png>|none"] [-HeightFrac 0.78]
#>
param(
  [Parameter(Mandatory=$true)][string]$Norm,
  [Parameter(Mandatory=$true)][string]$Bbox,
  [Parameter(Mandatory=$true)][string]$Out,
  [string]$FigureColor="#1A2238",
  [string]$BgColor="#D4D9E0",
  [ValidateSet("16:9","9:16","1:1")][string]$Aspect="16:9",
  [string]$Scene="none",
  [double]$HeightFrac=0.78
)
$ErrorActionPreference="Stop"
Add-Type -AssemblyName System.Drawing
function Hex2RGB([string]$h){ $h=$h.TrimStart('#'); return @([Convert]::ToInt32($h.Substring(0,2),16),[Convert]::ToInt32($h.Substring(2,2),16),[Convert]::ToInt32($h.Substring(4,2),16)) }
$navy=Hex2RGB $FigureColor; $bg=Hex2RGB $BgColor
$bb=$Bbox -split ','; $bx=[int]$bb[0];$by=[int]$bb[1];$bw=[int]$bb[2];$bh=[int]$bb[3]
switch($Aspect){ "16:9"{$cw=1280;$ch=720} "9:16"{$cw=720;$ch=1280} "1:1"{$cw=1024;$ch=1024} }

$src=[System.Drawing.Image]::FromFile($Norm)
$crop=New-Object System.Drawing.Bitmap($bw,$bh,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g=[System.Drawing.Graphics]::FromImage($crop)
$g.DrawImage($src,(New-Object System.Drawing.Rectangle(0,0,$bw,$bh)),(New-Object System.Drawing.Rectangle($bx,$by,$bw,$bh)),[System.Drawing.GraphicsUnit]::Pixel)
$g.Dispose();$src.Dispose()

# recolor to brand (keep alpha) + find tight alpha bbox
$rect=New-Object System.Drawing.Rectangle(0,0,$bw,$bh)
$data=$crop.LockBits($rect,[System.Drawing.Imaging.ImageLockMode]::ReadWrite,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$len=$bw*$bh*4;$buf=New-Object byte[] $len;[System.Runtime.InteropServices.Marshal]::Copy($data.Scan0,$buf,0,$len)
$minX=$bw;$minY=$bh;$maxX=0;$maxY=0
for($y=0;$y -lt $bh;$y++){ for($x=0;$x -lt $bw;$x++){ $i=($y*$bw+$x)*4; if($buf[$i+3] -gt 16){ $buf[$i]=$navy[2];$buf[$i+1]=$navy[1];$buf[$i+2]=$navy[0]; if($x -lt $minX){$minX=$x};if($x -gt $maxX){$maxX=$x};if($y -lt $minY){$minY=$y};if($y -gt $maxY){$maxY=$y} } } }
[System.Runtime.InteropServices.Marshal]::Copy($buf,0,$data.Scan0,$len);$crop.UnlockBits($data)
if($maxX -lt $minX){ throw "No opaque pixels in bbox; check the figure box." }

$pad=8;$tx=[Math]::Max(0,$minX-$pad);$ty=[Math]::Max(0,$minY-$pad)
$tw=[Math]::Min($bw-$tx,($maxX-$minX)+2*$pad);$th=[Math]::Min($bh-$ty,($maxY-$minY)+2*$pad)
$fig=New-Object System.Drawing.Bitmap($tw,$th,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$gf=[System.Drawing.Graphics]::FromImage($fig)
$gf.DrawImage($crop,(New-Object System.Drawing.Rectangle(0,0,$tw,$th)),(New-Object System.Drawing.Rectangle($tx,$ty,$tw,$th)),[System.Drawing.GraphicsUnit]::Pixel)
$gf.Dispose();$crop.Dispose()

$canvas=New-Object System.Drawing.Bitmap($cw,$ch,[System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$gc=[System.Drawing.Graphics]::FromImage($canvas)
$gc.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
if($Scene -ne "none" -and (Test-Path $Scene)){
  $sc=[System.Drawing.Image]::FromFile($Scene)
  $s=[Math]::Max($cw/$sc.Width,$ch/$sc.Height);$sw2=[int]($sc.Width*$s);$sh2=[int]($sc.Height*$s)
  $gc.DrawImage($sc,(New-Object System.Drawing.Rectangle([int](($cw-$sw2)/2),[int](($ch-$sh2)/2),$sw2,$sh2)));$sc.Dispose()
}else{
  $gc.Clear([System.Drawing.Color]::FromArgb($bg[0],$bg[1],$bg[2]))
}
$targetH=[int]($ch*$HeightFrac);$scl=$targetH/$th;$dw2=[int]($tw*$scl);$dh2=$targetH
$dx=[int](($cw-$dw2)/2);$dy=[int](($ch-$dh2)/2)
$gc.DrawImage($fig,(New-Object System.Drawing.Rectangle($dx,$dy,$dw2,$dh2)));$fig.Dispose();$gc.Dispose()
$dir=Split-Path $Out -Parent; if($dir -and -not (Test-Path $dir)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
$canvas.Save($Out,[System.Drawing.Imaging.ImageFormat]::Png);$canvas.Dispose()
Write-Output ("start frame -> $Out  ({0}x{1}, figure {2}x{3})" -f $cw,$ch,$dw2,$dh2)
