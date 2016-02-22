param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$VMName,
    [Parameter(Mandatory)]
    [string]$VMPath,
    [string]$VMSwitch,    
    [string]$VMHost = "localhost",
    [string]$ISOPath,
    [switch]$Running = $false
)

Configuration MakeVM {
    param (
        [Parameter(Mandatory)]
        [String]$HyperVNode,
        [Parameter(Mandatory)]
        [String]$VMPath,
        [Parameter(Mandatory)]
        [String]$VMName,
        [String]$VMSwitch
    )
    
    Import-DscResource -ModuleName xHyper-V

    Node $HyperVNode {

        xVHD NewVHD {
            Ensure = "Present"
            Name = "$VMName.vhdx"
            Path = "$VMPath\Virtual Hard Disks"
            Generation = "Vhdx"
            MaximumSizeBytes = 50GB
        }

        xVMHyperV NewVM {
            Ensure = "Present"
            Name = $VMName
            Path = $VMPath
            Generation = 2
            StartupMemory = 2048MB
            State = "Off"
            ProcessorCount = 4
            SwitchName = $VMSwitch
            VhdPath = "$VMPath\Virtual Hard Disks\$VMName.vhdx"
            DependsOn = "[xVHD]NewVHD"
        }
    }
}

Remove-Item $PSScriptRoot/*.mof -Force

MakeVM -HyperVNode $VMHost -VMPath $VMPath -VMName $VMName -VMSwitch $VMSwitch -outputpath $PSScriptRoot
Start-DscConfiguration -Path $PSScriptRoot -Credential (import-clixml "$PSScriptRoot\Creds\administrator.clixml") -Wait -Force -verbose

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