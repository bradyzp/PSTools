param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$VMName,
    [Parameter(Mandatory)]
    [string]$VMPath,
    [string]$VMSwitch,    
    [string]$VMHost = "localhost",
    [string]$ISOPath,
    [switch]$Running = $false,
    [int]$VMGeneration = 2
)

Configuration MakeVM {
    param (
        [Parameter(Mandatory)]
        [String]$HyperVNode,
        [Parameter(Mandatory)]
        [String]$VMPath,
        [Parameter(Mandatory)]
        [String]$VMName,
        [String]$VMSwitch,
        [int]$Generation = 2
    )
    
    Import-DscResource -ModuleName xHyper-V
    Import-DscResource -ModuleName PSDesiredStateConfiguration

    Node $HyperVNode {

        File VHDDir {
            DestinationPath = "$VMPath\Virtual Hard Disks"
            Ensure = "Present"
            Force = $true
            Type = 'Directory'
        }
        File VMDir {
            DestinationPath = "$VMPath\Virtual Machines"
            Ensure = "Present"
            Force = $true
            Type = 'Directory'
        }

        xVHD NewVHD {
            Ensure = "Present"
            Name = "$VMName.vhdx"
            Path = "$VMPath\Virtual Hard Disks"
            Generation = "Vhdx"
            MaximumSizeBytes = 50GB
            DependsOn = "[File]VHDDir"
        }

        xVMHyperV NewVM {
            Ensure = "Present"
            Name = $VMName
            Path = "$VMPath\Virtual Machines"
            Generation = $Generation
            StartupMemory = 2048MB
            State = "Off"
            ProcessorCount = 4
            SwitchName = $VMSwitch
            VhdPath = "$VMPath\Virtual Hard Disks\$VMName.vhdx"
            DependsOn = @("[xVHD]NewVHD","[File]VMDir")
        }
    }
}

Remove-Item $PSScriptRoot/*.mof -Force

MakeVM -HyperVNode $VMHost -VMPath $VMPath -VMName $VMName -VMSwitch $VMSwitch -Generation $VMGeneration -outputpath $PSScriptRoot
Start-DscConfiguration -Path $PSScriptRoot -Credential (Get-Credential -Message "DSC Config Credential") -Wait -Force -verbose

#Clean up mof file
Remove-Item $PSScriptRoot/*.mof -Force

Remove-Module Hyper-V
Import-Module Hyper-V -RequiredVersion '1.1'

$VM = Get-VM -ComputerName $VMHost -VMName $VMName

if($ISOPath) {
    $VM | Add-VMDvdDrive -ControllerNumber 0 -ControllerLocation 1 -Path $ISOPath
}

$VM | Set-VM -DynamicMemory -MemoryMinimumBytes 1024MB -MemoryMaximumBytes 8192MB

if($Running) {
    $VM | Start-VM -Verbose
}

return $VM