# On module load:

function Get-AIProfilerHandlerExePath {
    $HandlerPartialPath = [IO.Path]::Combine("ApplicationInsightsProfiler", "ApplicationInsightsProfiler-Handler.exe")
    
    $HandlerPathCandidates = @(
        [IO.Path]::Combine($PSScriptRoot, $HandlerPartialPath), # Prefer to use a local subdirectory if any.
        [IO.Path]::Combine([IO.Path]::GetFullPath("/"), $HandlerPartialPath) # Fallback to a directory in the volume root (typically C:\).
    )
    foreach ($HandlerPathCandidate in $HandlerPathCandidates) {
        if ([IO.File]::Exists($HandlerPathCandidate)) {
            return $HandlerPathCandidate
        }
    }

    throw ("Can't find handler executable. Considered:`n{0}" -f ([String]::Join("`n", $HandlerPathCandidates)))
}

$script:ProfilerHandlerExePath = Get-AIProfilerHandlerExePath
$script:ProfilerDataDirectoryPath = [IO.Path]::Combine($env:ProgramData, "ApplicationInsightsProfiler")
$script:ProfilerConfigPath = [IO.Path]::Combine($script:ProfilerDataDirectoryPath, "Config.json")



# Public:

function Set-AIProfilerConfiguration {
    Param(
        [string][Parameter(mandatory=$true)] $InstrumentationKey,
        [string] $LogFolder
    )

    if ([String]::IsNullOrWhiteSpace($InstrumentationKey)) {
        throw [ArgumentException]::new("Missing instrumentation key argument to config AI Profiler.")
    }
    if ([String]::IsNullOrWhiteSpace($LogFolder)) {
        $LogFolder = [IO.Path]::Combine([IO.Path]::GetTempPath(), "ApplicationInsightsProfiler")
    }

    New-DirectoryRecursive $LogFolder | Out-Null
    New-DirectoryRecursive $script:ProfilerDataDirectoryPath | Out-Null

    [IO.File]::WriteAllText($script:ProfilerConfigPath,
        ("{{ ""Args"": [""--ikey"", ""{0}"", ""-m"", ""Default""], ""LogFolder"": ""{1}"" }}" -f @($InstrumentationKey, $LogFolder.Replace("\", "\\"))))
}



function Get-AIProfilerConfiguration {
    return ([IO.File]::ReadAllText($script:ProfilerConfigPath))
}


function Start-AIProfiler {
    Param(
        [switch] $Detached,
        [switch] $EnableIISHttpTracing
    )
    if (-not [IO.File]::Exists($script:ProfilerConfigPath)) {
        throw "Please run Set-AIProfilerConfiguration first."
    }
    if ($EnableIISHttpTracing) {
        Enable-WindowsOptionalFeature -FeatureName IIS-HttpTracing -Online -All
    }
    if ($Detached) {
        Start-Process -FilePath $script:ProfilerHandlerExePath -ArgumentList "--bootstrap" -WindowStyle Hidden
    }
    else {
        . $script:ProfilerHandlerExePath --bootstrap
    }
}


function Stop-AIProfiler {
    . $script:ProfilerHandlerExePath --disable
}


function Uninstall-AIProfiler {
    . $script:ProfilerHandlerExePath --uninstall
}


function Get-AIProfilerStatus {
    $Status = @()
    
    $Status += "Finding profiler related processes."
    $ProfilerProcesses = @(Get-Process -Name "*ApplicationInsightsProfiler*")
    if ($ProfilerProcesses.Count -eq 0) {
        $Status += "No profiler related processes running."
    }
    else {
        foreach ($ProfilerProcess in $ProfilerProcesses) {
            $Status += ("Id: {0}, Name: {1}, StartTime (UTC): {2}." `
                -f @($ProfilerProcess.Id, $ProfilerProcess.ProcessName, $ProfilerProcess.StartTime.ToUniversalTime()))
        }
    }

    $Status += "`nFinding the latest bootstrap log file."
    try {
        $Status += Get-AIProfilerLatestLogFileContents -BaseName Bootstrap
    }
    catch {
        $Status += $_.ToString()
    }

    return $Status
}


function Get-AIProfilerLatestLogFileContents {
    Param(
        [string][Parameter(mandatory=$true)][ValidateSet("Bootstrap", "Disable", "Uninstall")] $BaseName
    )
    $LogFolder = (ConvertFrom-Json (Get-AIProfilerConfiguration)).LogFolder
        
    $LogFiles = @(@(dir ([IO.Path]::Combine($LogFolder, "$BaseName*.log"))) | Sort-Object -Property CreationTimeUTC -Descending)
    foreach ($LogFile in $LogFiles) {
        # The last created log file might not be the one representing the running profiler.
        $LogContents = Get-Content $LogFile.FullName
        if (-not ($LogContents.Contains("There are other processes executing this same operation"))) {
            return $LogContents
        }
    }

    throw [InvalidOperationException]::new("Can't find a log file for $BaseName.")
}



# Private:

function New-DirectoryRecursive {
    Param(
        [string] $DirectoryPath
    )
    if ([String]::IsNullOrWhiteSpace($DirectoryPath)) {
        return
    }
    New-DirectoryRecursive ([IO.Path]::GetDirectoryName($DirectoryPath))
    if (-not [IO.Directory]::Exists($DirectoryPath)) {
        [IO.Directory]::CreateDirectory($DirectoryPath)
    }
}


Export-ModuleMember -Function Set-AIProfilerConfiguration
Export-ModuleMember -Function Get-AIProfilerConfiguration
Export-ModuleMember -Function Start-AIProfiler
Export-ModuleMember -Function Stop-AIProfiler
Export-ModuleMember -Function Uninstall-AIProfiler
Export-ModuleMember -Function Get-AIProfilerStatus
Export-ModuleMember -Function Get-AIProfilerLatestLogFileContents