$vendors = @()
$output= "C:\localgit\PowerShellSaturday2019\AzureTable\input.txt"

if (test-path -Path $output) {
    $vendorlist = Get-Content -Path $output 
    if ($vendorlist.Length -gt 15300) {
        foreach ($vendor in $vendorlist) {
            if (($vendor.Contains("(hex)")) -or ($vendor.Contains("(base 16)"))) {
                $arrVDetails = $vendor.Split("`t")
                if (!$vendorName) {
                    $vendorName = $arrVDetails[2]
                }
                if ($vendor.Contains("(hex)")) { $hex = $arrVDetails[0].Split(" ")}
            if ($vendor.Contains("(base 16)")) { $base16 = $arrVDetails[0].Split(" ")}
                if ($hex -and $base16 -and $vendorName) {
                    write-host -ForegroundColor blue "$($base16[0]) $($hex[0]) $($vendorName)"                  
                    $vendorDetails = [PSCustomObject]@{    
                        vendor = $vendorName
                        base16 = "$($base16[0])"
                        hex    = "$($hex[0])"                    
                    }
                    $vendors += $vendorDetails
                    $arrVDetails = $null 
                    $hex = $null
                    $base16 = $null
                    $vendorName = $null 
                }
            }
        }
    }
}