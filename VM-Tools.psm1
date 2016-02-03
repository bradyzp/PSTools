
function Move-VMStorageSynchronous {
    <#
        .SYNOPSIS
            Performs synchornous storage migration of one or more Hyper-V VM's to a target path
        .DESCRIPTION
            The Migrate-VMStorage cmdlet moves the storage (HDD's, snapshots, configuration etc.) associated with one or more Virtual Machines to a specified path.
        .PARAMETER VMName
            Virtual Machine Name, or list of VM Names, wildcards are supported in this field
        .PARAMETER VMs
            VirtualMachine object, or list of Virtual Machines
        .PARAMETER DestinationStoragePath
            Path to store the Virutal Machine storage. Sub-Directories will be created based on soruce structure.
        .PARAMETER ComputerName
            Remote Hyper-V Host to execute VM Storage operation on
        .PARAMETER RetainVhdCopiesOnSource
            Specify $true to keep any parent virtual hard disks on the source computer. 
            If not specified, all virtual hard disks will be removed from the source computer 
            once the virtual machine is successfully moved.

    #>

    [CmdletBinding(ConfirmImpact='High')]
    Param (
        
        [Parameter(Position = 0, Mandatory = $True, ValueFromPipeline = $True, ParameterSetName = "ByName")]
        [String[]]$VMName,
        [Parameter(Position = 0, Mandatory = $True, ValueFromPipeline = $True, ParameterSetName = "ByVM")]
        [Microsoft.HyperV.PowerShell.VirtualMachine[]]$VMs,
        [Parameter(Position = 1, Mandatory = $True)]
        [String]$DestinationStoragePath,
        [String]$ComputerName = 'localhost',
        [Switch]$RetainVhdCopiesOnSource = $False
    )
    if($VMName) {
        $VMs = Get-VM -Name $VMName -ComputerName $ComputerName
    }

    $VMs | % {
        Move-VMStorage -VM $_ -DestinationStoragePath $DestinationStoragePath -RetainVhdCopiesOnSource:$RetainVhdCopiesOnSource -ErrorAction Continue
    }
}

#MigrateVMStorage  -VMName '*','Red-Hawk-Rand*' -DestPath "X:\HyperVStore\" -Debug

function CleanDeleteVM {
    [CmdletBinding(ConfirmImpact='High')]
    Param (
        [String]$ComputerName = 'localhost',
        [Parameter(Mandatory)]
        [String[]]$VMName,
        [pscredential]$Credential,
        [Switch]$WhatIf = $false,
        [Switch]$Confirm = $true
    )
    #Ensure running correct version of hyper-v mod
    Remove-Module -Name Hyper-V -Verbose:$False
    Import-Module -Name Hyper-V -RequiredVersion '1.1' -ErrorAction Stop -Verbose:$False

    if($ComputerName -ne 'localhost') {
        #Attempt to initiate a session with the remote host
        $session = New-PSSession $ComputerName -Credential $Credential -ErrorAction Stop
        $VMName | % {
            Write-Verbose "Removing Virtual Hard Disk Files for VM: $_"
            Invoke-Command -ScriptBlock { $args[0] | Get-VMHardDiskDrive | select -ExpandProperty Path | 
                % {Remove-Item $_ -Confirm }
              } -ArgumentList $_ -Session $session
            
            Write-Verbose "Deleting Virtual Machine $_"
            Invoke-Command -ScriptBlock { $args[0] | 
                Remove-VM -Confirm} -ArgumentList $_ -Session $session
        }
    }
    
}


Export-ModuleMember -Function 'Move-VMStorageSynchronous'