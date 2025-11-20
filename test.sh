# This script collects information about a machine running on Windows OS
cd C:\Users\Administrator\scripts

# Collect system‑wide info once
$INFO = Get-ComputerInfo -Property CsTotalPhysicalMemory,CsProcessors,OsName

# Start a new data file with hostname
hostname | Set-Content inventory_win.data

# Date
Get-Date -Format "dd.MM.yyyy" | Add-Content inventory_win.data

# MAC addresses
$macs = ((Get-NetAdapter).MacAddress) -replace '-',':'
(-split $macs) -join ";" | Add-Content inventory_win.data

# IP addresses (preferred, valid ≤ 24 h)
$IP = (Get-NetIPAddress | Where-Object {
    $_.AddressState -eq "Preferred" -and $_.ValidLifetime -lt "24:00:00"
}).IPAddress
(-split $IP) -join " " | Add-Content inventory_win.data 

# Motherboard model
$mthbrd = Get-CimInstance -Class Win32_BaseBoard
$mthbrd.Product | Add-Content inventory_win.data

# RAM by slots
$ram  = (Get-WmiObject win32_physicalmemory).Capacity
$ramd = foreach ($r in $ram) { [int]($r/1gb) }
(-split $ramd) -join "|" | Add-Content inventory_win.data

# Total RAM
[int]($INFO.CsTotalPhysicalMemory/1gb) | Add-Content inventory_win.data

# CPU model
$INFO.CsProcessors.Name | Add-Content inventory_win.data

# CPU logical threads
$INFO.CsProcessors.NumberOfLogicalProcessors | Add-Content inventory_win.data

# Storage sizes
$sizes = (Get-PhysicalDisk).Size
$size  = foreach ($a in $sizes) { [int]($a/1gb) }
(-split $size) -join ";" | Add-Content inventory_win.data

# GPU model
$gpu_model = Get-WmiObject win32_VideoController
$gpu_model.Caption | Add-Content inventory_win.data

# OS name
$INFO.OsName | Add-Content inventory_win.data



# ---------------- Battery information ----------------
# First: check if the system actually has a battery
$batteries = Get-WmiObject -Class Win32_Battery -ErrorAction SilentlyContinue

if (!$batteries -or $batteries.Count -eq 0) {
    # Desktop / server — no battery present
    "Battery: not present" | Add-Content -Path "C:\Users\Administrator\scripts\inventory_win.data" -Encoding utf8
}
else {
    # Battery exists → continue with the original logic
    $batteryStaticData = Get-WmiObject -Namespace root\wmi -Class BatteryStaticData

    $batteryStatuses = ""

    foreach ($battery in $batteries) {
        # Find the corresponding BatteryStaticData entry
        $staticData = $batteryStaticData | Where-Object { $_.UniqueID -eq $battery.DeviceID }

        if ($staticData -ne $null) {
            # Extract values
            $fullChargedCapacity = (
                Get-WmiObject -Namespace root\wmi -Class BatteryFullChargedCapacity |
                Where-Object { $_.InstanceName -eq $staticData.InstanceName }
            ).FullChargedCapacity
            $designedCapacity = $staticData.DesignedCapacity

            if ($fullChargedCapacity -ne $null -and $designedCapacity -ne $null) {
                # Calculate percentage and status
                $capacityPercentage = ($fullChargedCapacity / $designedCapacity) * 100
                if ($capacityPercentage -gt 70) {
                    $status = "excellent"
                } elseif ($capacityPercentage -gt 40) {
                    $status = "good"
                } else {
                    $status = "fair"
                }

                $batteryStatuses += "$status ($([math]::Round($capacityPercentage, 2))%)"

                # Add comma if not the last battery
                if ($batteries.Count -gt 1 -and $batteries.IndexOf($battery) -lt ($batteries.Count - 1)) {
                    $batteryStatuses += ", "
                }
            } else {
                $batteryStatuses += "Battery information missing for battery $($battery.DeviceID)"
            }
        } else {
            $batteryStatuses += "Battery data not found for $($battery.DeviceID)"
        }
    }

    # Write the battery statuses to the file
    $batteryStatuses | Add-Content -Path "C:\Users\Administrator\scripts\inventory_win.data" -Encoding utf8
}
# ------------------------------------------------------


