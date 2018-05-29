# Windows-Summary.ps1
# General Variables and Functions
$verScript = "1.6"; $dateNow = Get-Date -format "yyyy-MM-dd"; $dateStr = $dateNow.ToString(); $verobjW2K8 = new-object -typename System.Version 6,0,6001,18000; $currNET = [environment]::version.tostring(); $currPS = ((Get-Host).version).Major;
# Operating System details
$hostCS = gwmi Win32_ComputerSystem; $hostOS = gwmi win32_operatingsystem; $hostHW = get-wmiobject win32_bios; $hostOSstat = $hostOS.Name.Split("|"); $hostOSWinName = $hostOSstat[0]; $hostOSDir = $hostOSstat[1]; $hostOSPart = $hostOSstat[2]; $hostOSFullVersion = [System.Environment]::OSVersion.Version.tostring(); $hostOSVersionObj = New-Object -typename System.Version -argumentlist $hostOSFullVersion; 
[int]$NumRole = $hostCS.domainrole;
switch($NumRole)
{
  0 { $role = "Standalone Workstation" }
  1 { $role = "Member Workstation" }
  2 { $role = "Standalone Server" }
  3 { $role = "Member Server" } 
  4 { $role = "Backup Domain Controller" }
  5 { $role = "Primary Domain Controller" }
} 

$CPUs=@((Get-WmiObject -class win32_processor));
$countCPU=0;
foreach ($CPU in $CPUs) { $countCPU++ }

$logicalCPUs=@((Get-WmiObject -class win32_processor).NumberOfLogicalProcessors);
$countlCPU=0;
foreach ($lCPU in $logicalCPUs) { $countlCPU = $countlCPU + $lCPU }

$coresCPUs=@((Get-WmiObject -class win32_processor).numberOfCores);
$countCores=0;
foreach ($core in $coresCPUs) { $countCores= $countCores + $core }

if ($hostOS.OSArchitecture) { $hostOSArchitecture = $hostOS.OSArchitecture; } else { $testWin32 = [IntPtr]::size -eq 4; if ($testWin32) { $hostOSArchitecture = "32-bit" } else { $hostOSArchitecture = "Unknown" } } $hostTotalPhysGBMemory = [math]::round(($hostCS.TotalPhysicalMemory/1GB),2); if ($hostOS.PAEEnabled) {$hostOSPAEEnabled = $hostOS.PAEEnabled } else { $hostOSPAEEnabled = "False" } $hostSummary = new-object psobject; 

$hostSummary | add-member noteproperty "Computer Name" $hostOS.CSName;
$hostSummary | add-member noteproperty "Cores" $countCores;
$hostSummary | add-member noteproperty "Description" $hostOSDescription;
$hostSummary | add-member noteproperty "Domain" $hostCSDomain; 
$hostSummary | add-member noteproperty "GB Memory" $hostTotalPhysGBMemory;
$hostSummary | add-member noteproperty "OS Architecture" $hostOSArchitecture;
$hostSummary | add-member noteproperty "OS Build" $hostOS.BuildNumber;
$hostSummary | add-member noteproperty "OS Directory" $hostOSDir;
$hostSummary | add-member noteproperty "OS PAE" $hostOSPAEEnabled;
$hostSummary | add-member noteproperty "OS Service Pack Level" $hostOS.CSDVersion;
$hostSummary | add-member noteproperty "OS Service Pack" $hostOS.ServicePackMajorVersion;
$hostSummary | add-member noteproperty "OS Service Pack Minor" $hostOS.ServicePackMinorVersion;
$hostSummary | add-member noteproperty "OS Sub-Type" $hostOSWinName;
$hostSummary | add-member noteproperty "OS Version Revision" $hostOSFullVer;
$hostSummary | add-member noteproperty "OS Version" $hostOS.Version;
$hostSummary | add-member noteproperty "Last Bootup" $hostOS.ConvertToDateTime($hostOS.LastBootUpTime);
$hostSummary | add-member noteproperty "Logical Processors" $countlCPU;
$hostSummary | add-member noteproperty "Manufacturer" $hostCS.Manufacturer;
$hostSummary | add-member noteproperty "Model" $hostCS.Model;
$hostSummary | add-member noteproperty "Processors" $countCPU;
$hostSummary | add-member noteproperty "Role" $role; 
$hostSummary | add-member noteproperty "Serial Number" $hostHW.SerialNumber;

