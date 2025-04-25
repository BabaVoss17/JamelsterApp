Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Google OAuth Configuration #
$client_id = "ENTER CLIENT_ID"
$client_secret = "ENTER CLIENT_SECRET"
$scope = "https://www.googleapis.com/auth/drive.file"
$redirect_uri = "urn:ietf:wg:oauth:2.0:oob"
$access_token = ""
$fileMap = @{}

# GUI Setup #
$form = New-Object Windows.Forms.Form
$form.Text = "JamelsterApp - Google Drive Manager"
$form.Size = New-Object Drawing.Size(880, 500)
$form.StartPosition = "CenterScreen"

# Top Buttons #
$btnUpload = New-Object Windows.Forms.Button -Property @{
    Text = "Upload"; Location = "10,10"; Size = "100,30"
}
$btnDownload = New-Object Windows.Forms.Button -Property @{
    Text = "Download"; Location = "120,10"; Size = "100,30"
}
$btnList = New-Object Windows.Forms.Button -Property @{
    Text = "List Files"; Location = "230,10"; Size = "100,30"
}
$btnDelete = New-Object Windows.Forms.Button -Property @{
    Text = "Delete"; Location = "340,10"; Size = "100,30"
}
$btnAuth = New-Object Windows.Forms.Button -Property @{
    Text = "Authenticate"; Location = "450,10"; Size = "120,30"
}

$listBox = New-Object Windows.Forms.ListBox -Property @{
    Location = "10,50"; Size = "840,250"; Font = 'Courier New, 9pt'
}

$logBox = New-Object Windows.Forms.TextBox -Property @{
    Multiline = $true; ReadOnly = $true
    ScrollBars = "Vertical"; Location = "10,310"; Size = "840,140"
}

$form.Controls.AddRange(@(
    $btnUpload, $btnDownload, $btnList, $btnDelete, $btnAuth,
    $listBox, $logBox
))

# Prompt Authorization Code #
function Show-CodePrompt {
    $codeForm = New-Object Windows.Forms.Form
    $codeForm.Text = "Google Auth Code"
    $codeForm.Size = New-Object Drawing.Size(400,150)
    $codeForm.StartPosition = "CenterScreen"

    $label = New-Object Windows.Forms.Label
    $label.Text = "Paste the authorization code below:"
    $label.AutoSize = $true
    $label.Location = New-Object Drawing.Point(10,10)

    $textBox = New-Object Windows.Forms.TextBox
    $textBox.Location = New-Object Drawing.Point(10,40)
    $textBox.Width = 360

    $okButton = New-Object Windows.Forms.Button
    $okButton.Text = "OK"
    $okButton.Location = New-Object Drawing.Point(290,70)
    $okButton.Add_Click({ $codeForm.Close() })

    $codeForm.Controls.AddRange(@($label, $textBox, $okButton))
    $null = $codeForm.ShowDialog()
    return $textBox.Text
}

# Authenticate #
$btnAuth.Add_Click({
    $authUrl = "https://accounts.google.com/o/oauth2/v2/auth?response_type=code&client_id=$client_id&redirect_uri=$redirect_uri&scope=$scope&access_type=offline"
    Start-Process $authUrl
    $code = Show-CodePrompt
    if (-not $code) { return }

    $tokenResp = Invoke-RestMethod -Uri "https://oauth2.googleapis.com/token" -Method POST -Body @{
        code = $code
        client_id = $client_id
        client_secret = $client_secret
        redirect_uri = $redirect_uri
        grant_type = "authorization_code"
    }
    $global:access_token = $tokenResp.access_token
    $logBox.AppendText("Access token acquired.`r`n")
})

# List - Type & Modified Time #
$btnList.Add_Click({
    if (-not $access_token) {
        $logBox.AppendText("Authenticate first.`r`n")
        return
    }

    $headers = @{ Authorization = "Bearer $access_token" }
    $listBox.Items.Clear(); $fileMap.Clear()
    $pageToken = $null

    $listBox.Items.Add(("Name".PadRight(50)) + ("MIME Type".PadRight(30)) + ("Modified Time"))
    $listBox.Items.Add(("-" * 110))

    do {
        $uri = "https://www.googleapis.com/drive/v3/files?pageSize=1000&fields=nextPageToken,files(id,name,mimeType,modifiedTime)"
        if ($pageToken) {
            $uri += "&pageToken=$pageToken"
        }

        $response = Invoke-RestMethod -Uri $uri -Headers $headers
        foreach ($file in $response.files) {
            $line = "{0,-50} {1,-25} {2}" -f $file.name, $file.mimeType, $file.modifiedTime
            $listBox.Items.Add($line)
            $fileMap[$file.name] = $file.id
        }

        $pageToken = $response.nextPageToken
    } while ($pageToken)

    $logBox.AppendText("All Google Drive files listed with type and modified time.`r`n")
})

