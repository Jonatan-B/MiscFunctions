function Get-MachinePendingRebootStatus {
    <#
    .SYNOPSIS
    Function to query if a computer is pending reboot.
    
    .DESCRIPTION
    Function to query if a computer is pending reboot after an SCCM deployment has been done on the machine. 
    
    .PARAMETER ComputerName
    The name of the computer that will be queried. This can be an array and the cmdlet will loop through each one and find the information.
    
    .EXAMPLE
    Get-MachinePendingRebootStatus -ComputerName CH2-Worker3

    OUTPUT:
    True
    
    .NOTES
    - Requires that the SCCM client is installed on the computer and that a deployment has been made to the computer.
    #>
    param(
        # Name of the computer(s) that will need to be checked for pending reboot status.
        [Parameter(Mandatory=$true, Position=0)]
        [ValidateScript({Test-NetConnection -ComputerName $_ -Port 135 -InformationLevel Quiet})]
        [String[]]
        $ComputerName
    )
    begin{
        $WmiMethodParams = @{
            NameSpace='ROOT\CCM\ClientSDK'
            Class='CCM_ClientUtilities'
            Name='DetermineIfRebootPending'
            ComputerName=$ComputerName
            ErrorAction='Stop'
        }
    }
    process {
        Invoke-WmiMethod @WmiMethodParams | Select-Object -ExpandProperty RebootPending
    }
}