$arpResults = arp.exe -a | Out-String
$arpResults | Select-string -Pattern '(?smi)((?<=Interface:).*?(?=Interface:|\Z))' -AllMatches | 
        Select-Object -ExpandProperty Matches | ForEach-Object{
    $interfaceData = $_.Groups[0].Value.Trim() -split "`r`n"

    # Header of the data table is the second array element.
    $headerString = $interfaceData[1]
    $headerElements = $headerString -split "\s{2,}" | Where-Object{$_}
    $headerIndexes = $headerElements | ForEach-Object{$headerString.IndexOf($_)}

    # Skip the first two lines as they are for the interface address and header for each table
    $interfaceData | Select-Object -Skip 2 | ForEach-Object{
        $props = @{Interface = $interfaceData[0].Trim()}
        $line = $_
        For($indexStep = 0; $indexStep -le $headerIndexes.Count - 1; $indexStep++){
            $value = $null            # Assume a null value 
            $valueLength = $headerIndexes[$indexStep + 1] - $headerIndexes[$indexStep]
            $valueStart = $headerIndexes[$indexStep]
            If(($valueLength -gt 0) -and (($valueStart + $valueLength) -lt $line.Length)){
                $value = ($line.Substring($valueStart,$valueLength)).Trim()
            } ElseIf ($valueStart -lt $line.Length){
                $value = ($line.Substring($valueStart)).Trim()
            }
            $props.($headerElements[$indexStep]) = $value    
        }
        [pscustomobject]$props
    } 

} | Select-Object Interface, "Internet Address","Physical Address",Type