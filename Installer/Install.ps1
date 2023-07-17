if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-File $($MyInvocation.MyCommand.Path)" -Verb RunAs
    exit
}

$osArch = (Get-CimInstance CIM_Processor).Architecture
$sbiePath = Join-Path $Env:ProgramFiles "Sandboxie-Plus"
$scriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$services = @('SbieSvc', 'SbieDrv')

if (!(Test-Path $sbiePath)) {
    Write-Error "Sandboxie-Plus not found!"
    Pause
    exit 1
}

switch ($osArch) {
    "0" {
        $selectedFile = "x86"
    }
    "9" {
        $selectedFile = "x64"
    }
    "5" {
        $selectedFile = "a64"
    }
}

$selectedFile = [IO.Path]::Combine($scriptDirectory, "SbiePlus_$selectedFile", "SbieDrv.sys")

foreach ($service in $services) {
    if ((Get-Service $service).Status -ne 'Stopped') {
        Write-Output "Stopping $service..."
        & "$sbiePath\KmdUtil.exe" stop $service
        $timeout = 15
        while ((Get-Service $service).Status -ne 'Stopped' -and $timeout -gt 0) {
            Write-Output "Waiting for $service to stop..."
            Start-Sleep -Seconds 5
            $timeout -= 5
        }
        if ((Get-Service $service).Status -ne 'Stopped') {
            Write-Error "$service failed to stop within 15 seconds. Check if there's another process using it"
            & "$sbiePath\KmdUtil.exe" scandll
            Pause
            exit 1
        }
    }
}

Write-Output "Copying $selectedFile to $sbiePath"
Copy-Item $selectedFile $sbiePath -Force
if (!$?) {
    Pause
    exit 1
}

foreach ($service in $services) {
    if ((Get-Service $service).Status -ne 'Running') {
        Write-Output "Starting $service..."
        & "$sbiePath\KmdUtil.exe" start $service
    }
}

Write-Output "Success!"
Pause
