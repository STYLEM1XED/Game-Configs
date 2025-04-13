    If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator"))
    {Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    Exit}
    $Host.UI.RawUI.WindowTitle = $myInvocation.MyCommand.Definition + " (Administrator)"
    $Host.UI.RawUI.BackgroundColor = "Black"
	$Host.PrivateData.ProgressBackgroundColor = "Black"
    $Host.PrivateData.ProgressForegroundColor = "White"
    Clear-Host

    function Get-FileFromWeb {
    param ([Parameter(Mandatory)][string]$URL, [Parameter(Mandatory)][string]$File)
    function Show-Progress {
    param ([Parameter(Mandatory)][Single]$TotalValue, [Parameter(Mandatory)][Single]$CurrentValue, [Parameter(Mandatory)][string]$ProgressText, [Parameter()][int]$BarSize = 10, [Parameter()][switch]$Complete)
    $percent = $CurrentValue / $TotalValue
    $percentComplete = $percent * 100
    if ($psISE) { Write-Progress "$ProgressText" -id 0 -percentComplete $percentComplete }
    else { Write-Host -NoNewLine "`r$ProgressText $(''.PadRight($BarSize * $percent, [char]9608).PadRight($BarSize, [char]9617)) $($percentComplete.ToString('##0.00').PadLeft(6)) % " }
    }
    try {
    $request = [System.Net.HttpWebRequest]::Create($URL)
    $response = $request.GetResponse()
    if ($response.StatusCode -eq 401 -or $response.StatusCode -eq 403 -or $response.StatusCode -eq 404) { throw "Remote file either doesn't exist, is unauthorized, or is forbidden for '$URL'." }
    if ($File -match '^\.\\') { $File = Join-Path (Get-Location -PSProvider 'FileSystem') ($File -Split '^\.')[1] }
    if ($File -and !(Split-Path $File)) { $File = Join-Path (Get-Location -PSProvider 'FileSystem') $File }
    if ($File) { $fileDirectory = $([System.IO.Path]::GetDirectoryName($File)); if (!(Test-Path($fileDirectory))) { [System.IO.Directory]::CreateDirectory($fileDirectory) | Out-Null } }
    [long]$fullSize = $response.ContentLength
    [byte[]]$buffer = new-object byte[] 1048576
    [long]$total = [long]$count = 0
    $reader = $response.GetResponseStream()
    $writer = new-object System.IO.FileStream $File, 'Create'
    do {
    $count = $reader.Read($buffer, 0, $buffer.Length)
    $writer.Write($buffer, 0, $count)
    $total += $count
    if ($fullSize -gt 0) { Show-Progress -TotalValue $fullSize -CurrentValue $total -ProgressText " $($File.Name)" }
    } while ($count -gt 0)
    }
    finally {
    $reader.Close()
    $writer.Close()
    }
    }

    function Show-ModernFilePicker {
    param(
    [ValidateSet('Folder', 'File')]
    $Mode,
    [string]$fileType
    )
    if ($Mode -eq 'Folder') {
    $Title = 'Select Folder'
    $modeOption = $false
    $Filter = "Folders|`n"
    }
    else {
    $Title = 'Select File'
    $modeOption = $true
    if ($fileType) {
    $Filter = "$fileType Files (*.$fileType) | *.$fileType|All files (*.*)|*.*"
    }
    else {
    $Filter = 'All Files (*.*)|*.*'
    }
    }
    $AssemblyFullName = 'System.Windows.Forms, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'
    $Assembly = [System.Reflection.Assembly]::Load($AssemblyFullName)
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.AddExtension = $modeOption
    $OpenFileDialog.CheckFileExists = $modeOption
    $OpenFileDialog.DereferenceLinks = $true
    $OpenFileDialog.Filter = $Filter
    $OpenFileDialog.Multiselect = $false
    $OpenFileDialog.Title = $Title
    $OpenFileDialog.InitialDirectory = [Environment]::GetFolderPath('Desktop')
    $OpenFileDialogType = $OpenFileDialog.GetType()
    $FileDialogInterfaceType = $Assembly.GetType('System.Windows.Forms.FileDialogNative+IFileDialog')
    $IFileDialog = $OpenFileDialogType.GetMethod('CreateVistaDialog', @('NonPublic', 'Public', 'Static', 'Instance')).Invoke($OpenFileDialog, $null)
    $null = $OpenFileDialogType.GetMethod('OnBeforeVistaDialog', @('NonPublic', 'Public', 'Static', 'Instance')).Invoke($OpenFileDialog, $IFileDialog)
    if ($Mode -eq 'Folder') {
    [uint32]$PickFoldersOption = $Assembly.GetType('System.Windows.Forms.FileDialogNative+FOS').GetField('FOS_PICKFOLDERS').GetValue($null)
    $FolderOptions = $OpenFileDialogType.GetMethod('get_Options', @('NonPublic', 'Public', 'Static', 'Instance')).Invoke($OpenFileDialog, $null) -bor $PickFoldersOption
    $null = $FileDialogInterfaceType.GetMethod('SetOptions', @('NonPublic', 'Public', 'Static', 'Instance')).Invoke($IFileDialog, $FolderOptions)
    }
    $VistaDialogEvent = [System.Activator]::CreateInstance($AssemblyFullName, 'System.Windows.Forms.FileDialog+VistaDialogEvents', $false, 0, $null, $OpenFileDialog, $null, $null).Unwrap()
    [uint32]$AdviceCookie = 0
    $AdvisoryParameters = @($VistaDialogEvent, $AdviceCookie)
    $AdviseResult = $FileDialogInterfaceType.GetMethod('Advise', @('NonPublic', 'Public', 'Static', 'Instance')).Invoke($IFileDialog, $AdvisoryParameters)
    $AdviceCookie = $AdvisoryParameters[1]
    $Result = $FileDialogInterfaceType.GetMethod('Show', @('NonPublic', 'Public', 'Static', 'Instance')).Invoke($IFileDialog, [System.IntPtr]::Zero)
    $null = $FileDialogInterfaceType.GetMethod('Unadvise', @('NonPublic', 'Public', 'Static', 'Instance')).Invoke($IFileDialog, $AdviceCookie)
    if ($Result -eq [System.Windows.Forms.DialogResult]::OK) {
    $FileDialogInterfaceType.GetMethod('GetResult', @('NonPublic', 'Public', 'Static', 'Instance')).Invoke($IFileDialog, $null)
    }
    return $OpenFileDialog.FileName
    }

