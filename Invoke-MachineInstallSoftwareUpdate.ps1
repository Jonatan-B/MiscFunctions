function Invoke-MachineInstallSoftwareUpdate {
    <#
    .SYNOPSIS
    This function will install all available SCCM software updates on the given server(s).
    
    .DESCRIPTION
    This function will install available SCCM software updates by invoking the WmiMethod InstallUpdates from the CCM_SoftwareUpdatesManager class. It is also possible to only install
    the certain updates by using the ArticleID parameter.
    
    .PARAMETER ComputerName
    The name of the computer, or computers, where the software update installation will be performed.
    
    .PARAMETER ArtileID
    The article ID, or Ids, (KB#####) of the software update that should be installed.
    
    .EXAMPLE
    Invoke-CMInstallSoftwareUpdate -ComputerName Computer1, Computer2

    OUTPUT:
    No output
    
    .NOTES
    General notes
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName="AllUpdates")]
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
        $ArtileID
    )
    process {
        foreach($Computer in $ComputerName){
            Write-Verbose -Message "Gathering Updates computer $($Computer)."
            if($PSCmdlet.ParameterSetName -eq "SpecificUpdates"){
                Write-Verbose -Message "The parameter -ArticleId has been used. Gathering only the specified updates."
                $AvailableSoftwareUpdates = @()
                foreach($Update in $ArtileID){
                    $Update = Get-WmiObject -Namespace root\ccm\clientSDK -Class CCM_SoftwareUpdate -ComputerName $Computer -Filter "ArticleID=$($Update.Remove(0,2))"
                    if($Update){
                        Write-Verbose -Message "A Software Update with ID $($Update) has been found."
                        $AvailableSoftwareUpdates += $Update
                    }
                    else {
                        Write-Warning -Message "A Software Update with ID $($Update) has not been found."
                    }
                }
            }
            else {
                Write-Verbose -Message "The -ArticleID parameter has not been used. All Updates will be gathered."
                $AvailableSoftwareUpdates = Get-WmiObject -Namespace root\ccm\clientSDK -Class CCM_SoftwareUpdate -ComputerName $Computer
            }

            Write-Verbose -Message "The following updates will be installed:"
            $AvailableSoftwareUpdates | ForEach-Object { Write-Verbose -Message "Name - $($_.Name)"}
            
            if($PSCmdlet.ShouldProcess($Computer, "Install $($AvailableSoftwareUpdates.Count) SCCM Software Updates")){ 
                
                try {   
                    Invoke-WmiMethod -ComputerName $Computer -Namespace root\ccm\clientSDK -Class CCM_SoftwareUpdatesManager -Name InstallUpdates -ArgumentList @(, $AvailableSoftwareUpdates) -ErrorAction Stop | Out-Null
                    Write-Verbose -Message "Installation started successfully. You can check the installation status with the Get-MachineSoftwareUpdate cmdlet."
                }
                catch {
                    Write-Error -Message "Unable to start the installations on server $($Computer). Error: $($_.Exception.Message)"
                }
            }
        }
    }
}