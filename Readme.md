# Overview:

[Application Insights Profiler](https://docs.microsoft.com/en-us/azure/application-insights/enable-profiler-cloud-services)
typically runs as part of the [Windows Azure Diagnostics](https://docs.microsoft.com/en-us/azure/monitoring-and-diagnostics/azure-diagnostics) (WAD).  

This shows how to install and manage AI Profiler on any other environment where the user has administrator access.


# Disclaimer:

This is not an officially supported Microsoft solution.
Microsoft is not responsible for supporting bug tickets or evolving features on this code.


# How to use:

In a PowerShell console, as administrator:

```powershell
Import-Module ./AIProfiler.psm1

# Before starting, prepare the environment with my settings.
# This guid should be instrumentation key for the Application Insights instance my web application is configured to use.
Set-AIProfilerConfiguration -InstrumentationKey "00000000-0000-0000-0000-000000000000" -LogFolder "C:\Logs"

# Start AI Profiler without blocking this console.
# Since my web application is meant to run on IIS, I also want to enable tracing as part of the Start.
Start-AIProfiler -Detached -EnableIISHttpTracing

# Wait some time for everything to bootstrap
sleep 10

# Is Profiler really running?
Get-AIProfilerStatus

# I don't want Profiler processes to be running on this system anymore.
Stop-AIProfiler

# Now I don't want the system changes Profiler did on this system.
Uninstall-AIProfiler
```


# Limitations:

On a system restart, Profiler will not be automatically enabled again.
This is because there's no Windows service to bring AI Profiler up.  

What this means is that you'll need to run this again:

```powershell
Start-AIProfiler -Detached
```