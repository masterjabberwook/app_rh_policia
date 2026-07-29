Write-Host "Fetching Android repository XML..."
$url = "https://dl.google.com/android/repository/repository2-1.xml"
$xmlText = (New-Object System.Net.WebClient).DownloadString($url)

Write-Host "Finding Windows command line tools URL via regex..."
if ($xmlText -match "(commandlinetools-win-\d+_latest\.zip)") {
    $zipName = $Matches[1]
    $zipUrl = "https://dl.google.com/android/repository/$zipName"
    Write-Host "Found URL: $zipUrl"
} else {
    Write-Error "Could not find commandlinetools-win zip in repository XML."
    exit 1
}

$sdkPath = "$env:LOCALAPPDATA\Android\Sdk"
$tempZip = "$env:TEMP\cmdline-tools.zip"
$tempExtract = "$env:TEMP\cmdline-tools-extract"

Write-Host "Downloading command-line tools..."
Invoke-WebRequest -Uri $zipUrl -OutFile $tempZip

Write-Host "Extracting..."
if (Test-Path $tempExtract) {
    Remove-Item -Path $tempExtract -Recurse -Force
}
Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force

$destDir = "$sdkPath\cmdline-tools\latest"
if (!(Test-Path $destDir)) {
    New-Item -ItemType Directory -Path $destDir -Force
} else {
    Remove-Item -Path "$destDir\*" -Recurse -Force
}

# The extracted archive folder has cmdline-tools directory containing bin, lib, source.properties, etc.
# We copy its contents directly into the 'latest' folder.
Write-Host "Moving files to SDK path ($destDir)..."
Copy-Item -Path "$tempExtract\cmdline-tools\*" -Destination $destDir -Recurse -Force

Write-Host "Cleaning up..."
Remove-Item -Path $tempZip -Force
Remove-Item -Path $tempExtract -Recurse -Force

Write-Host "Installation completed successfully!"
