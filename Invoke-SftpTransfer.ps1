function Invoke-SftpTransfer {
    <#
    .Synopsis
       This function will copy/move data through an SFTP connection using the WinScp client.
    .DESCRIPTION
       The script will use WinSCP to copy/move data from a local directory to a remote directory.
    .PARAMETER LocalFolder
        The path of the local folder that will be use on the Sftp transfer.
    .PARAMETER RemoveFolder
        The destination path on the SFTP server where the data will be transferred.
    .PARAMETER ComputerName
        The hostname of the SFTP server.
    .PARAMETER Username
        The username that will be used to authenticated on the SFTP server.
    .PARAMETER Password
        The password that will be used to authenticated on the SFTP server.
    .PARAMETER SshHostKey
        The SSH hostkey of the SFTP server.
    .PARAMETER WinScpDllPath
        The path where the WinScpDll file is located. This is required as it is used to tranfer the data using the WinSCP client.
    .PARAMETER LocalPathLogFilePath
        The path where you want the logs to be stored.
    .PARAMETER ClearSource
        If this switch is included the data will be moved and not copied.
    .PARAMETER DataAge
        The DataAge parameter takes a DataTime object and will only copy files after that date. 
    .PARAMETER TeeDataFolder
        The path where the data will be backed up before it is been copied or moved to the SFTP server.

    .EXAMPLE
        # Move all files in C:\Path to SFTP location /path/ on SFTP server Server1. 

        $params = @{
            localFolder = "C:\Path"
            remoteFolder = "/path/"
            ComputerName = "Server1"
            Username = "Admin"
            Password = "Password"
            SshHostKey = $HostKey
            WinScpDllPath = "C:\Program Files (x86)\WinSCP\WinSCPnet.dll"
            LogFilePath = "C:\temp"
        }

        Invoke-SftpTransfer @params -cleanSource
    .EXAMPLE 
        # Copy files before yesterday at 12 AM from C:\Path to /path/ on SFTP server Server1.

        $params = @{
            localFolder = "C:\Path"
            remoteFolder = "/path/"
            ComputerName = "Server1"
            Username = "Admin"
            Password = "Password"
            SshHostKey = $HostKey
            WinScpDllPath = "C:\Program Files (x86)\WinSCP\WinSCPnet.dll"
            LogFilePath = "C:\temp"
        }

        Invoke-SftpTransfer @params -ageData $((Get-Date 00:00).AddDay(-1)) 
    .EXAMPLE 
        # Move files from C:\Path to /path on SFTP server Server1 and create a backup of the data in C:\backup

        $params = @{
            localFolder = "C:\Path"
            remoteFolder = "/path/"
            ComputerName = "Server1"
            Username = "Admin"
            Password = "Password"
            SshHostKey = $HostKey
            WinScpDllPath = "C:\Program Files (x86)\WinSCP\WinSCPnet.dll"
            LogFilePath = "C:\temp"
        }

        Invoke-SftpTransfer -localFolder C:\Path -remoteFolder /path/.. -dataTee C:\backup -cleanSource 
    #>
	[CmdletBinding(SupportsShouldProcess)]
	Param
	(
		#localFolder
		[Parameter(Position = 0,
                   Mandatory = $true,
				   ValueFromPipelineByPropertyName = $true,
				   HelpMessage = 'What is the local path of the folder that will be copied?')]
		[Alias('Path')]
		[string]$LocalFolder,
        #sftpPath
		[Parameter(Position = 1,
                   Mandatory = $true,
				   ValueFromPipelineByPropertyName = $true,
				   HelpMessage = 'What is the remote SFTP path?')]
		[Alias('Destination')]
        [string]$RemoteFolder,
        # SFTP Server Hostname
		[Parameter(Position = 2,
                   Mandatory = $true,
				   ValueFromPipelineByPropertyName = $true,
				   HelpMessage = 'What is the hostname of the SFTP server to connect to?')]
		[Alias('SftpServer')]
        [string]$ComputerName,
        # Username
        [Parameter(Position = 3,
                   Mandatory = $true,
				   ValueFromPipelineByPropertyName = $true,
				   HelpMessage = 'What is the username to connect to the SFTP server?')]
        [string]$Username,
        # Username
        [Parameter(Position = 4,
                   Mandatory = $true,
				   ValueFromPipelineByPropertyName = $true,
				   HelpMessage = 'What is the password to connect to the SFTP server?')]
        [String]$Password,
        # Ssh host key
        [Parameter(Position = 5,
                   Mandatory = $true,
				   ValueFromPipelineByPropertyName = $true,
				   HelpMessage = 'What is the host key for the SFTP server?')]
        [String]$SshHostKey,
        # WinSCP Dll path
        [Parameter(Position = 6,
                   Mandatory = $true,
                   ValueFromPipelineByPropertyName = $true,
                   HelpMessage = 'Where is the WinSCPnet.dll file located?')]
        [string]$WinScpDllPath,
        # Log file path
        [Parameter(Position = 7,
                   Mandatory = $true,
                   ValueFromPipelineByPropertyName = $true,
                   HelpMessage = 'Where should the log file be stored?')]
        [ValidateScript( {Test-Path -Path $_} )]
        [string]$LogFilePath,
        #CleanSource
		[Parameter(Mandatory = $false,
                   ValueFromPipelineByPropertyName = $true,
				   HelpMessage = 'Where should the data be copied to?')]
        [Alias('Move')]
		[switch]$CleanSource,
        #dataAge
		[Parameter(Mandatory = $false,
                   ValueFromPipelineByPropertyName = $true,
				   HelpMessage = 'How far back should we move files? Default: All files')]
		[System.DateTime]$DataAge,
        #teeData
		[Parameter(Mandatory = $false,
                   ValueFromPipelineByPropertyName = $true,
				   HelpMessage = 'Where should the data be copied to?')]
        [Alias('CopyPath')]
        [string]$TeeDataFolder
	)

    Begin{
        # If data will be moved and not copied to a datatee, show warning.
        if($CleanSource.IsPresent -and ($TeeDataFolder.Length -eq 0)){
            Write-Warning -Message "Warning: You are moving the data and not leaving a local backup."
        }

        # If no date is provided present the warning.
        if($DataAge -eq $null){
            Write-Warning -Message "Warning: No age date provided. All items will be copied." 
        }

        # Initiating the hashtable containing the 
        $hashFolders = @{
            "Source" = $LocalFolder; # Source is assigned to the local folder
            "remoteDestination" = $RemoteFolder # remoteDestination is assigned to the sftp location
        }

        if($TeeDataFolder.Length -ne 0){
            $hashFolders.Add("cDestination", $TeeDataFolder) # If a dataTee folder provided it add it to the hashtable.
        }

        # Set Move to False by default
        $move = $false
        if($CleanSource.IsPresent){ 
            
            # If the cleanSource switch is set then we will set Move to true. 
            $move = $true;
        }

        # Initiate the Test-TransferFolder function.
        function Test-TransferFolder{
            param([Hashtable]$transferInformation)
            $status = $true

            foreach($key in $transferInformation.Keys){ # Perform the check on each folder path
                if(!($key.equals("remoteDestination"))){ # Ignore the sftp path as it wouldn't exist.
                    if(!(Test-Path $transferInformation.$key)){ 

                        # If the folder doesn't exist then we set this to false.
                        $status = $false
                    }
                }
            }
            
            # Return the $status
            return $status
        }

        function Write-LogToFile ($LogContent) {
            $LogContent | Out-File -FilePath "$($LogFilePath)\SftpTransferLog_$(get-date -Format MMddyyyy-hhmmss).txt"
        }
    }
    Process{
        # Initiate the log object
        $progressLog = @()
        $progressLog += "Init: SFTP Data Transfer from $($hashFolders.source) to $($hashFolders.remoteDestination)."

        if($move) {
            # If the move variable is set to true note it in the log
            $progressLog += "Info: Move option enabled. SFTP will upload and remove the source."
        }
        
        if(!(Test-TransferFolder $hashFolders)){

            # Check the transfer folders, and return an error if there is any errors.
            $progressLog += "Error: One or more folders were not found. Please verify parameters."
            Write-LogToFile $progressLog

            Write-Error -Message "Error: One or more folders were not found. Please verify parameters." -Category ObjectNotFound -ErrorAction Stop
        }

        # Get the files that will be transferred from the source folder
        $filesToTransfer = Get-ChildItem $hashFolders.source 

        if($filesToTransfer.Length -eq 0){

            # If no files were found note the log file and end the function
            $progressLog += "Info: There is no files to move. This script is ending."
            Write-LogToFile $progressLog
            return 0
        }

        if($DataAge -ne $null){

            # If the DateAge is provided then get only the files that match the date.
            # Ensure there is no NAV files in there as NAV files do not follow the same aging rules.
            $filesToTransfer = $filesToTransfer | 
                Where-Object {$_.LastWriteTime -gt $DataAge} | 
                Where-Object {$_.Name -notLike "NAV_*"}

            $progressLog += "Info: dataAge has been provided. Only files modified after $DataAge will be transferred."
        }

        if($TeeDataFolder.Length -gt 0){

            # If a teeDataFolder has been provided 
            $progressLog += "Info: DataTee enabled. Copying $($filesToTransfer.Length) files from $($hashFolders.Source) to Destination $($hashFolders.cDestination)"

            try {
                if($PSCmdlet.ShouldProcess($LocalFolder, "Create DataTee to $($hashFolders.cDestination)"){
                    # Start copying the items from the source location to the datatee location
                    Copy-Item $filesToTransfer.FullName -Destination $hashFolders.cDestination -ErrorAction Stop
                }

                # Note the number of files that were copied. 
                $progressLog += "Info: DataTee copy complete. $($filesToTransfer.Length) files copied."
            }
            catch {
                # Catch any errors during the copying of data.
                
                $progressLog += "Error: $($_.Exception.Message)" 
                Write-LogToFile $progressLog

                Write-Error -Message "Error: $($_.Exception.Message)" -ErrorAction Stop
            }
        }

        # Load WinSCP .NET assembly
        try {
            # Attempt to load WinSCPnet.dll
            Add-Type -Path $WinScpDllPath
            $progressLog += "Info: WinSCP dll loaded."
        } # endtry
        catch {
            # If the dll is unable to be loaded
            # Log it, export the log and end the function
            $progressLog +="Error loading WinSCP dll: $($Error[0].Exception.Message)"
            Write-LogToFile $progressLog

            Write-Error "Error loading WinSCP dll: $($Error[0].Exception.Message)" -Category ObjectNotFound -ErrorAction Stop
        } # endcatch
 
        # Setup session options
        $sessionOptions = New-Object WinSCP.SessionOptions -Property @{                                         
            Protocol = [WinSCP.Protocol]::Sftp
            HostName = $ComputerName
            UserName = $Username
            Password = $Password
            SshHostKeyFingerprint = $SshHostKey
        } # endSessionOptions
 
        if($PSCmdlet.ShouldContinue($LocalFolder, "Transfer data in $($hashFolders.source) to $($remotePath)")){
            $session = New-Object WinSCP.Session
            $remotePath = $hashFolders.remoteDestination
    
            try
            {
                try{ # Attempt to open a connection.
                    $session.SessionLogPath = "$LogFilePath\Session_$(Get-date -Format MMddyyyy-hhmm).log"
                    $session.Open($sessionOptions)
                    $progressLog += "Info: WinSCP Session opened. Log found in $LogFilePath\Session_$(Get-date -Format MMddyyyy-hhmm).log"
                } # endtry
                catch{ # Exit the script block if there is an error making a connection.
                    $progressLog += "Error: $($Error[0].Exception.Message)"
                    Write-LogToFile $progressLog
                    
                    Write-Error -Exception "Error: $($Error[0].Exception.Message)" -Category ConnectionError -ErrorAction Stop
                } # endcatch
    
                # Ensure the remote folder exists.
                if(!($session.FileExists($remotePath))){
                    # Exit the script block if the remote folder cannot be found. 
                    $progressLog += "Error: $($remotePath) was not found."
                    Write-LogToFile $progressLog
                    
                    Write-Error -Message "Error: $($remotePath) was not found." -Category ObjectNotFound -ErrorAction Stop 
                } # endif
    
                $progressLog += "Info: $($remotePath) found. Transferring $($filesToTransfer.count) to $($remotePath) on $($ComputerName)."
     
                # Upload files
                foreach($file in $filesToTransfer) {
    
                    try {
                        $transferResult = $session.PutFiles(        
                                                $file.FullName,    # Local Path from parameter
                                                $remotePath,       # Remote Path from Parameter
                                                $move)             # Switch to indiate if the files must be moved or copied.
                        
                        $transferResult.Check()
    
                        foreach($transfer in $transferResult.Transfers){
                            $progressLog += "Info: $($transfer.Filename) was uploaded successfully."
                        }
                    }
                    catch [Exception] {
                        $progressLog += "Error: $($file.FullName) failed to upload - $($_.Exception.Message)"
                    }   
                }
    
                $progressLog += "Info: All files have been transferred."
            } # endtry
            catch [Exception] {
                # if there is any errors that were not caught return them and exit the scriptblock.
                $progressLog +=  ("Error: During upload {0}" -f $_.Exception.Message)
                Write-LogToFile $progressLog
                
                Write-Error -Message ("Error: During upload {0}" -f $_.Exception.Message) -ErrorAction Stop
            } # endcatch
            finally {
                # Disconnect, clean up
                $session.Close()
                $session.Dispose()
            } # endfinally
        }

        Write-LogToFile $progressLog
    }
}