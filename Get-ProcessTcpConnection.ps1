function Get-ProcessTcpConnection {
    <#
    .SYNOPSIS
    This Function will gather connection information on a remote server, and return them sorted by number of connections.
    
    .DESCRIPTION
    This function will invoke a scriptblock that will gather all of the current TCP connections. It will then group the connections by ProcessID and will output the grouping. It will also find the name of the process based on the ID, as this is not given by default.
    
    .PARAMETER ComputerName
    The name of the computer that the command will be run against.
    
    .EXAMPLE
    Get-ProcessTcpConnections -ComputerName server.domain.local | Format-Table -AutoSize
    
        Expected Output:
        ProcessName       ProcessID Bound Listen Established TimeWait TotalConnections MaxPorts
        -----------       --------- ----- ------ ----------- -------- ---------------- --------
        Idle              0             0      0           0       77               77    16384
        svchost           824           7      0           7        0               14    16384
        System            4             0      0          13        0               13    16384
        svchost           556           4      0           4        0                8    16384
        lsass             724           0      4           0        0                4    16384
        svchost           980           0      2           1        0                3    16384
        splunk-winevtlog  3800          3      0           0        0                3    16384
        plasrv            10564         0      2           0        0                2    16384
        CcmExec           788           1      0           1        0                2    16384
        wininit           624           0      2           0        0                2    16384
        svchost           3260          0      2           0        0                2    16384
        services          712           0      2           0        0                2    16384
        svchost           928           0      2           0        0                2    16384
        spoolsv           1360          0      2           0        0                2    16384
        SCNotification    40304         0      1           0        0                1    16384
    #>
    param(
        # ComputerName of the Server to get the current connections on
        [Parameter(Mandatory, Position=0)]
        [String]
        $ComputerName
    )

    # Script black that will run in the remote machine.
    $myScriptBlock = [scriptblock]{
        # First we'll get all of the current TCP Connections on the server.
        $connections = Get-NetTCPConnection

        if($connections){     # This is simply to ensure that a result was provided by Get-NetTCPConnection

            # Gather the maximum number ephemeral ports on the server as these are the ones used for external connections
            $maxNumberOfPorts = (( Get-NetTCPSetting ).DynamicPortRangeNumberOfPorts | 
                Sort-Object -Descending)[0]
            # Get the starting port of the Dynamic Port range.
            $startPortRange = (( Get-NetTCPSetting ).DynamicPortRangeStartPort | 
                Sort-Object -Descending)[0]
        
            # Select only the outgoing connections.
            $OutboundConnections = $connections | 
                Where-Object { $_.LocalPort -in $startPortRange..($startPortRange+$maxNumberOfPorts)}
            
            $Properties = @(
                @{n="ProcessName";e={(Get-Process -Id $_.Name).Name}},
                @{n="ProcessID";e={$_.Name}},
                @{n="Bound";e= {($_.Group | Group-Object -Property State | Where-Object Name -eq "Bound").Count }},
                @{n="Listen";e= {($_.Group | Group-Object -Property State | Where-Object Name -eq "Listen").Count }},
                @{n="Established";e= {($_.Group | Group-Object -Property State | Where-Object Name -eq "Established").Count }},
                @{n="TimeWait";e= {($_.Group | Group-Object -Property State | Where-Object Name -eq "TimeWait").Count }},
                @{n="MaxPorts";e={ $maxNumberOfPorts }},
                @{n="TotalConnections";e={ $_.Count }}
            )
            # Group the connections by process, format the returning object and sort the results by the number of connections on the process.
            $OutboundConnections | 
                Group-Object -Property OwningProcess | 
                Select-Object -Property $Properties | 
                Sort-Object -Property TotalConnections -Descending
        }
    }

    # Print out the report.
    Invoke-Command -ComputerName $ComputerName -ScriptBlock $myScriptBlock | 
        Select-Object ProcessName, ProcessId, Bound, Listen, Established, TimeWait, TotalConnections, MaxPorts
}