# message
Write-Host "Run game once to generate config location"
Write-Host ""
Pause
Clear-Host

# download config files
Get-FileFromWeb -URL "https://github.com/FR33THYFR33THY/Github-Game-Configs/raw/refs/heads/main/Call%20of%20Duty/Call%20of%20Duty%20WZ%20BO6%20MW2%20MW3.zip" -File "$env:TEMP\WZBO6MW2MW3.zip"
Clear-Host

# extract config files
Expand-Archive "$env:TEMP\WZBO6MW2MW3.zip" -DestinationPath "$env:TEMP\WZBO6MW2MW3" -ErrorAction SilentlyContinue | Out-Null
Clear-Host

# message
Write-Host "Importing Inspector Profiles: Rebar Off. Please wait . . ."
Write-Host ""
Write-Host "AMD GPU users, ignore error & press 'OK' x3"
Write-Host ""

# unblock drs files
$path = "C:\ProgramData\NVIDIA Corporation\Drs"
Get-ChildItem -Path $path -Recurse | Unblock-File

# import inspector profiles
Start-Process -wait "$env:TEMP\WZBO6MW2MW3\RebarOffInspector\Inspector.exe" -args "$env:TEMP\WZBO6MW2MW3\RebarOffInspector\MW2.nip -silent"
Timeout /T 3 | Out-Null
Start-Process -wait "$env:TEMP\WZBO6MW2MW3\RebarOffInspector\Inspector.exe" -args "$env:TEMP\WZBO6MW2MW3\RebarOffInspector\MW3.nip -silent"
Timeout /T 3 | Out-Null
Start-Process -wait "$env:TEMP\WZBO6MW2MW3\RebarOffInspector\Inspector.exe" -args "$env:TEMP\WZBO6MW2MW3\RebarOffInspector\WZBO6.nip -silent"
Timeout /T 3 | Out-Null
Clear-Host

# edit config files
$options3cod22cst = "$env:TEMP\WZBO6MW2MW3\players\options.3.cod22.cst"
$options4cod23cst = "$env:TEMP\WZBO6MW2MW3\players\options.4.cod23.cst"
$s10cod24txt0 = "$env:TEMP\WZBO6MW2MW3\players\s.1.0.cod24.txt0"
$s10cod24txt1 = "$env:TEMP\WZBO6MW2MW3\players\s.1.0.cod24.txt1"

