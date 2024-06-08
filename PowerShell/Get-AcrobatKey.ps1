<#PSScriptInfo
 
.VERSION 1.0
 
.GUID 434aa2df-3341-4e28-bed4-708b2f8616aa
 
.AUTHOR Chris Carter
 
.COMPANYNAME N/A
 
.COPYRIGHT 2017 Chris Carter
 
.TAGS Adobe Acrobat Serial
 
.LICENSEURI http://creativecommons.org/licenses/by-sa/4.0/
 
.PROJECTURI
 
.ICONURI
 
.EXTERNALMODULEDEPENDENCIES
 
.REQUIREDSCRIPTS
 
.EXTERNALSCRIPTDEPENDENCIES
 
.RELEASENOTES Initial Release
 
 
#>

<#
.SYNOPSIS
Gets Adobe Acrobat Serial Key
.DESCRIPTION
Get-AcrobatKey gets the Adobe Acrobat Serial Key needed if the program needs to be reinstalled. It does this by decrypting the Serial Number stored in the Registry. This field can sometimes be erroneously blank, so it is not a foolproof solution.
 
This command should run successfully on Adobe Acrobat from at least version 7-10, but may work on other versions as well.
 
The decryption code to convert the registry value was taken from: https://superuser.com/questions/784578/find-key-of-installed-and-activated-instance-adobe-acrobat-professional-without
.PARAMETER ComputerName
The name of the computer to retrieve the key from.
.PARAMETER Version
Version of Adobe Acrobat installed on the machine.
.INPUTS
System.String
 
You can pipe String objets to Get-AcrobatKey of computer names to retrieve the command from.
.OUTPUTS
System.String
 
Get-AcrobatKey returns a string of the decrypted Serial Key
.EXAMPLE
PS C:\> Get-AcrobatKey -ComputerName workstation1 -Version 9
 
This command gets the Adobe Acrobat Serial Key for version 9 from computer named workstation1.
.NOTES
If the registry value this command uses as its source is erroneously blank, other means will be required, and are discussed at the linked article.
 
.LINK
https://superuser.com/questions/784578/find-key-of-installed-and-activated-instance-adobe-acrobat-professional-without
#>

#Requires -Version 3.0
[CmdletBinding()]
Param(
    [Parameter(Position=1,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)] 
        [Alias("Cn")]
        [String]$ComputerName=$env:COMPUTERNAME,

    [Parameter(Position=0,Mandatory=$true)]
        [Int]$Version
)

Begin {
    $scriptblock = {
        Param( $Version, $ComputerName )

        $AdobeCipher = "0000000001", "5038647192", "1456053789", "2604371895",
        "4753896210", "8145962073", "0319728564", "7901235846",
        "7901235846", "0319728564", "8145962073", "4753896210",
        "2604371895", "1426053789", "5038647192", "3267408951",
        "5038647192", "2604371895", "8145962073", "7901235846",
        "3267408951", "1426053789", "4753896210", "0319728564"
        
        if ((Get-CimInstance Win32_OperatingSystem).OSArchitecture -eq "64-bit") {
            $WowNode = 'Wow6432Node\'
        } else { $WowNode = '' }

        $EncryptedKey = (Get-ItemProperty "HKLM:\SOFTWARE\$($WowNode)Adobe\Adobe Acrobat\$Version\Registration").SERIAL

        if ($EncryptedKey) {
            $counter = 0

            $DecryptedKey = ""

            while ($counter -ne 24) {
                $DecryptedKey += $AdobeCipher[$counter].substring($EncryptedKey.SubString($counter, 1), 1)
                $counter ++
            }

            $DecryptedKey
        }
        else { Write-Error "Adobe Acrobat $Version is not installed on $ComputerName or the serial information is missing in the registry." }
    }

    [string]$Version = "{0:n1}" -f $Version
}

Process {
    foreach ($cn in $ComputerName) {
        if ($cn -eq $env:COMPUTERNAME) {
            & $scriptblock -Version $Version -ComputerName $cn
        }
        else {
            Invoke-Command -ScriptBlock $scriptblock -ComputerName $cn -ArgumentList $Version,$cn
        }
    }
}