$lang = 'en_US'
$arch_gapps = 'x86_64'
$arch_wsa = 'x64'
$wsl_username = 'yourusername'

$downloadPath = '.'
$skipDownload = $false


if ( -not $skipDownload ) {
    "Downloading"

    # Get msixbundle

    $adgardQueryBody = @{
        type = 'ProductId'
        url  = '9P3395VX91NR'
        ring = 'WIS'
        lang = $lang
    }

    $req = Invoke-WebRequest -Uri 'https://store.rg-adguard.net/api/GetFiles' -Method Post -Body $adgardQueryBody 
    $re = '<tr style=".*?"><td><a href="(?<url>.*?)" rel="noreferrer">MicrosoftCorporationII\.WindowsSubsystemForAndroid_[^<]+\.msixbundle</a></td>.+</tr>'
    $req.Content -match $re > $null
    $downlowdLink = $Matches['url']

    mkdir -Force $downloadPath > $null

    Invoke-WebRequest -Uri $downlowdLink -OutFile $downloadPath'/wsa.msixbundle'  -SkipCertificateCheck

    #Get GApps
    $req = Invoke-WebRequest -Uri 'https://api.opengapps.org/list'
    $url = ((ConvertFrom-Json  $req.Content -AsHashtable)['archs'][$arch_gapps]['apis']['11.0']['variants'] | Where-Object { $_['name'] -eq 'pico' })['zip']
(Invoke-WebRequest -Uri $url) -match '<meta http-equiv="refresh" content="5; url=(.+?)">' > $null
    Invoke-WebRequest -Uri $Matches[1] -OutFile $downloadPath'/pico.zip'
    #clone repo
    git.exe clone https://github.com/ADeltaX/WSAGAScript 

}

# unzip wsa
"Unzipping"
Expand-Archive $downloadPath'/wsa.msixbundle'  -DestinationPath $downloadPath'/wsa' -Force
Expand-Archive  ((Get-ChildItem $downloadPath'/wsa') | Where-Object { $_.Name -match $arch_wsa } ).FullName -Force -DestinationPath $downloadPath'/wsap'

Remove-Item -Force $downloadPath'/wsap/AppxBlockMap.xml'
Remove-Item -Force $downloadPath'/wsap/AppxSignature.p7x'
Remove-Item -Force $downloadPath'/wsap/[Content_Types].xml'
Remove-Item -Force -Recurse $downloadPath'/wsap/AppxMetadata'

Move-Item $downloadPath'/wsap/*.img' $downloadPath'/WSAGAScript/#IMAGES'
Move-Item $downloadPath'/pico.zip' $downloadPath'/WSAGAScript/#GAPPS'

#run shell
$path = (Get-Location).Path.Replace('\', '/')
$path = 'Root="/mnt/' + $path[0].ToString().ToLower() + $path.Substring(2) + '/WSAGAScript"'
$vars = ((Get-Content $downloadPath'/WSAGAScript/VARIABLES.sh') -replace '^Root=".*"', $path) -join "`n"
($vars + "`n") |  Out-File $downloadPath'/WSAGAScript/VARIABLES.sh' -NoNewline

$shell = @"
sudo apt update
sudo apt install unzip
sudo apt install lzip
sudo ln -s /proc/self/mounts /etc/mtab
cd WSAGAScript
sudo ./extract_gapps_pico.sh
sudo ./extend_and_mount_images.sh
sudo ./apply.sh
sudo ./unmount_images.sh
"@
$shell | Set-Content $downloadPath'/shell.sh'
Clear-Host
"Waiting for WSL..."
wsl.exe -u $wsl_username './shell.sh'

#install

Copy-Item $downloadPath'/WSAGAScript/*.img' $downloadPath'/wsap' -Force
Import-Module Appx -usewindowspowershell
Add-AppxPackage -Register $downloadPath'/wsap/AppxManifest.xml'

"****Finished****"
