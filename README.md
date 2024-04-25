# Zero Networks Break Glass File Sync

This script is aimed at assisting organizations that wish to have a dedicated server from which to execute a breakglass procedure from. The breakglass procedure requires a certain file (segmentedAssets.json) that is only presented and updated on the segment server(s). So, in order to have a server up-to-date and ready to go in the event breakglass is needed, you have to ensure the server has the latest breakglass files needed. 

This script, when ran, will copy the contents of the BreakGlass directory on the Zero Networks Segment Server, to another destination server of your choosing. Running this script as a scheduled job will ensure the breakglass server has a (relatively) up to date version of the required files. 
## Authors

- Thomas Obarowski - [GitHub](https://www.github.com/tjobarow) - [LinkedIn](https://www.linkedin.com/in/tjobarow/)


## Usage/Examples

### Dependencies
In order to run this script successfully, you will need the following:
- A Windows Server with which you plan to use as a breakglass server
- A domain account that has local administrator permissions and PSRemoting permission on both the segment and destination breakglass server.
- PSRemoting must be enabled on both the segment server and destination server

#### Enabling PSRemoting
Open an administrator command PowerShell session on the server you want to enable PSRemoting on and run the following:
```powershell
Enable-PSRemoting -Force
```

#### Giving domain account permission for PSRemoting
On each server the account needs PSRemoting permission on, RDP (or console) into each server (GUI required), and run the following. 

```powershell
Set-PSSessionConfiguration -Name Microsoft.PowerShell -ShowSecurityDescriptorUI -Force 
```

This will open up a graphical popup, where you can then add the account and give it "full control" (read/write should work as well, but not tested). There is likely a way to do this without graphical interaction, but I am not sure how (didn't look into it).

### Usage

#### Basic Usage
Before running the script, you may will need to adjust the main function call to suit your needs. Open sync_breakglass_directory.ps1 and scroll to the bottom. You will see:

```powershell
Sync-BreakGlassDirectory -Username $ENV:username -Password $ENV:password -BreakGlassServer $ENV:breakglass_server -SegmentServer $ENV:segment_server -RemoteDirectory $ENV:remote_directory
```

This is the main function call that will execute the script. You can see there are several parameters that are present:
- Username - Optionally provide a username for the admin account to use (can use the -Credential parameter (not shown above) to pass the script a PSCredential object instead)
- Password - Optionally provide the password for the associated admin user (can use the -Credential parameter (not shown above) to pass the script a PSCredential object instead)
- BreakGlassServer - The destination server to copy the BreakGlass directory to 
- SegmentServer - The ZN segment server to fetch the BreakGlass directory from
- RemoteDirectory - The directory you wish to copy the BreakGlass folder to on the BreakGlassServer

#### Providing a PSCredential versus Username/Password

Not shown above is the additional option to provide the script a PSCredential Object instead of a username and password. Doing so would look like:

```powershell
Sync-BreakGlassDirectory -Credential $Credentials -BreakGlassServer $ENV:breakglass_server -SegmentServer $ENV:segment_server -RemoteDirectory $ENV:remote_directory
```

or 

```powershell
Sync-BreakGlassDirectory -Credential (Get-Credential) -BreakGlassServer $ENV:breakglass_server -SegmentServer $ENV:segment_server -RemoteDirectory $ENV:remote_directory
```

#### Leveraging Environment Variables

As seen above, the basic syntax provided uses PowerShell environment variables in order to avoid hard-coding potentially sensitive data. 

To configure environment variables, simply add them into the **same** PowerShell session you will run the script from by running the following:

```powershell
$ENV:breakglass_server="myserver1"
$ENV:segment_server="segserver2"
$ENV:remote_directory="C:\Users\Public\ZNBreakGlass"
$ENV:username="myaccount"
$ENV:password="changethis"
```

then reference them within the main function call of sync_breakglass_directory.ps1:

```powershell
Sync-BreakGlassDirectory -Username $ENV:username -Password $ENV:password -BreakGlassServer $ENV:breakglass_server -SegmentServer $ENV:segment_server -RemoteDirectory $ENV:remote_directory
```
## License

[MIT](https://choosealicense.com/licenses/mit/)



