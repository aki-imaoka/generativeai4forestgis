# Copy each participant's files from Google Drive into participants/pNN and push to main.
param(
    [string]$DriveRoot = 'G:\マイドライブ\generativeai_meeting\meetings\20261107\handson',
    [switch]$DryRun
)

$repo = Split-Path $PSScriptRoot -Parent
$allowed = '.html', '.htm', '.css', '.js', '.json', '.geojson', '.csv', '.png', '.jpg', '.jpeg', '.gif', '.svg', '.webp'
$maxBytes = 25MB

git -C $repo pull --ff-only

foreach ($dir in Get-ChildItem -LiteralPath $DriveRoot -Directory | Where-Object { $_.Name -match '^p\d{2}_' }) {
    $id = $dir.Name.Substring(0, 3)
    $files = @(Get-ChildItem -LiteralPath $dir.FullName -Recurse -File | Where-Object { $allowed -contains $_.Extension.ToLower() })
    $large = @($files | Where-Object { $_.Length -gt $maxBytes })
    foreach ($f in $large) { Write-Warning "$id skipped (over 25MB): $($f.Name)" }
    $files = @($files | Where-Object { $_.Length -le $maxBytes })

    # Keep the placeholder until the participant has an index.html.
    if (-not ($files | Where-Object { $_.Name -ieq 'index.html' })) { continue }

    Write-Output "$id : $($files.Count) file(s)"
    if ($DryRun) { continue }

    $dest = Join-Path $repo "participants\$id"
    Remove-Item -LiteralPath $dest -Recurse -Force -ErrorAction SilentlyContinue
    foreach ($f in $files) {
        $target = Join-Path $dest $f.FullName.Substring($dir.FullName.Length + 1)
        New-Item -ItemType Directory -Force -Path (Split-Path $target -Parent) | Out-Null
        Copy-Item -LiteralPath $f.FullName -Destination $target
    }
}

if ($DryRun) { return }

git -C $repo add participants
git -C $repo diff --cached --quiet
if ($LASTEXITCODE -eq 0) {
    Write-Output 'No changes.'
    return
}
git -C $repo commit -m "Sync participant files from Google Drive"
git -C $repo push origin main
