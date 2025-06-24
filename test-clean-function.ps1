# Clean version of the problematic function
function Start-NetworkPrinterScanV2 {
    param(
        [string]$NetworkRange,
        [string]$Community = "public",
        [switch]$ScanAll = $false
    )
    
    Write-Host "Testing function" -ForegroundColor Cyan
    
    # Simple test
    $ips = @("192.168.15.1", "192.168.15.2")
    
    foreach ($ip in $ips) {
        Write-Host "Checking $ip"
    }
    
    return @()
}

# Test
Start-NetworkPrinterScanV2 -NetworkRange "192.168.15.0/24"
