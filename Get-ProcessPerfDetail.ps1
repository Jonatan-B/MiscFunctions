function Get-ProcessPerfDetail {
    <#
    .SYNOPSIS
    This function will gather process performance details on the ComputerName, kind of like the Task Manager.

    .DESCRIPTION
    This function will gather process performance details for the ComputerName including information like CPU%, Memory% p, Virtual Memory, User, Time running and IO information. The function is a
    bit slow when running on a heavily utilized system, like our terminal servers, but otherwise its very useful.

    .PARAMETER ComputerName
    The name of the computer where the process information will be gathered.

    .PARAMETER SortBy
    How the information should be sorted.

    .PARAMETER Wait
    This switch will be used if you want the cmdlet to run on a loop. Clearning the script after each pass, kind of like top in Linux.

    .EXAMPLE
    ⚡ ➜ Get-ProcessDetail -ComputerName server.domain.local -SortBy MEM%

        Name                       PID CPU% User             MEM%     VIR IOR/s  IOW/s Time+
        ----                       --- ---- ----             ----     --- -----  ----- -----
        System                       4    0                     0      28     0      0 14.09:26:49
        conhost                   1708    0 SYSTEM              0     472     0      0 14.09:23:53
        smss                       504    0 SYSTEM              0     212     0      0 14.09:26:49
        Idle                         0 8.33                     0       4     0      0 14.09:26:49
        svchost#3                 3080    0 NETWORK SERVICE  0.01    1048     0      0 14.09:23:46
        svchost#6                24812    0 SYSTEM           0.01    1092     0      0 5.10:53:37
        plasrv                   44852    0 jonatan.bernal   0.01    1152     0      0 7.00:36:04
        VSSVC                     3120    0 SYSTEM           0.01    1416     0      0 14.09:23:45
        csrss                      684    0 SYSTEM           0.01     804     0      0 14.09:26:42
        csrss#1                    620    0 SYSTEM           0.01    1496     0      0 14.09:26:44
        winlogon                   720    0 SYSTEM           0.01     896     0      0 14.09:26:42
        wininit                    692    0 SYSTEM           0.01     864     0      0 14.09:26:42
        WmiPrvSE#2               27896    0 LOCAL SERVICE    0.01    1560     0      0 2.06:30:24
        WmiApSrv                 28956    0 SYSTEM           0.01    1268     0      0 00:02:06
        msdtc                     2380    0 NETWORK SERVICE  0.02    1996     0      0 14.09:21:41
        svchost#5                 2620    0 SYSTEM           0.02    2500     0      0 14.09:23:46
        WmiPrvSE#6               19356    0 SYSTEM           0.02    1688     0      0 00:00:04
        CmRcService              33936    0 SYSTEM           0.02    1968     0      0 2.06:30:24
        WmiPrvSE#7               52572    0 SYSTEM           0.02    2348     0      0 00:00:04
        svchost#4                 1952    0 SYSTEM           0.03    3324     0      0 14.09:23:56
        splunk-winevtlog          3640    0 SYSTEM           0.04    4032     0      0 14.09:23:39
        taskhost                 32304    0 SYSTEM           0.04    4800     0      0 2.06:47:01
        spoolsv                   1488    0 SYSTEM           0.04    4644     0      0 14.09:24:30
        svchost                   1324    0 LOCAL SERVICE    0.05    5552     0      0 14.09:24:31
        rundll32                 29632    0 SYSTEM           0.05    5068     0      0 4.21:02:02
        WmiPrvSE#5                2100    0 SYSTEM           0.05    5216     0      0 14.09:21:44
        services                   784    0 SYSTEM           0.06    6352     0      0 14.09:26:41
        svchost#8                  572    0 SYSTEM           0.06    6800     0      0 14.09:26:35
        svchost#11                 852    0 SYSTEM           0.06    6324     0      0 14.09:26:37
        LogonUI                    992    0 SYSTEM           0.07    7880     0      0 14.09:26:36
        winlogbeat               14792    0 SYSTEM           0.08    9428     0      0 5.03:35:19
        WmiPrvSE#3               43580    0 LOCAL SERVICE    0.08    9064     0      0 4.22:59:08
        svchost#2                  928    0 SYSTEM           0.09    9608     0      0 14.09:23:53
        svchost#7                  592    0 LOCAL SERVICE     0.1   11204     0      0 14.09:26:35
        svchost#9                 2800    0 NETWORK SERVICE   0.1   11404     0      0 14.09:23:47
        dwm                       1008    0 DWM-1            0.12   13700     0      0 14.09:26:36
        metricbeat               44664    0 SYSTEM           0.12   13696     0      0 5.03:35:11
        CcmExec                  32928    0 SYSTEM           0.15   16540     0      0 2.06:30:25
        WmiPrvSE#1                1164  0.5 SYSTEM            0.2   22228     0      0 14.09:21:52
        WmiPrvSE                  4360    0 SYSTEM            0.2   21948     0      0 14.09:15:46
        svchost#10                1020    0 LOCAL SERVICE     0.2   22456     0      0 14.09:26:35
        WmiPrvSE#8                2756    0 NETWORK SERVICE  0.22   23936     0      0 14.09:23:51
        filebeat                 33152    0 SYSTEM           0.23   25060     0      0 5.03:35:08
        svchost#12                 904    0 NETWORK SERVICE  0.29   32340     0      0 14.09:26:37
        svchost#13                 884    0 NETWORK SERVICE  0.44   48684     0      0 14.09:26:34
        splunkd                   1724    0 SYSTEM           0.54   60520     0      0 14.09:23:55
        WmiPrvSE#4               44288 8.33 LOCAL SERVICE    0.72   80012     0      0 4.23:01:50
        svchost#1                  584  0.5 SYSTEM           1.01  112716   333    936 14.09:26:35
        lsass                      792    0 SYSTEM           1.16  128868     0      0 14.09:26:41
    #>
    param(
        [Parameter(Position = 0)]
        [String]
        $ComputerName = [Environment]::MACHINENAME,
        [Parameter(Position = 1)]
        [ValidateSet('CPU%', 'MEM%', 'User', 'Time+', 'PID', 'Name', 'IOR/s', 'IOW/s')]
        [String]
        $SortBy = 'CPU%',
        [Parameter(Position = 2)]
        [Switch]
        $Wait
    )
    $CpuCores = ( Get-WMIObject Win32_ComputerSystem -ComputerName $ComputerName ).NumberOfLogicalProcessors
    $AvailableMemory = ( Get-Counter -Counter "\\$($ComputerName)\Memory\Available Bytes").CounterSamples.CookedValue


    workflow getProcessStatistics {
        param($Processes, $ComputerName)

        foreach -parallel ($Process in $Processes) {
            Get-WmiObject -PSComputerName $ComputerName -Class Win32_PerfFormattedData_PerfProc_Process -Filter "IDProcess=$($process.ProcessId)"
        }
    }

    while ($true) {
        if ([System.Security.Principal.WindowsIdentity]::GetCurrent().Groups -notmatch "S-1-5-32-544") {
            Write-Warning "Not running as Administrator. Might be unable to get the process owner."
        }
        $processes = Get-WmiObject -Class Win32_Process -ComputerName $ComputerName |
            Where-Object Name -ne "Total_" |
            Select-Object ProcessId, @{n = "User"; e = {$_.GetOwner().User}}

        $SelectProperties = @(
            'Name',
            @{N = "PID"; E = { $_.IdProcess} },
            @{N = "CPU%"; E = { [Math]::Round($_.PercentProcessorTime / $CpuCores, 2 )}},
            @{N = "User"; E = { $id = $_.IdProcess; ($processes | Where-Object { $_.ProcessId -eq $id }).User } },
            @{N = "MEM%"; E = { [Math]::Round($_.WorkingSetPrivate / $AvailableMemory * 100, 2) }},
            @{N = "VIR"; E = { $_.WorkingSetPrivate / 1KB }},
            @{N = "IOR/s"; E = { $_.IOReadBytesPersec }},
            @{N = "IOW/s"; E = { $_.IOWriteBytesPersec }},
            @{N = "Time+"; E = { New-TimeSpan -Seconds $_.ElapsedTime }}
        )

        $data = getProcessStatistics -Processes $processes -ComputerName $ComputerName -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ne "_Total" } |
            Select-Object $SelectProperties


        if ($Wait.IsPresent) {
            Clear-Host
            $data | Sort-Object -Property $SortBy | Format-Table -AutoSize
            Start-Sleep -Seconds 5
        }
        else {
            $data | Sort-Object -Property $SortBy | Format-Table -AutoSize
            Break
        }
    }
}