# Upload File #
$btnUpload.Add_Click({
    if (-not $access_token) {
        $logBox.AppendText("Authenticate first.`r`n")
        return
    }

    $dialog = New-Object Windows.Forms.OpenFileDialog
    if ($dialog.ShowDialog() -eq "OK") {
        $file = $dialog.FileName
        $name = [System.IO.Path]::GetFileName($file)
        $bytes = [System.IO.File]::ReadAllBytes($file)

        $boundary = [guid]::NewGuid().ToString()
        $LF = "`r`n"
        $meta = @{ name = $name } | ConvertTo-Json -Depth 5

        $body = "--$boundary$LF"
        $body += "Content-Type: application/json; charset=UTF-8$LF$LF$meta$LF"
        $body += "--$boundary$LF"
        $body += "Content-Type: application/octet-stream$LF$LF"
        $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($body)
        $endBytes = [System.Text.Encoding]::UTF8.GetBytes("$LF--$boundary--$LF")

        $all = New-Object byte[] ($bodyBytes.Length + $bytes.Length + $endBytes.Length)
        [System.Buffer]::BlockCopy($bodyBytes,0,$all,0,$bodyBytes.Length)
        [System.Buffer]::BlockCopy($bytes,0,$all,$bodyBytes.Length,$bytes.Length)
        [System.Buffer]::BlockCopy($endBytes,0,$all,$bodyBytes.Length + $bytes.Length,$endBytes.Length)

        $upload = Invoke-RestMethod -Uri "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart" `
            -Method POST -Headers @{
                Authorization = "Bearer $access_token"
                "Content-Type" = "multipart/related; boundary=$boundary"
            } -Body $all

        $logBox.AppendText("Uploaded '$name' with ID: $($upload.id)`r`n")
    }
})

# Download File #
$btnDownload.Add_Click({
    if (-not $access_token) {
        $logBox.AppendText("Authenticate first.`r`n")
        return
    }

    $selected = $listBox.SelectedItem
    if (-not $selected -or $selected.StartsWith("Name")) {
        $logBox.AppendText("Select a file to download.`r`n")
        return
    }

    $name = ($selected -split '\s{2,}')[0]
    $fileId = $fileMap[$name]
    $saveDialog = New-Object Windows.Forms.SaveFileDialog
    $saveDialog.FileName = $name

    if ($saveDialog.ShowDialog() -eq "OK") {
        $outputPath = $saveDialog.FileName
        $downloadUrl = "https://www.googleapis.com/drive/v3/files/$fileId?alt=media"

        Invoke-WebRequest -Uri $downloadUrl -Headers @{
            Authorization = "Bearer $access_token"
        } -OutFile $outputPath

        $logBox.AppendText("Downloaded '$name' to '$outputPath'`r`n")
    }
})

# Delete File #
$btnDelete.Add_Click({
    if (-not $access_token) {
        $logBox.AppendText("Authenticate first.`r`n")
        return
    }

    $selected = $listBox.SelectedItem
    if (-not $selected -or $selected.StartsWith("Name")) {
        $logBox.AppendText("Select a file to delete.`r`n")
        return
    }

    $name = ($selected -split '\s{2,}')[0]
    $fileId = $fileMap[$name]
    $confirm = [System.Windows.Forms.MessageBox]::Show("Delete '$name'?", "Confirm", "YesNo")
    if ($confirm -eq "Yes") {
        Invoke-RestMethod -Uri "https://www.googleapis.com/drive/v3/files/$fileId" -Method DELETE -Headers @{
            Authorization = "Bearer $access_token"
        }
        $logBox.AppendText("Deleted '$name'.`r`n")
        $listBox.Items.Remove($selected)
        $fileMap.Remove($name)
    }
})

# Run Form #
[void]$form.ShowDialog()
