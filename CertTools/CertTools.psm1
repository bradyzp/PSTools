
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

function New-SslCSR {

    <#
    .SYNOPSIS
        Generate an openssl req configuration file used to generate a CSR with Subject Alternative Name (SAN) DNS Fields.
        Additionally generate the private key and CSR using the openssl commandline tool using the -Generate flag
        With -Submit, also submit the generated CSR(s) to an Active Directory Certificate Authority using certreq.exe
        and the specified CertificateTemplate
    .DESCRIPTION

    .EXAMPLE
        New-SslCSR -CommonName test.contoso.com -Generate -Submit -CertificateTemplate ContosoWebServer


    .PARAMETER CommonName
        DNS Name or Names to generate a v3 openssl configuration for. The Common Name is also included as the first SAN DNS entry.
    .PARAMETER OutPath
    .PARAMETER Bits
        Bit size of RSA private key to generate.
    .PARAMETER DNS_Names
        Additional DNS Names to include in the v3 SSL SAN Field (Note the Common Name is already included).
    
    
    
    .INPUTS
        String[]
            Common Name(s), to generate Openssl config files for.
    .LINK
        https://www.openssl.org/docs/man1.1.0/apps/req.html
    .LINK
        https://technet.microsoft.com/en-us/library/dn296456%28v=ws.11%29.aspx?f=255&MSPPError=-2147217396

    #>
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true)]
        [String[]]$CommonName,
        [Parameter(Position = 1, Mandatory = $false, HelpMessage='Output filename for generated configuration')]
        [String]$OutPath,
        [Parameter(Position = 2, Mandatory = $false, HelpMessage='Default Private Key size when creating a new key')]
        [Int]$Bits = 2048,
        [Parameter(Position = 3, Mandatory = $false, HelpMessage='2 Letter Country Code')]
        [String]$Country = 'US',
        [Parameter(Position = 4, Mandatory = $false, HelpMessage='State/Province')]
        [String]$State = 'Colorado',
        [Parameter(Mandatory = $false, HelpMessage='Certificate Administrators email address')]
        [String]$Email='none',
        [Parameter(Mandatory = $false, HelpMessage='Additional DNS SANs (CN is automatically included)')]
        [String[]]$DNS_Names,
        [Parameter(Mandatory = $false, HelpMessage='Display the openssl command to generate a certificate signing request using the generated config file')]
        [Switch]$ShowCmd,
        [Parameter(Mandatory = $false, HelpMessage='Generates configuration files and outputs to stdout without saving to file')]
        [Switch]$noout,
        [Parameter(Mandatory = $false, HelpMessage='Execute openssl req command to generate CSR with new config file')]
        [Switch]$Generate,
        [Parameter(Mandatory = $false, HelpMessage='Submit generated csr to ADCS using certreq.exe', ParameterSetName='Submit')]
        [Switch]$Submit,
        [Parameter(Mandatory = $true, ParameterSetName='Submit')]
        [String]$CertificateTemplate
    
    )

    BEGIN {
        $CWD = Get-Item -Path ".\" | Select-Object -ExpandProperty FullName
        if (-not $OutPath){
            $OutPath = $CWD
        }
        $cmd_list = @()
    } # END BEGIN
    PROCESS {

        foreach ($cn in $CommonName) {
            $OutPath = Join-Path $CWD "$cn.cfg"
            Write-Debug "Writing configuration file to $Out in current directory ($CWD)"
            $KeyPath = Join-Path $CWD "$cn.key"

            $SAN_DNS = "DNS.1 = $cn`n"
            $DNS_N = 2
            foreach ($name in $DNS_Names) {
                $SAN_DNS += "DNS.$DNS_N = $name`n"
                $DNS_N += 1
            }

            $Config = @"
[req]
default_bits = $Bits
default_keyfile = $cn.key
encrypt_key = no
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = distinguished_name

[distinguished_name]
CN=$cn
C=$Country
ST=$State
emailAddress=$Email

[req_ext]
subjectAltName = @alt_names

[alt_names]
$SAN_DNS
"@
            if(-not $Noout) {
                $Config | Out-Unix -Path $OutPath
                $cfg_path = (Get-ChildItem $OutPath).FullName
                Write-Debug "Configuration written to $cfg_path"        
            } else {
                Write-Output $Config
            }
        
            ### Generate CSR with openssl ###
            if($Generate) {
                $openssl_cmd = "openssl req -out $cn.csr -new -config $cn.cfg"
                Write-Verbose "Invoking command: $openssl_cmd"
                $openssl_result = Invoke-Expression -Command $openssl_cmd 2> $null
                Write-Host $openssl_result
            }

            ### Submit Generated CSR with certreq ###
            if($Submit) {
                if(-not $Generate){
                    throw "Unable to submit CSR as CSR has not been generated, run this command again with the -Execute switch."
                }
                $certreq_cmd = "certreq.exe -submit -attrib `"CertificateTemplate:$CertificateTemplate`" $cn.csr 2>&1"
                Write-Verbose "Invoking command: $certreq_cmd"
                #$certreq_result = Invoke-Expression -Command $certreq_cmd
                Write-Host $certreq_result

            }
        } # END FOREACH
    } # END PROCESS
    END {
     $CmdHelp = @"

#######################################################
USAGE:
Generate CSR using generated configuration file(s) ($Out):
openssl req -out <CN>.csr -new -config $OutPath
#openssl req -out <CN>.csr -newkey rsa:$Bits -nodes -keyout <CN>.key -config $OutPath

Verify the generated CSR (<CN>.csr):
openssl req -noout -text -in <CN>.csr

Submit the CSR to an Active Directory Certificate Authority:
certreq.exe -submit -attrib "CertificateTemplate:<TemplateName>" $OutPath
"@
        if ($ShowCmd) {
                Write-Host $CmdHelp -ForegroundColor Cyan
            }
    } # END END
}

Export-ModuleMember -Function 'New-SslCSR'

#'rh-fw-1.ad.rusthawk.net','prtg.ad.rusthawk.net' | Generate-CSR -Bits 1024