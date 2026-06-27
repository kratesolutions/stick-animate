<#
  hf_put.ps1 — upload local bytes to a Higgsfield presigned URL (the PUT step of
  media_upload). Usage:
    powershell -ExecutionPolicy Bypass -File hf_put.ps1 -Url "<upload_url>" -File "<path>" -ContentType "image/png"
#>
param([Parameter(Mandatory=$true)][string]$Url,[Parameter(Mandatory=$true)][string]$File,[string]$ContentType="image/png")
$ErrorActionPreference="Stop"
$r=Invoke-WebRequest -Uri $Url -Method Put -InFile $File -ContentType $ContentType -UseBasicParsing
Write-Output ("PUT " + $r.StatusCode)