# user input change rendererworkercount in config files
Write-Host "Set RendererWorkerCount to cpu cores -1"
Write-Host ""
do {
$input = Read-Host -Prompt "RendererWorkerCount"
} while ([string]::IsNullOrWhiteSpace($input))
(Get-Content $options3cod22cst) -replace "\$", $input | Out-File $options3cod22cst
(Get-Content $options4cod23cst) -replace "\$", $input | Out-File $options4cod23cst
(Get-Content $s10cod24txt0) -replace "\$", $input | Out-File $s10cod24txt0
(Get-Content $s10cod24txt1) -replace "\$", $input | Out-File $s10cod24txt1

# convert options.3.cod22.cst to utf8
$content = Get-Content -Path "$env:TEMP\WZBO6MW2MW3\players\options.3.cod22.cst" -Raw
$filePath = "$env:TEMP\WZBO6MW2MW3\players\options.3.cod22.cst"
$encoding = New-Object System.Text.UTF8Encoding $false
$writer = [System.IO.StreamWriter]::new($filePath, $false, $encoding)
$writer.Write($content)
$writer.Close()

# convert options.4.cod23.cst to utf8
$content = Get-Content -Path "$env:TEMP\WZBO6MW2MW3\players\options.4.cod23.cst" -Raw
$filePath = "$env:TEMP\WZBO6MW2MW3\players\options.4.cod23.cst"
$encoding = New-Object System.Text.UTF8Encoding $false
$writer = [System.IO.StreamWriter]::new($filePath, $false, $encoding)
$writer.Write($content)
$writer.Close()

# convert s.1.0.cod24.txt0 to utf8
$content = Get-Content -Path "$env:TEMP\WZBO6MW2MW3\players\s.1.0.cod24.txt0" -Raw
$filePath = "$env:TEMP\WZBO6MW2MW3\players\s.1.0.cod24.txt0"
$encoding = New-Object System.Text.UTF8Encoding $false
$writer = [System.IO.StreamWriter]::new($filePath, $false, $encoding)
$writer.Write($content)
$writer.Close()

# convert s.1.0.cod24.txt1 to utf8
$content = Get-Content -Path "$env:TEMP\WZBO6MW2MW3\players\s.1.0.cod24.txt1" -Raw
$filePath = "$env:TEMP\WZBO6MW2MW3\players\s.1.0.cod24.txt1"
$encoding = New-Object System.Text.UTF8Encoding $false
$writer = [System.IO.StreamWriter]::new($filePath, $false, $encoding)
$writer.Write($content)
$writer.Close()

# install config files
Copy-Item -Path "$env:TEMP\WZBO6MW2MW3\players\*" -Destination "$env:USERPROFILE\Documents\Call of Duty\players" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
Copy-Item -Path "$env:TEMP\WZBO6MW2MW3\players\*" -Destination "$env:USERPROFILE\OneDrive\Documents\Call of Duty\players" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
Clear-Host

# pick folder
Write-Host "In 'Documents\Call of Duty\players' select 'YourID' folder:"
$ConfigFolder1 = Show-ModernFilePicker -Mode Folder
Clear-Host

# install config files
Copy-Item -Path "$env:TEMP\WZBO6MW2MW3\YourID\*" -Destination "$ConfigFolder1" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
Clear-Host

# cleanup
Remove-Item "$env:TEMP\WZBO6MW2MW3" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:TEMP\WZBO6MW2MW3.zip" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null

# message
Write-Host "Call of Duty WZ BO6 MW2 MW3 config applied . . ."
Write-Host ""
Write-Host "Resizable-bar causes bad 1% lows in this engine"
Write-Host "Resizable-bar is turned off in Config & Inspector for NVIDIA GPU'S"
Write-Host "AMD GPU users please turn off Resizable-bar in BIOS"
Write-Host ""
Write-Host "Turn HAGS off ONLY in MW2 for more FPS"
Write-Host ""
Write-Host "Always select 'no' for 'Set Optimal Settings & Run In Safe Mode'"
Write-Host ""
Write-Host "Open game, in GRAPHICS select Restart Shaders Pre-Loading then reboot game"
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")