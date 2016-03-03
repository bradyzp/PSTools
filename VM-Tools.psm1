
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

function Remove-VMFull {
    [CmdletBinding(SupportsShouldProcess,
                    ConfirmImpact='High')]
    Param (
        [Parameter(Mandatory,Position=0,ValueFromPipeline)]
        [String[]]$VMName,
        [Parameter(Position=1)]
        [String]$ComputerName = 'localhost',
        [pscredential]$Credential,
        [Switch]$WhatIf = $false,
        [string]$HVVersion = '1.1',
        [Switch]$Force
    )
    BEGIN {
        #$PSBoundParameters.Remove('Force')

    }
    PROCESS {
        #Ensure running correct version of hyper-v mod
        Remove-Module -Name Hyper-V -Verbose:$False
        Import-Module -Name Hyper-V -RequiredVersion $HVVersion -ErrorAction Stop -Verbose:$False

        if($ComputerName -ne 'localhost') {
            #Attempt to initiate a session with the remote host
            $session = New-PSSession $ComputerName -Credential $Credential -ErrorAction Stop
            $VMName | % {
                Stop-VM $_ -Force -TurnOff
                Write-Verbose "Removing Virtual Hard Disk Files for VM: $_"
                Invoke-Command -ScriptBlock { $args[0] | Get-VMHardDiskDrive | select -ExpandProperty Path | 
                    % {Remove-Item $_ }
                  } -ArgumentList $_ -Session $session
            
                Write-Verbose "Deleting Virtual Machine $_"
                Invoke-Command -ScriptBlock { $args[0] | 
                    Remove-VM -Confirm} -ArgumentList $_ -Session $session
            }
        }
        else {
            $VMName | % {
                if($Force -or $PSCmdlet.ShouldProcess($_, "Force Stop VM and delete")) {
                    Write-Verbose "Stopping Virtual Machine $_"
                    Stop-VM $_ -Force -TurnOff
                
                
                    Write-Verbose "Deleting VHDs"
                    $_ | Get-VMHardDiskDrive | select -ExpandProperty Path |
                        % { 
                            if($Force -or $PSCmdlet.ShouldProcess($_, "Delete VHD")) {
                                Remove-Item $_ -Confirm:$false | Out-Null
                            }
                          }
                    Write-Verbose "Deleting VM Configs"
                    if($Force -or $PSCmdlet.ShouldProcess($_, "Delete VMConfig")) {
                        $_ | Remove-VM -Confirm:$false -Force -ErrorAction Continue -ErrorVariable err
                    }
                    else {
                        Write-Warning "Retaining VM Config"
                    }
                }
                else {
                    Write-Warning "Aborting deletion of $_"
                }
            }
        }
    }
}

Export-ModuleMember -Function 'Remove-VMFull'
Export-ModuleMember -Function 'Move-VMStorageSynchronous'