#A BOLT ON TO THE CHECK_UPLOADS; THIS DOES PREPROCESSING TO LOOK FOR A DEFINED SET OF GOOD FILE TYPES AND CONTENTS TO MARK AS SAFE.


# Define the directory to search for .doc files
$directory = "C:\Users\Administrator\Desktop\upload"

# Run the script continuously in the background
while ($true) {
    # Find all .doc files in the specified directory
    $docFiles = Get-ChildItem -Path $directory -Filter "*.doc"

    # Loop through each .doc file
    foreach ($file in $docFiles) {
        # Skip files that already have '_safe' in the filename
        if ($file.Name -like "*_safe*") {
            continue
        }

        # Read the file's binary content
        $content = [System.IO.File]::ReadAllBytes($file.FullName)

        # Convert the binary content to a string
        $stringContent = [System.Text.Encoding]::ASCII.GetString($content)

        # Check for the phrase "GENERIC BOILERPLATE"
        if ($stringContent -match "GENERIC BOILERPLATE") {
            # Generate a random number between 1 and 100
            $randomChance = Get-Random -Minimum 1 -Maximum 100

            # Check if the random number is within the 30% chance
            if ($randomChance -le 30) {
                # Rename the file to include '_safe'
                $newName = $file.BaseName + "_safe" + $file.Extension
                Rename-Item -Path $file.FullName -NewName $newName
            }
        }
    }

    # Wait for 1 minute before repeating the process
    Start-Sleep -Seconds 60
}
