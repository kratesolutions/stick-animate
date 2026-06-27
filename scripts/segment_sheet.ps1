<#
  segment_sheet.ps1 — find each separate figure on a stick-figure sheet.
  Handles transparent-background sheets AND solid-background sheets (knocks the
  background out first). Writes:
    <Out>\normalized.png   transparent, figures opaque (used by prep_plate.ps1)
    <Out>\figures.json     [{index,x,y,w,h}, ...] in source-pixel coords
    <Out>\figures_grid.png numbered preview (navy figures on the brand grey) to pick from

  Usage:
    powershell -ExecutionPolicy Bypass -File segment_sheet.ps1 -Sheet "<sheet.png>" -Out "<workdir>"
#>
param(
  [Parameter(Mandatory=$true)][string]$Sheet,
  [Parameter(Mandatory=$true)][string]$Out,
  [double]$MinAreaFrac = 0.0022,
  [double]$MergeGapFrac = 0.020,
  [int]$Target = 500,
  [string]$FigureColor = "#1A2238",
  [string]$BgColor = "#D4D9E0"
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

function Hex2RGB([string]$h){ $h=$h.TrimStart('#'); return @([Convert]::ToInt32($h.Substring(0,2),16),[Convert]::ToInt32($h.Substring(2,2),16),[Convert]::ToInt32($h.Substring(4,2),16)) }
New-Item -ItemType Directory -Force -Path $Out | Out-Null
$navy = Hex2RGB $FigureColor
$bg   = Hex2RGB $BgColor

# ---- Load source into a clean 32bppArgb bitmap ----
$orig = [System.Drawing.Image]::FromFile($Sheet)
$W=$orig.Width; $H=$orig.Height
$full = New-Object System.Drawing.Bitmap($W,$H,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g=[System.Drawing.Graphics]::FromImage($full); $g.DrawImage($orig,0,0,$W,$H); $g.Dispose(); $orig.Dispose()

# ---- Detect transparent vs solid background (small alpha sample) ----
$ds=200
$sb=New-Object System.Drawing.Bitmap($ds,$ds,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$gs=[System.Drawing.Graphics]::FromImage($sb); $gs.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$gs.DrawImage($full,0,0,$ds,$ds); $gs.Dispose()
$sd=$sb.LockBits((New-Object System.Drawing.Rectangle(0,0,$ds,$ds)),[System.Drawing.Imaging.ImageLockMode]::ReadOnly,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$sbuf=New-Object byte[] ($ds*$ds*4); [System.Runtime.InteropServices.Marshal]::Copy($sd.Scan0,$sbuf,0,$sbuf.Length); $sb.UnlockBits($sd); $sb.Dispose()
$trans=0; for($i=0;$i -lt $ds*$ds;$i++){ if($sbuf[$i*4+3] -lt 16){$trans++} }
$transFrac=$trans/($ds*$ds)

# ---- Normalize to transparent ----
$normPath = Join-Path $Out "normalized.png"
if($transFrac -gt 0.03){
  $full.Save($normPath,[System.Drawing.Imaging.ImageFormat]::Png)
} else {
  $c=$full.GetPixel(2,2)
  $hex=('0x{0:X2}{1:X2}{2:X2}' -f $c.R,$c.G,$c.B)
  $tmp=Join-Path $Out "_src.png"; $full.Save($tmp,[System.Drawing.Imaging.ImageFormat]::Png)
  & ffmpeg -loglevel error -y -i $tmp -vf ("colorkey=" + $hex + ":0.12:0.04") $normPath | Out-Null
  Remove-Item $tmp -Force
  $full.Dispose()
  $t2=[System.Drawing.Image]::FromFile($normPath)
  $full=New-Object System.Drawing.Bitmap($W,$H,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g2=[System.Drawing.Graphics]::FromImage($full); $g2.DrawImage($t2,0,0,$W,$H); $g2.Dispose(); $t2.Dispose()
}

# ---- Downscale alpha to a working mask ----
$scale=$Target/[Math]::Max($W,$H)
$dw=[int]($W*$scale); $dh=[int]($H*$scale)
$db=New-Object System.Drawing.Bitmap($dw,$dh,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$gd=[System.Drawing.Graphics]::FromImage($db); $gd.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$gd.DrawImage($full,0,0,$dw,$dh); $gd.Dispose()
$dd=$db.LockBits((New-Object System.Drawing.Rectangle(0,0,$dw,$dh)),[System.Drawing.Imaging.ImageLockMode]::ReadOnly,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$dbuf=New-Object byte[] ($dw*$dh*4); [System.Runtime.InteropServices.Marshal]::Copy($dd.Scan0,$dbuf,0,$dbuf.Length); $db.UnlockBits($dd); $db.Dispose()
$n=$dw*$dh
$mask=New-Object byte[] $n
for($p=0;$p -lt $n;$p++){ if($dbuf[$p*4+3] -gt 24){$mask[$p]=1} }

# ---- Connected components (8-connectivity, iterative flood fill) ----
$labels=New-Object int[] $n
$boxes=New-Object System.Collections.Generic.List[object]
$st=New-Object System.Collections.Generic.Stack[int]
$cur=0
for($p=0;$p -lt $n;$p++){
  if($mask[$p] -eq 1 -and $labels[$p] -eq 0){
    $cur++
    $minx=$dw;$miny=$dh;$maxx=0;$maxy=0;$area=0
    $st.Clear();$st.Push($p);$labels[$p]=$cur
    while($st.Count -gt 0){
      $q=$st.Pop(); $qx=$q%$dw; $qy=[int][Math]::Floor($q/$dw); $area++
      if($qx -lt $minx){$minx=$qx}; if($qx -gt $maxx){$maxx=$qx}
      if($qy -lt $miny){$miny=$qy}; if($qy -gt $maxy){$maxy=$qy}
      $y0=[Math]::Max(0,$qy-1);$y1=[Math]::Min($dh-1,$qy+1)
      $x0=[Math]::Max(0,$qx-1);$x1=[Math]::Min($dw-1,$qx+1)
      for($ny=$y0;$ny -le $y1;$ny++){
        $row=$ny*$dw
        for($nx=$x0;$nx -le $x1;$nx++){
          $np=$row+$nx
          if($mask[$np] -eq 1 -and $labels[$np] -eq 0){$labels[$np]=$cur;$st.Push($np)}
        }
      }
    }
    $boxes.Add([pscustomobject]@{minx=$minx;miny=$miny;maxx=$maxx;maxy=$maxy;area=$area})
  }
}

# ---- Absorb small detached props into a nearby figure (never merge two figure-sized blobs) ----
$rawCount=$boxes.Count
$gap=[int]($MergeGapFrac*$dw)
$propMax=0.008*$n
$merged=$true
while($merged){
  $merged=$false
  for($i=0;$i -lt $boxes.Count -and -not $merged;$i++){
    for($j=$i+1;$j -lt $boxes.Count -and -not $merged;$j++){
      $a=$boxes[$i];$b=$boxes[$j]
      $near=(($a.minx-$gap) -le $b.maxx -and ($a.maxx+$gap) -ge $b.minx -and ($a.miny-$gap) -le $b.maxy -and ($a.maxy+$gap) -ge $b.miny)
      if($near -and [Math]::Min($a.area,$b.area) -lt $propMax){
        $a.minx=[Math]::Min($a.minx,$b.minx);$a.miny=[Math]::Min($a.miny,$b.miny)
        $a.maxx=[Math]::Max($a.maxx,$b.maxx);$a.maxy=[Math]::Max($a.maxy,$b.maxy);$a.area=$a.area+$b.area
        $boxes.RemoveAt($j);$merged=$true
      }
    }
  }
}

# ---- Drop specks, sort row-major ----
$minArea=$MinAreaFrac*$n
$figs=@($boxes | Where-Object { $_.area -ge $minArea })
$bandH=0.10*$dh
$figs=@($figs | Sort-Object @{e={[Math]::Floor((($_.miny+$_.maxy)/2)/$bandH)}}, @{e={$_.minx}})

# ---- Scale up + pad, write figures.json ----
$pad=[int](0.006*$W)
$list=New-Object System.Collections.Generic.List[object]
$idx=0
foreach($f in $figs){
  $idx++
  $x=[Math]::Max(0,[int]($f.minx/$scale)-$pad)
  $y=[Math]::Max(0,[int]($f.miny/$scale)-$pad)
  $x2=[Math]::Min($W,[int]($f.maxx/$scale)+$pad)
  $y2=[Math]::Min($H,[int]($f.maxy/$scale)+$pad)
  $list.Add([pscustomobject]@{index=$idx;x=$x;y=$y;w=($x2-$x);h=($y2-$y)})
}
$parts = foreach($f in $list){ '{{"index":{0},"x":{1},"y":{2},"w":{3},"h":{4}}}' -f $f.index,$f.x,$f.y,$f.w,$f.h }
$json = "[" + ($parts -join ",") + "]"
$json | Set-Content -Path (Join-Path $Out "figures.json") -Encoding UTF8

# ---- Numbered preview (navy on grey) ----
$cols=[int][Math]::Ceiling([Math]::Sqrt([Math]::Max(1,$list.Count))); $rows=[int][Math]::Ceiling($list.Count/$cols)
$cell=240; $thumb=196
$grid=New-Object System.Drawing.Bitmap(($cols*$cell),($rows*$cell),[System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$gg=[System.Drawing.Graphics]::FromImage($grid)
$gg.Clear([System.Drawing.Color]::FromArgb($bg[0],$bg[1],$bg[2]))
$gg.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$navyBrush=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($navy[0],$navy[1],$navy[2]))
$font=New-Object System.Drawing.Font("Arial",18,[System.Drawing.FontStyle]::Bold)
$pen=New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(185,193,203),1)
$ci=0
foreach($f in $list){
  $col=$ci%$cols; $row=[int][Math]::Floor($ci/$cols); $ci++
  $cx=$col*$cell; $cy=$row*$cell
  $s=[Math]::Min($thumb/$f.w,$thumb/$f.h); $tw=[Math]::Max(1,[int]($f.w*$s)); $th=[Math]::Max(1,[int]($f.h*$s))
  $tb=New-Object System.Drawing.Bitmap($tw,$th,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $gtb=[System.Drawing.Graphics]::FromImage($tb); $gtb.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $gtb.DrawImage($full,(New-Object System.Drawing.Rectangle(0,0,$tw,$th)),(New-Object System.Drawing.Rectangle($f.x,$f.y,$f.w,$f.h)),[System.Drawing.GraphicsUnit]::Pixel); $gtb.Dispose()
  $td=$tb.LockBits((New-Object System.Drawing.Rectangle(0,0,$tw,$th)),[System.Drawing.Imaging.ImageLockMode]::ReadWrite,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $tbuf=New-Object byte[] ($tw*$th*4); [System.Runtime.InteropServices.Marshal]::Copy($td.Scan0,$tbuf,0,$tbuf.Length)
  for($k=0;$k -lt $tw*$th;$k++){ if($tbuf[$k*4+3] -gt 16){ $tbuf[$k*4]=$navy[2];$tbuf[$k*4+1]=$navy[1];$tbuf[$k*4+2]=$navy[0] } }
  [System.Runtime.InteropServices.Marshal]::Copy($tbuf,0,$td.Scan0,$tbuf.Length); $tb.UnlockBits($td)
  $tx=$cx+[int](($cell-$tw)/2); $ty=$cy+[int](($cell-$th)/2)
  $gg.DrawImage($tb,(New-Object System.Drawing.Rectangle($tx,$ty,$tw,$th))); $tb.Dispose()
  $gg.DrawRectangle($pen,$cx+4,$cy+4,$cell-8,$cell-8)
  $gg.FillEllipse($navyBrush,$cx+10,$cy+10,38,38)
  $gg.DrawString([string]$f.index,$font,[System.Drawing.Brushes]::White,$cx+$(if($f.index -lt 10){17}else{11}),$cy+16)
}
$gg.Dispose(); $grid.Save((Join-Path $Out "figures_grid.png"),[System.Drawing.Imaging.ImageFormat]::Png); $grid.Dispose(); $full.Dispose()

Write-Output ("figures={0}  transparentFrac={1:N3}  ({2})" -f $list.Count,$transFrac,$(if($transFrac -gt 0.03){"transparent sheet"}else{"solid-bg sheet -> bg knocked out"}))
foreach($f in $list){ Write-Output ("  #{0}: x={1} y={2} w={3} h={4}" -f $f.index,$f.x,$f.y,$f.w,$f.h) }
