<#PSScriptInfo

.VERSION 1.0

.AUTHOR Thomas Obarowski (https://www.linkedin.com/in/tjobarow/)

.COPYRIGHT (c) 2024 Thomas Obarowski

.TAGS Automation Scripts

.SYNOPSIS
    This module copies the C:\Program Files\Zero Networks\BreakGlass\ directory to a destination server

.DESCRIPTION
    This module will use a PSSession to connect to the provided Segment Server. It attempts
    to compress C:\Program Files\Zero Networks\BreakGlass\ to BreakGlass.zip, and then copy
    it to the local filesystem (host running module). It then closes the previous pssession
    and enters a new one on the destination server. It copies the breakglass.zip file to 
    a remote directory provided at run time. It then closes the pssession and removes the 
    local copy of BreakGlass.zip

.NOTES
    The account used to run the module must have PSRemoting permission to BOTH the
    SegmentServer and BreakGlassServer. It must also have local admin on the 
    BreakGlassServer.


.EXAMPLE
    Sync-BreakGlassDirectory -Username "adminUsername" -Password "adminPwd"-BreakGlassServer "destinationServerHostName" -SegmentServer "znSegmentServerHostName" -RemoteDirectory "C:\Users\Public\ZNBreakGlassFiles"

#>

function Log-Message {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Message = ""
    )
    Write-Host "$((Get-Date -Format 'yyyy-MM-dd HH:mm:ss').ToString()) - $Message"
    "$((Get-Date -Format 'yyyy-MM-dd HH:mm:ss').ToString()) - $Message" | Out-File -FilePath "$((Get-Date -Format 'yyyy-MM-dd').ToString())_sync-BreakGlass-Directory.log" -Append
}


function Get-Credentials {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Username,
        [Parameter(Mandatory = $true)]
        [string]$Password
    )
    try {
        # Create the PSCredential object from jenkins credentials passed as env variables
        $svc_pwd = ConvertTo-SecureString "$Password" -AsPlainText -Force
        $credentials = New-Object System.Management.Automation.PSCredential ($Username, $svc_pwd)
        Log-Message "Loaded credentials for use with AD. Username: $($credentials.UserName)"
        return $credentials
    }
    catch {
        Log-Message "An error occurred when creating the credentials object."
        Log-Message $Error[0]
        exit 1
    }
}


function Get-BreakGlassZip {
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]$Credential,
        [Parameter(Mandatory = $true)]
        [string]$SegmentServer
    )
    try {
        Log-Message "Attemping to connect to $SegmentServer via New-PSSession."
        $RemoteSession = New-PSSession -ComputerName $SegmentServer -Credential $Credential
        Log-Message "Successfully connected to $SegmentServer via PSSession using $($Credential.UserName)"

        Log-Message "Attempting to compress the ZN BreakGlass directory to breakGlass.zip file"
        $CompressScript = {
            Compress-Archive -Path "C:\Program Files\Zero Networks\BreakGlass\" -DestinationPath "C:\Users\$($args[0])\BreakGlass.zip" -Update
        }
        Invoke-Command -Session $RemoteSession -ArgumentList $Credential.UserName -ScriptBlock $CompressScript
        Log-Message "Successfully compressed ZN BreakGlass directory to zip file breakGlass.zip"

        Log-Message "Attempting to copy BreakGlass.zip file from $SegmentServer to $ENV:COMPUTERNAME"
        Copy-Item -FromSession $RemoteSession -Path "C:\Users\$($Credential.UserName)\BreakGlass.zip" -Destination .
        Log-Message "Successfully copied the BreakGlass.zip file from $SegmentServer to $ENV:COMPUTERNAME"

        Log-Message "Tearing down PSSession to $SegmentServer"
        Remove-PsSession -Session $RemoteSession
        Log-Message "Exited PSSession on $SegmentServer"
    }
    catch {
        $Error
        Log-Message $Error[0]
        exit 1
    }
}


