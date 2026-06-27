<#
  compose_scene.ps1 — place TWO OR MORE figures from a normalized sheet onto one brand plate,
  for interaction scenes (a face-off, a handshake, a fight). Each figure is cropped, recolored
  to the brand color, trimmed, optionally mirrored, then laid out left-to-right on a shared
  baseline. Costs nothing (no Higgsfield call). Output is a start frame for generate_video.

  Usage:
    powershell -ExecutionPolicy Bypass -File compose_scene.ps1 -Norm "<normalized.png>" `
      -Boxes "x,y,w,h|x,y,w,h" -Out "<start.png>" [-Flip "0|1"] [-FigureColor "#1A2238"] `
      [-BgColor "#D4D9E0"] [-Aspect 16:9|9:16|1:1] [-HeightFrac 0.6] [-Scene "<scene.png>|none"]
#>
param(
  [Parameter(Mandatory=$true)][string]$Norm,
  [Parameter(Mandatory=$true)][string]$Boxes,
  [Parameter(Mandatory=$true)][string]$Out,
  [string]$Flip="",
  [string]$FigureColor="#1A2238",
  [string]$BgColor="#D4D9E0",
  [ValidateSet("16:9","9:16","1:1")][string]$Aspect="16:9",
  [double]$HeightFrac=0.60,
  [double]$BottomFrac=0.90,
  [string]$Scene="none"
)
$ErrorActionPreference="Stop"
Add-Type -AssemblyName System.Drawing
function Hex2RGB([string]$h){ $h=$h.TrimStart('#'); return @([Convert]::ToInt32($h.Substring(0,2),16),[Convert]::ToInt32($h.Substring(2,2),16),[Convert]::ToInt32($h.Substring(4,2),16)) }
$navy=Hex2RGB $FigureColor; $bg=Hex2RGB $BgColor
switch($Aspect){ "16:9"{$cw=1280;$ch=720} "9:16"{$cw=720;$ch=1280} "1:1"{$cw=1024;$ch=1024} }

$full=[System.Drawing.Image]::FromFile($Norm)
$boxList=$Boxes -split '\|'
$flipList=@(); if($Flip -ne ""){ $flipList=$Flip -split '\|' }

function Get-Figure($full,$bx,$by,$bw,$bh,$navy,$doFlip){
  $crop=New-Object System.Drawing.Bitmap($bw,$bh,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g=[System.Drawing.Graphics]::FromImage($crop)
  $g.DrawImage($full,(New-Object System.Drawing.Rectangle(0,0,$bw,$bh)),(New-Object System.Drawing.Rectangle($bx,$by,$bw,$bh)),[System.Drawing.GraphicsUnit]::Pixel)
  $g.Dispose()
  $rect=New-Object System.Drawing.Rectangle(0,0,$bw,$bh)
  $d=$crop.LockBits($rect,[System.Drawing.Imaging.ImageLockMode]::ReadWrite,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $len=$bw*$bh*4;$buf=New-Object byte[] $len;[System.Runtime.InteropServices.Marshal]::Copy($d.Scan0,$buf,0,$len)
  $minX=$bw;$minY=$bh;$maxX=0;$maxY=0
  for($y=0;$y -lt $bh;$y++){ for($x=0;$x -lt $bw;$x++){ $i=($y*$bw+$x)*4; if($buf[$i+3] -gt 16){ $buf[$i]=$navy[2];$buf[$i+1]=$navy[1];$buf[$i+2]=$navy[0]; if($x -lt $minX){$minX=$x};if($x -gt $maxX){$maxX=$x};if($y -lt $minY){$minY=$y};if($y -gt $maxY){$maxY=$y} } } }
  [System.Runtime.InteropServices.Marshal]::Copy($buf,0,$d.Scan0,$len);$crop.UnlockBits($d)
  $pad=6;$tx=[Math]::Max(0,$minX-$pad);$ty=[Math]::Max(0,$minY-$pad);$tw=[Math]::Min($bw-$tx,($maxX-$minX)+2*$pad);$th=[Math]::Min($bh-$ty,($maxY-$minY)+2*$pad)
  $fig=New-Object System.Drawing.Bitmap($tw,$th,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $gf=[System.Drawing.Graphics]::FromImage($fig)
  $gf.DrawImage($crop,(New-Object System.Drawing.Rectangle(0,0,$tw,$th)),(New-Object System.Drawing.Rectangle($tx,$ty,$tw,$th)),[System.Drawing.GraphicsUnit]::Pixel)
  $gf.Dispose();$crop.Dispose()
  if($doFlip){ $fig.RotateFlip([System.Drawing.RotateFlipType]::RotateNoneFlipX) }
  return $fig
}

$canvas=New-Object System.Drawing.Bitmap($cw,$ch,[System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$gc=[System.Drawing.Graphics]::FromImage($canvas)
$gc.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
if($Scene -ne "none" -and (Test-Path $Scene)){
  $sc=[System.Drawing.Image]::FromFile($Scene)
  $s=[Math]::Max($cw/$sc.Width,$ch/$sc.Height);$sw2=[int]($sc.Width*$s);$sh2=[int]($sc.Height*$s)
  $gc.DrawImage($sc,(New-Object System.Drawing.Rectangle([int](($cw-$sw2)/2),[int](($ch-$sh2)/2),$sw2,$sh2)));$sc.Dispose()
}else{ $gc.Clear([System.Drawing.Color]::FromArgb($bg[0],$bg[1],$bg[2])) }

$N=$boxList.Count
$targetH=[int]($ch*$HeightFrac)
$baseY=[int]($ch*$BottomFrac)
$slotW=$cw/$N
for($k=0;$k -lt $N;$k++){
  $p=$boxList[$k] -split ','
  $doFlip = ($flipList.Count -gt $k -and $flipList[$k] -eq "1")
  $fig=Get-Figure $full ([int]$p[0]) ([int]$p[1]) ([int]$p[2]) ([int]$p[3]) $navy $doFlip
  $scl=$targetH/$fig.Height;$dw2=[int]($fig.Width*$scl);$dh2=$targetH
  $cx=[int](($k+0.5)*$slotW)
  $dx=[int]($cx-$dw2/2);$dy=$baseY-$dh2
  $gc.DrawImage($fig,(New-Object System.Drawing.Rectangle($dx,$dy,$dw2,$dh2)));$fig.Dispose()
}
$gc.Dispose();$full.Dispose()
$dir=Split-Path $Out -Parent; if($dir -and -not (Test-Path $dir)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
$canvas.Save($Out,[System.Drawing.Imaging.ImageFormat]::Png);$canvas.Dispose()
Write-Output ("scene -> $Out  ({0}x{1}, {2} figures)" -f $cw,$ch,$N)