"== $(($hostOS).CSName) CONFIGURATION SUMMARY =="; "`nGenerated on $dateStr by Windows-Summary ver $verScript"; $hostSummary | fl;
# Pagefile and Disk Resources
"`n === PAGE FILE "; $PageFileUse = Get-WmiObject Win32_PageFileUsage; $PageFileUse | select Name, FileSystem, @{Name="Allocated_GB";Expression={[math]::round(($_.AllocatedBaseSize/1000),1)}}, @{Name="Peak_GB";Expression={[math]::round(($_.PeakUsage/1000),1)}} | fl;
"`n === STORAGE DISKS === `n"; $allDrives = get-wmiobject Win32_Volume | ?{($_.filesystem -ne "") -and ($_.capacity -gt 0)} | sort driveletter | select @{Name="Drive";Expression="driveLetter"}, Label, FileSystem, @{Name="Free_GB";Expression={[math]::round(($_.FreeSpace/1GB),1)}}, @{Name="%_Used";Expression={[math]::round(((($_.Capacity - $_.FreeSpace)/$_.Capacity)*100),1)}}; $allDrives | ft -auto;
# Readout .Net environment
"`n === NET ENVIRONMENT ===  `n"; "NET Framework in Use : $currNET";
# Readout Powershell environment
"`n === POWERSHELL ENVIRONMENT ===  `n"; "Powershell Version: $currPS"; $currPSPolicy = get-executionpolicy; "Execution Policy in Effect : $currPSPolicy";
# Membership of (local) Administrators security group
"`n === ADMINISTRATORS ===  `n"; $groupAdmin = [ADSI]("WinNT://./Administrators,group"); $membersAdmin = $groupAdmin.psbase.invoke("Members"); $membersAdmin | ForEach-Object {$_.GetType().InvokeMember("Name",'GetProperty', $null, $_, $null) }
# List installed Windows software
"`n === SOFTWARE INSTALLED "; if (((Get-Host).version).Major -ge 2) { gwmi -class 'win32_Product' | select Name, Version | sort-object Name | ConvertTo-HTML -fragment; } else { gwmi -class 'win32_Product' | select Name, Version | sort-object Name | ft -auto; }
# List all Services
"`n === SERVICES ==="; if (((Get-Host).version).Major -ge 2) { gwmi win32_service | select Displayname, Name, ProcessID, StartMode, Started, State, Status, StartName | sort-object -Unique Displayname | ConvertTo-HTML -fragment; } else { gwmi win32_service | select Name, StartMode, State, Status, StartName | sort-object -Unique Name | ft -auto; }
# Windows Scheduler Tasks
"=== SCHEDULED TASKS ===  `n"; if (((Get-Host).version).Major -ge 2) { schtasks.exe /query /fo csv | ConvertFrom-CSV | ?{($_.taskname -notlike '*Microsoft\Windows*') -and ($_.taskname -ne 'TaskName')} | ConvertTo-HTML -fragment } else { schtasks.exe /query /fo csv | select-string "^(?!.*Taskname)" }
# networking configs and stats
"`n === NETWORK ADAPTER CONFIGS "; ipconfig /all
"`n === NETWORK STATS ===  `n"; netstat -se
"`n === STATIC ROUTES ===  `n"; route print
"`n === OPEN LISTENING PORTS ===  `n"; netstat -an
"`n === NETBIOS RESOLUTIONS "; nbtstat -r
# readout entries in hosts and lmhosts
"`n === HOST DEFINITONS ===  `n"; if (((Get-Host).version).Major -ge 2) { get-content "$($hostOSDir)\system32\drivers\etc\hosts" | select -skip 18 ; } else { get-content "$($hostOSDir)\system32\drivers\etc\hosts" ; }
"`n === LMHOSTS DEFINITIONS ===  `n"; if (test-path "$($hostOSDir)\system32\drivers\etc\lmhosts") { get-content "$($hostOSDir)\system32\drivers\etc\lmhosts" ; } else { "File lmhosts not used on this server."; }
# readout windows firewall rules, exceptions
"`n === FIREWALL RULES ===  `n"; if ($hostOSVersionObj -ge $verobjW2K8) { netsh advfirewall show allprofiles } else { netsh firewall show opmode }
