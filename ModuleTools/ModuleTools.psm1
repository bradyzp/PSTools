function Sync-Module {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [String]$ModuleName
    )
    $name = Split-Path -Path $ModuleName -Leaf
    
    $loaded = Get-Module -Name $name

    if($loaded){
        Remove-Module $loaded.Name
        Import-Module ($loaded.Path | Split-Path -Parent) -Scope Global
    } else {
        try {
            Import-Module -Name $ModuleName -Scope Global -ErrorAction Stop
        } catch {
            # If the above fails try to import from the current directory
            Write-Verbose "Attempting to source module from current directory"
            Import-Module -Name ".\$ModuleName" -Scope Global -ErrorAction Stop
        }
    }
}

New-Alias -Name sym -Value 'Sync-Module' -Force -ErrorAction Inquire

Export-ModuleMember -Function 'Sync-Module'

Export-ModuleMember -Alias 'sym'