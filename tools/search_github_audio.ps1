$headers = @{ "User-Agent" = "PowerShell-DragonAudioFinder" }

function Search-Repo($ownerRepo, $path = "") {
    $url = "https://api.github.com/repos/$ownerRepo/contents/$path"
    try {
        $items = Invoke-RestMethod -Uri $url -Headers $headers
        return $items
    } catch {
        Write-Host "Error accessing $url : $_"
        return $null
    }
}

Write-Host "=== veloren/veloren/assets/voxygen/audio/sfx/footsteps ==="
$r1 = Search-Repo "veloren/veloren" "assets/voxygen/audio/sfx/footsteps"
if ($r1) { $r1 | ForEach-Object { Write-Host "$($_.name)" } }

Write-Host "`n=== veloren/veloren/assets/voxygen/audio/ambient ==="
$r2 = Search-Repo "veloren/veloren" "assets/voxygen/audio/ambient"
if ($r2) { $r2 | ForEach-Object { Write-Host "$($_.name)" } }
