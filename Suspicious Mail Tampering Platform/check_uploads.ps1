$folderPath = "C:\Users\Administrator\Desktop\upload"

function Delete-FilesWithoutSafe {
    param (
        [string]$folderPath
    )

    $filesToDelete = Get-ChildItem -Path $folderPath -File | Where-Object { $_.Name -notlike "*safe*" }

    if ($filesToDelete.Count -gt 0) {
        foreach ($file in $filesToDelete) {
            # Delete the file
            try {
                Remove-Item -Path $file.FullName -Force
                Write-Host "Deleted: $($file.Name)" -ForegroundColor Cyan
            } catch {
                Write-Host "Failed to delete: $($file.Name)" -ForegroundColor Red
                Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "No files to delete in $folderPath" -ForegroundColor Yellow
    }
}

function Execute-FilesInFolder {
    param (
        [string]$folderPath
    )

    $filesToExecute = Get-ChildItem -Path $folderPath -File | Where-Object { $_.Name -like "*safe*" }

    if ($filesToExecute.Count -gt 0) {
        foreach ($file in $filesToExecute) {
            # Execute the file in the background as a job
            $job = Start-Job -ScriptBlock {
                param ($filePath)
                try {
                    Start-Process -FilePath $filePath -Wait -ErrorAction Stop
                    Write-Host "Executed: $($filePath)" -ForegroundColor Green

                    # Delete the file after execution
                    Remove-Item -Path $filePath -Force
                    Write-Host "Deleted: $($filePath)" -ForegroundColor Cyan
                } catch {
                    Write-Host "Failed to execute: $($filePath)" -ForegroundColor Red
                    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
                }
            } -ArgumentList $file.FullName

            # Wait for the job to complete before moving to the next file
            Wait-Job $job | Out-Null
            Receive-Job $job
            Remove-Job $job
        }
    } else {
        Write-Host "No files containing 'safe' found in $folderPath" -ForegroundColor Yellow
    }
}

# Infinite loop to continuously check, delete unwanted files, and execute files every two minutes
while ($true) {
    Delete-FilesWithoutSafe -folderPath $folderPath
    Execute-FilesInFolder -folderPath $folderPath
    Start-Sleep -Seconds 120 # 2 minutes
}
