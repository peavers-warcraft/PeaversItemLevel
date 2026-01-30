# Auto-deploy script for WoW addons (Windows/PowerShell)
# Detects addon name from current directory and copies to WoW installation

# Get addon name from current directory
$ADDON_NAME = Split-Path -Leaf $PWD

Write-Host "Deploying addon: $ADDON_NAME" -ForegroundColor Green

# Get all fixed drives to check for WoW installations
$Drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -ne $null } | ForEach-Object { $_.Root }

# Base WoW installation folder names to look for
$WOW_FOLDERS = @(
    "World of Warcraft"
    "Games\World of Warcraft"
    "Program Files (x86)\World of Warcraft"
    "Program Files\World of Warcraft"
    "Battle.net\World of Warcraft"
)

# WoW flavor subfolders (where Interface\AddOns actually lives)
$WOW_FLAVORS = @(
    "_retail_"
    "_classic_"
    "_classic_era_"
    "_ptr_"
    "_beta_"
    "_xptr_"
)

# Track if any deployment succeeded
$Deployed = $false

# Function to deploy to a specific addon path
function Deploy-ToPath {
    param($AddOnsPath)

    $TargetPath = Join-Path $AddOnsPath $ADDON_NAME

    Write-Host "Found AddOns folder at: $AddOnsPath" -ForegroundColor Yellow

    # Remove existing addon if present
    if (Test-Path $TargetPath) {
        Write-Host "Removing existing addon..." -ForegroundColor Yellow
        Remove-Item -Path $TargetPath -Recurse -Force
    }

    # Copy addon files
    Write-Host "Copying addon files..." -ForegroundColor Yellow
    Copy-Item -Path . -Destination $TargetPath -Recurse -Force

    # Remove deployment scripts and git files from target
    $FilesToRemove = @(
        "local_deploy.sh"
        "local_deploy.ps1"
        ".git"
        ".gitignore"
        ".gitattributes"
        "README.md"
        ".github"
    )

    foreach ($File in $FilesToRemove) {
        $FilePath = Join-Path $TargetPath $File
        if (Test-Path $FilePath) {
            Remove-Item -Path $FilePath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Host "Deployed to: $TargetPath" -ForegroundColor Green
    return $true
}

# Search for WoW installations
$FoundPaths = @()

foreach ($Drive in $Drives) {
    foreach ($Folder in $WOW_FOLDERS) {
        $BasePath = Join-Path $Drive $Folder

        if (Test-Path $BasePath) {
            # Check each flavor subfolder
            foreach ($Flavor in $WOW_FLAVORS) {
                $FlavorPath = Join-Path $BasePath $Flavor
                $AddOnsPath = Join-Path $FlavorPath "Interface\AddOns"

                if (Test-Path $AddOnsPath) {
                    $FoundPaths += $AddOnsPath
                }
            }

            # Also check if Interface\AddOns exists directly (older structure)
            $DirectAddOns = Join-Path $BasePath "Interface\AddOns"
            if (Test-Path $DirectAddOns) {
                $FoundPaths += $DirectAddOns
            }
        }
    }
}

# Remove duplicates
$FoundPaths = $FoundPaths | Select-Object -Unique

# Deploy to all found paths
foreach ($AddOnsPath in $FoundPaths) {
    if (Deploy-ToPath $AddOnsPath) {
        $Deployed = $true
    }
}

# Check if any deployment succeeded
if (-not $Deployed) {
    Write-Host "Error: Could not find WoW installation" -ForegroundColor Red
    Write-Host "Searched for Interface\AddOns in these locations:" -ForegroundColor Yellow
    foreach ($Drive in $Drives) {
        foreach ($Folder in $WOW_FOLDERS) {
            Write-Host "  - $Drive$Folder\<flavor>\" -ForegroundColor Gray
        }
    }
    Write-Host ""
    Write-Host "Flavors checked: $($WOW_FLAVORS -join ', ')" -ForegroundColor Gray
    exit 1
}

Write-Host ""
Write-Host "Deployment complete!" -ForegroundColor Green
Write-Host "Remember to reload your UI in-game with /reload" -ForegroundColor Yellow
