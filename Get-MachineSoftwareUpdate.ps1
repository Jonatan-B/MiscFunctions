function Get-MachineSoftwareUpdate {
    <#
    .SYNOPSIS
    Function to get the updates evaluation status of the available updates on a machine.
    
    .DESCRIPTION
    The function will gather the list of available SCCM software updates on a machine and return its current evaluation status. 
    This information can be used to determine the status of the updates as they are being installed, or to determine if there is 
    updates that require the machine to be rebooted before they are completed.
    
    .PARAMETER ComputerName
    Name of the machine where the information will be gathered. This can be an array and the cmdlet will loop through each one and find the information.
    
    .PARAMETER ArtileID
    Name of specific updates that we want to get information on. This can be an array and the cmdlet will loop through each one and find the information.

    .PARAMETER Overview
    If this parameter is specified the cmdlet will only return the computer name and the current status. Possible outputs are: Not Started, InProgress, PendingReboot
    
    .EXAMPLE
    Get-MachineSoftwareUpdate -ComputerName machinename -ArtileID KB4040685, KB4041693

    OUTPUT:
    ArticleId                   : KB4041693
    Status                      : PendingSoftReboot
    EvaluationState             : 8
    RebootOutsideServiceWindows : False
    OverrideServiceWindows      : False
    URL                         : http://support.microsoft.com/help/4041693
    Name                        : 2017-10 Security Monthly Quality Rollup for Windows Server 2012 R2 for x64-based Systems (KB4041693)
    ComputerName                : machinename

    ArticleId                   : KB4040685
    Status                      : PendingSoftReboot
    EvaluationState             : 8
    RebootOutsideServiceWindows : False
    OverrideServiceWindows      : False
    URL                         : http://support.microsoft.com/kb/4040685
    Name                        : Cumulative Security Update for Internet Explorer 11 for Windows Server 2012 R2 (KB4040685)
    ComputerName                : machinename

    .EXAMPLE
    Get-MachineSoftwareUpdate -ComputerName machinename -ArtileID KB4040685, KB40416934

    OUTPUT:
    WARNING: Update KB40416934 could not be found in the available updates.

    ArticleId                   : KB4041693
    Status                      : PendingSoftReboot
    EvaluationState             : 8
    RebootOutsideServiceWindows : False
    OverrideServiceWindows      : False
    URL                         : http://support.microsoft.com/help/4041693
    Name                        : 2017-10 Security Monthly Quality Rollup for Windows Server 2012 R2 for x64-based Systems (KB4041693)
    ComputerName                : machinename

    .EXAMPLE
    Get-MachineSoftwareUpdate -ComputerName machinename -Overview
    
    OUTPUT:
    ComputerName                : machinename
    InstallationStatus          : InProgress
    
    .NOTES
    - Requires that the SCCM client is installed on the computer and that a deployment has been made to the computer.
    - Only updates that are not compliant will appear in the results.
    #>
    [CmdletBinding(DefaultParameterSetName="AllUpdates")]
    param(
        # Computer where Software Updates will be installed.
        [Parameter(Mandatory, Position=0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateScript({ Test-NetConnection -ComputerName $_ -CommonTCPPort WinRM -InformationLevel Quiet })]
        [String[]]
        $ComputerName,
        # Name of the update that will be installed.
        [Parameter(Position=1, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName="SpecificUpdates")]
        [ValidatePattern("(K|k)(B|b)\d+")]
        [String[]]
        $ArtileID,
        # If this parameter is included only an overall status will be returned instead of each individual update status.
        [Parameter(ParameterSetName="Overview")]
        [Switch]
        $Overview
    )
    begin {
        $EvaluationState = @{
            0 = "None"
            1 = "Available"
            2 = "Submitted"
            3 = "Detecting"
            4 = "PreDownload"
            5 = "Downloading"
            6 = "WaitInstall"
            7 = "Installing"
            8 = "PendingSoftReboot"
            9 = "PendingHardReboot"
            10 = "WaitReboot"
            11 = "Verifying"
            12 = "InstallComplete"
            13 = "Error"
            14 = "WaitServiceWindow"
            15 = "WaitUserLogon"
            16 = "WaitUserLogoff"
            17 = "WaitJobUserLogon"
            18 = "WaitUserReconnect"
            19 = "PendingUserLogoff"
            20 = "PendingUpdate"
            21 = "WaitingRetry"
            22 = "WaitPresModeOff"
            23 = "WaitForOrchestration"
        }
    }
    process {
        foreach($Computer in $ComputerName){
            $AvailableSoftwareUpdates = Get-WmiObject -Namespace root\ccm\clientSDK -Class CCM_SoftwareUpdate -ComputerName $Computer
            if(!($AvailableSoftwareUpdates)){
                Write-Warning "No updates found for server $($Computer)."
                continue
            }

            foreach($Update in $ArtileID){
                if($AvailableSoftwareUpdates.ArticleId -notcontains $Update.Remove(0,2)){
                    Write-Warning -Message "Update $($Update) could not be found in the available updates."
                }
            }

            
            if($PSCmdlet.ParameterSetName -eq "Overview") {
                if(($AvailableSoftwareUpdates.EvaluationState | Where-Object {$_ -notmatch "Reboot"}).Count -eq 0){
                    $ResultsParam = @{
                        ComputerName = $Computer
                        InstallationStatus = "PendingReboot"
                    }
                    New-Object -TypeName PSObject -Property $ResultsParam
                    continue
                }

                if($AvailableSoftwareUpdates.EvaluationState -notcontains 0){
                    $ResultsParam = @{
                        ComputerName = $Computer
                        InstallationStatus = "InProgress"
                    }
                    New-Object -TypeName PSObject -Property $ResultsParam
                    continue
                }
                
                $ResultsParam = @{
                    ComputerName = $Computer
                    InstallationStatus = "Not Started"
                }
                New-Object -TypeName PSObject -Property $ResultsParam
                continue
            }
            
            foreach($SoftwareUpdate in $AvailableSoftwareUpdates){
                $FullArticleName = @{N="ArticleId";E={ "KB$($_.ArticleId)" }}
                $TranslateEvaluationCode = @{N="Status";E={ $EvaluationState.[int]$_.EvaluationState }}
                $ComputerProperty = @{N="ComputerName";E={ $Computer }}

                switch($PSCmdlet.ParameterSetName){
                    "SpecificUpdates" { 
                        if($ArtileID -contains "KB$($SoftwareUpdate.ArticleId)"){    
                            $SoftwareUpdate | Select-Object -Property $FullArticleName, $TranslateEvaluationCode, EvaluationState, RebootOutsideServiceWindows, OverrideServiceWindows, URL, Name, $ComputerProperty
                        }
                    }
                    "AllUpdates" {
                        $SoftwareUpdate | Select-Object -Property $FullArticleName, $TranslateEvaluationCode, EvaluationState, RebootOutsideServiceWindows, OverrideServiceWindows, URL, Name, $ComputerProperty
                    }
                }                
            }
        }
    }
}