function Push-BreakGlassZip {
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]$Credential,
        [Parameter(Mandatory = $true)]
        [string]$RemoteDirectory,
        [Parameter(Mandatory = $true)]
        [string]$BreakGlassServer,
        [Parameter(Mandatory = $true)]
        [string]$SegmentServer
    )
    try {



        Log-Message "Attemping to connect to $BreakGlassServer via New-PSSession."
        $RemoteSession = New-PSSession -ComputerName $BreakGlassServer -Credential $Credential
        Log-Message "Successfully connected to $BreakGlassServer via PSSession using $($Credential.UserName)"

        Log-Message "Verifying directory $RemoteDirectory exists on $BreakGlassServer and creating it if non-existent."
        $VerifyDirectoryScript = {
            if (-not (Test-Path -Path $args[0])) {
                New-Item -Path $args[0] -ItemType Directory
            }
            else {
                Write-Output "$($args[0]) already exists"
            }
        }
        Invoke-Command -Session $RemoteSession -ArgumentList $RemoteDirectory -ScriptBlock $VerifyDirectoryScript
        Log-Message "Verfied directory $RemoteDirectory exists on $BreakGlassServer"

        Log-Message "Attempting to copy BreakGlass.zip file from $ENV:COMPUTERNAME to $BreakGlassServer ($RemoteDirectory\BreakGlass-From-$($SegmentServer).zip)"
        Copy-Item -ToSession $RemoteSession -Path ".\BreakGlass.zip" -Destination "$($RemoteDirectory)\BreakGlass-From-$($SegmentServer).zip"
        Log-Message "Successfully copied the BreakGlass.zip file from $ENV:COMPUTERNAME to $BreakGlassServer ($RemoteDirectory\BreakGlass-From-$($SegmentServer).zip)"
    
        Log-Message "Tearing down PSSession to $BreakGlassServer"
        Remove-PsSession -Session $RemoteSession
        Log-Message "Exited PSSession on $BreakGlassServer"

        Log-Message "Attempting to remove BreakGlass.zip file from $ENV:COMPUTERNAME"
        Remove-Item -Path ".\BreakGlass.zip"
        Log-Message "Successfully removed BreakGlass.zip file from $ENV:COMPUTERNAME"
    }
    catch {
        Log-Message $Error[0]
        exit 1
    }
}

function Sync-BreakGlassDirectory {
    param(
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]$Credential = $null,
        [Parameter(Mandatory = $true)]
        [string]$RemoteDirectory,
        [Parameter(Mandatory = $true)]
        [string]$BreakGlassServer,
        [Parameter(Mandatory = $true)]
        [string]$SegmentServer,
        [Parameter(Mandatory = $false)]
        [string]$Username,
        [Parameter(Mandatory = $false)]
        [string]$Password
    )

    if ($null -eq $Credential) {
        if (($null -eq $Username) -or ($null -eq $Password)) {
            Log-Message "You must either provide a valid credential object, or a valid -Username and -Password"
        }
        else {
            $Credential = Get-Credentials -Username $Username -Password $Password
        }
    }

    if ($null -eq $Credential) {
        Log-Message "No valid credential object was provided or created. Exiting."
        exit 1
    }

    Get-BreakGlassZip -Credential $Credential -SegmentServer $SegmentServer
    Push-BreakGlassZip -Credential $Credential -RemoteDirectory $RemoteDirectory -BreakGlassServer $BreakGlassServer -SegmentServer $SegmentServer
    Log-Message "Completed copying BreakGlass directory from $SegmentServer to $BreakGlassServer at $RemoteDirectory\BreakGlass-From-$($SegmentServer)"
}

Sync-BreakGlassDirectory -Username $ENV:username -Password $ENV:password -BreakGlassServer $ENV:breakglass_server -SegmentServer $ENV:segment_server -RemoteDirectory $ENV:remote_directory

