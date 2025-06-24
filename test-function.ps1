# Test function to check syntax
function Start-NetworkPrinterScan {
    param(
        [string]$NetworkRange,
        [string]$Community = "public",
        [switch]$ScanAll = $false
    )
    
    Write-Host "Test function" -ForegroundColor Cyan
    
    $ips = @("192.168.1.1", "192.168.1.2")
    
    foreach ($ip in $ips) {
        Write-Host "Testing $ip"
        
        if ($ip -eq "192.168.1.1") {
            Write-Host "Found device"
        } else {
            Write-Host "No device"
        }
    }
    
    return $null
}

# Test the function
Start-NetworkPrinterScan -NetworkRange "192.168.1.0/24"
