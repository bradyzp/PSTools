
function Out-Unix {
<#
Credit for this function to Adrian@picuspickings.blogspot.com
#>
    param ([string] $Path)

    begin 
    {
        $streamWriter = New-Object System.IO.StreamWriter("$Path", $false)
    }
    
    process
    {
        $streamWriter.Write(($_ | Out-String).Replace("`r`n","`n"))
    }
    end
    {
        $streamWriter.Flush()
        $streamWriter.Close()
    }
}

function New-CSR {

    <#
    .SYNOPSIS
        Generate an openssl req configuration file used to generate a CSR with Subject Alternative Name (SAN) DNS Fields



    #>
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $false, HelpMessage='Output filename for generated configuration', ParameterSetName='Single')]
        [String]$Out,
        [Parameter(Position = 1, Mandatory = $true, ValueFromPipeline = $true)]
        [String[]]$CN,
        [Parameter(Position = 2, Mandatory = $false, HelpMessage='Default Private Key size when creating a new key')]
        [Int]$Bits = 2048,
        [Parameter(Position = 3, Mandatory = $false, HelpMessage='2 Letter Country Code')]
        [String]$Country = 'US',
        [Parameter(Position = 4, Mandatory = $false, HelpMessage='State/Province')]
        [String]$State = 'Colorado',
        [Parameter(Mandatory = $false, HelpMessage='Additional DNS SANs (CN is automatically included)', ParameterSetName='Single')]
        [String[]]$DNS_Names,
        [Parameter(Mandatory = $false, HelpMessage='Display the openssl command to generate a certificate signing request using the generated config file')]
        [Bool]$ShowCmd = $true
    
    )

    BEGIN {
        $CWD = Get-Item -Path ".\" | Select-Object -ExpandProperty FullName
        if (-not $Out){
            $Out = $CWD
        }
    }
    PROCESS {

        foreach ($entry in $CN) {
            $OutPath = Join-Path $CWD "$entry.cfg"
            Write-Output "Writing configuration file to $Out in current directory ($CWD)"
            $KeyPath = Join-Path $CWD "$entry.key"

            $SAN_DNS = "DNS.1 = $entry`n"
            $DNS_N = 2
            foreach ($name in $DNS_Names) {
                $SAN_DNS += "DNS.$DNS_N = $name`n"
                $DNS_N += 1
            }

            $Config = @"
[req]
default_bits = $Bits
default_keyfile = $KeyPath
encrypt_key = no
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = distinguished_name

[distinguished_name]
CN=$entry
C=$Country
ST=$State
emailAddress=

[req_ext]
subjectAltName = @alt_names

[alt_names]
$SAN_DNS
"@

        $Config | Out-Unix -Path $OutPath
        $cfg_path = (Get-ChildItem $OutPath).FullName
        Write-Output "Configuration written to $cfg_path"        
        }
    } # END PROCESS
    END {
     $CmdHelp = @"

#######################################################
USAGE:
Generate CSR using generated configuration file(s) ($Out):
openssl req -out <CN>.csr -new -config $Out
#openssl req -out <CN>.csr -newkey rsa:$Bits -nodes -keyout <CN>.key -config $Out

Verify the generated CSR (<CN>.csr):
openssl req -noout -text -in <CN>.csr

Submit the CSR to an Active Directory Certificate Authority:
certreq.exe -submit -attrib "CertificateTemplate:<TemplateName>" $Out
"@
        if ($ShowCmd) {
                Write-Output $CmdHelp
            }

    }
}


Export-ModuleMember -Function 'New-SslCSR'

#'rh-fw-1.ad.rusthawk.net','prtg.ad.rusthawk.net' | Generate-CSR -Bits 1024