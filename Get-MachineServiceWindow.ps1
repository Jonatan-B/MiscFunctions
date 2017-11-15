function Get-MachineServiceWindow {
    <#
    .SYNOPSIS
    This function will query the next Service Window that the machine has scheduled.
    
    .DESCRIPTION
    This function will query the next SCCM Service Window that is currently in the system's configuration.
    
    .PARAMETER ComputerName
    The name of the computer that the cmdlet will be run against.
    
    .PARAMETER NextOnly
    If the parameter is included only the next window will be shown and not all Windows.
    
    .EXAMPLE
    Get-MachineServiceWindow -ComputerName Computer1 -NextOnly

    OUTPUT:
    StartTime       : 12/9/2017 6:00:00 AM
    EndTime         : 12/9/2017 8:00:00 AM
    TypeCode        : 1
    TypeName        : ALLPROGRAM_SERVICEWINDOW
    TypeDescription : All Programs Service Window
    ComputerName    : Computer1.domain.local

    .EXAMPLE 
    Get-MachineServiceWindow -ComputerName Computer1 

    OUTPUT:
    StartTime       : 12/9/2017 6:00:00 AM
    EndTime         : 12/9/2017 8:00:00 AM
    TypeCode        : 1
    TypeName        : ALLPROGRAM_SERVICEWINDOW
    TypeDescription : All Programs Service Window
    ComputerName    : Computer1.domain.local

    StartTime       : 12/9/2017 8:00:00 AM
    EndTime         : 12/9/2017 2:00:00 PM
    TypeCode        : 1
    TypeName        : ALLPROGRAM_SERVICEWINDOW
    TypeDescription : All Programs Service Window
    ComputerName    : Computer1.domain.local
    #>
    [CmdletBinding(DefaultParameterSetName="AllWindows")]
    param(
        # Name of the computer where we want to get the service window information.
        [Parameter(Mandatory, Position=0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [String[]]
        $ComputerName,
        # Use this switch if you would like to only see the next window. Otherwise all Windows will be displayed. 
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName="NextOnly")]
        [Switch]
        $NextOnly
    )
    begin {
        $ServiceWindowType = @{
            1 = @{Name = "ALLPROGRAM_SERVICEWINDOW"; Description = "All Programs Service Window" }
            2 = @{Name = "PROGRAM_SERVICEWINDOW"; Description = "Program Service Window" }
            3 = @{Name = "REBOOTREQUIRED_SERVICEWINDOW"; Description = "Reboot Required Service Window" }
            4 = @{Name = "SOFTWAREUPDATE_SERVICEWINDOW"; Description = "Software Update Service Window" }
            5 = @{Name = "OSD_SERVICEWINDOW"; Description = "OSD Service Window" }
            6 = @{Name = "USER_DEFINED_SERVICE_WINDOW"; Description = "Corresponds to non-working hours." }
        }
    }
    process {
        foreach($Computer in $ComputerName){
            if($PSCmdlet.ParameterSetName -eq "NextOnly"){
                $NextWindowId = Invoke-WmiMethod -ComputerName $Computer -Name root\ccm\clientSDK -Class CCM_ServiceWindowManager -Name GetNextServiceWindowID
                $ServiceWindows = Get-WmiObject -ComputerName $Computer -Namespace root\ccm\clientSDK -Class CCM_ServiceWindow -Filter "ID=$NextWindowID"
            }
            else {
                $ServiceWindows = Get-WmiObject -ComputerName $Computer -Namespace root\ccm\clientSDK -Class CCM_ServiceWindow -Filter "Type=1"
            }

            foreach($Window in $ServiceWindows){
                
                [int]$WindowTypeCode = $Window.Type
                $WindowTypeInformation = $ServiceWindowType.$WindowTypeCode
                
                $ObjProperties = [Ordered]@{
                    StartTime = [DateTime](Get-WmiObject -ComputerName $Computer -Namespace root\ccm\clientSDK -Class CCM_ServiceWindow -Filter "Type=1" | Select-Object -First 1).ConvertToDateTime($Window.StartTime)
                    EndTime = [DateTime](Get-WmiObject -ComputerName $Computer -Namespace root\ccm\clientSDK -Class CCM_ServiceWindow -Filter "Type=1" | Select-Object -First 1).ConvertToDateTime($Window.EndTime)
                    TypeCode = $WindowTypeCode
                    TypeName = $WindowTypeInformation.Name
                    TypeDescription = $WindowTypeInformation.Description
                    ComputerName = $Computer
                }

                New-Object -TypeName PSObject -Property $ObjProperties
            }
        }
    }
}