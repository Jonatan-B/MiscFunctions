function Test-NetTcpPortsConnection {
    <#
    .SYNOPSIS
    This function performs icmp and port scan on a given computer name.

    .DESCRIPTION
    This function will perform icmp test and async port scan on a given computer name.

    .PARAMETER ComputerName
    The name of the computer, or computers, that will be scanned.

    .PARAMETER Ports
    The ports that we want to scan, default is 20,21,22,23,25,53,80,123, 135,137,161,389,443,636

    .PARAMETER QuickScan
    If this option is used the cmdlet discard the list Ports parameters, and will only scan 80, 443, 135.

    .PARAMETER NoICMP
    IF this option is used the cmdlet will not perform an ICMP test.

    .EXAMPLE
    Test-NetTcpPortsConnection -ComputerName 10.2.1.34

    OUTPUT:

    ComputerName : 10.2.1.34
    ICMP         : True
    Port 443     : Open
    Port 135     : Open
    Port 636     : Closed
    Port 389     : Closed
    Port 80      : Open
    Port 161     : Closed
    Port 123     : Closed
    Port 137     : Closed
    Port 53      : Closed
    Port 25      : Closed
    Port 23      : Closed
    Port 22      : Closed
    Port 21      : Closed
    Port 20      : Closed

    .EXAMPLE
    Test-NetTcpPortsConnection -ComputerName server-web01 -Ports 80, 443

    OUTPUT:

    ComputerName ICMP Port 443 Port 80
    ------------ ---- -------- -------
    server-web01  True Open     Open

    .EXAMPLE
    Test-NetTcpPortsConnection -ComputerName 10.2.1.34, server1 -QuickScan -NoICMP

    OUTPUT:

    ComputerName : 10.2.1.34
    ICMP         : Supressed
    Port 135     : Open
    Port 443     : Open
    Port 80      : Open

    ComputerName : server1
    ICMP         : Supressed
    Port 135     : Open
    Port 443     : Open
    Port 80      : Open
    #>
    param(
        # The network that you want to search on.
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [String[]]
        $ComputerName,
        # Ports to Scan for connectivity. Default are 20,21,22,23,25,53,80,123,137,161,389,443,636
        [Parameter(ValueFromPipelineByPropertyName)]
        [Int[]]
        $Ports = @(20, 21, 22, 23, 25, 53, 80, 123, 135, 137, 161, 389, 443, 636),
        # Switch used to perform a quick scan
        [Switch]
        $QuickScan,
        # Supress the ICMP results, and perform port scans anyways.
        [Switch]
        $NoICMP

    )

    if ($QuickScan.IsPresent) {
        $Ports = @(80, 443, 135)
    }

    workflow Invoke-WFScanPort {
        param($ComputerName, $Ports)

        foreach -parallel ($port in $Ports) {
            InlineScript {
                $TcpClient = [System.Net.Sockets.TcpClient]::new()
                try {
                    $TcpClient.Connect($using:ComputerName, $using:Port)
                    $TcpClient.Dispose()
                    [ordered]@{"Port $($using:Port)" = "Open"}
                }
                catch {
                    [ordered]@{"Port $($using:Port)" = "Closed"}
                    $TcpClient.Dispose()
                }
            }
        }
    }

    foreach ($Computer in $ComputerName) {
        $PortScanProperties = [ordered]@{
            ComputerName = $Computer
        }

        Write-Verbose -Message "Starting Port Scan sequence for $Computer"
        if ($NoICMP.IsPresent) {
            Write-Verbose -Message "Supressing ICMP test."
            $PortScanProperties.Add("ICMP", "Supressed")
            $ICMPTest = $true
        }
        else {
            Write-Verbose -Message "Testing ICMP Connectiong."
            $ICMPTest = Test-Connection -ComputerName $Computer -Count 1 -Quiet
            $PortScanProperties.Add("ICMP", $ICMPTest)
        }

        Write-Verbose -Message "Performing Port Scans."
        Invoke-WFScanPort -ComputerName $Computer -Ports $Ports | ForEach-Object { $PortScanProperties += $_ }

        New-Object -TypeName PsObject -Property $PortScanProperties
    }
}
