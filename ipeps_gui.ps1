# Init PowerShell Gui
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
# Make the GUI a bit more pretty
[System.Windows.Forms.Application]::EnableVisualStyles()

# Add an icon to our window
$iconPS = [Drawing.Icon]::ExtractAssociatedIcon((Get-Command powershell).Path)

# Define the default IP address and password of the iPEPS device
#$iPEPS_IP = 192.168.1.42
$iPEPS_IP = "10.0.0.112"
$iPEPS_PW = "P4ssword_"

# We're keeping the kvmadmin executable next to our PS script
$kvmadmin  = $PSScriptRoot+"\kvmadmin.exe"
$usersfile = $PSScriptRoot+"\users2.csv"

# Images for the basic UI buttons
$a_image_path = $PSScriptRoot+"\ipeps_analog.png"
$d_image_path = $PSScriptRoot+"\ipeps_digital.png"

function Ping_test () {
    Write-Host "Pinging device on "$iPEPS_IP -ForegroundColor Green

    $result = Test-Connection $iPEPS_IP -Quiet -Count 2
    return $result
}

function kvmadmintool ($command){
    $pw_attrib = "-password="+$iPEPS_PW
    switch ($command) {
        getconfig {
            Write-Host "Getting device information"
            $Script:output = & $kvmadmin -getconfig oldconfig.tmp $iPEPS_IP -verifyid=0 $pw_attrib 2>&1 | %{ "$_" } 
        }
        setconfig {
            Write-Host "Uploading selected config file"
            $Script:output = & $kvmadmin -setconfig $inputfile $iPEPS_IP -verifyid=0 $pw_attrib 2>&1 | %{ "$_" }
        }
        setpasswd {
            Write-Host "Updating passwords"
            $Script:output = & $kvmadmin -setusers $usersfile $iPEPS_IP 2>&1 | %{ "$_" }
        }
    }
    $cmdout = ($Script:output -split "kvmadmin:")[7].ToString().Trim()
    Write-Host $cmdout
    return $cmdout
}

function compatibilitycheck () {
    if ($hw -ne $dev_hw) {
        [System.Windows.Forms.MessageBox]::Show("Selected configuration hardware version does not match the connected device.", 'Configuration mismatch!', 'OK', 'Error')
        return $false
    }
    elseif ($fw -ne $dev_fw) {
        [System.Windows.Forms.MessageBox]::Show("Selected configuration firmware version does not match the connected device.", 'Configuration mismatch!', 'OK', 'Error')
        return $false
    }
    else {
        return $true
    }
}

Function Get-FileName($initialDirectory){  
    Write-Host "Getting configuration file path"
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.filter = "iPEPS Config file (*.cfg)| *.cfg"
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.filename
}

Function ChildForm ($Parentlabel){
    $ChildForm = New-Object system.Windows.Forms.Form
    $ChildForm.text            = "iPEPS Configuration Progress"
    $ChildForm.Icon            = $iconPS
    $ChildForm.StartPosition   = "CenterScreen"
    $ChildForm.ClientSize      = '350,250'

    # Add a progressbar to show where we are in the progress
    $ProgressBar              = New-Object System.Windows.Forms.ProgressBar
    $ProgressBar.Location     = New-Object System.Drawing.Point(25,150)
    $ProgressBar.Size         = New-Object System.Drawing.Size(300,20)
    $ProgressBar.Style        = "Continuous"
    $ProgressBar.Value        = 0

    $ProgressCheckbox1 = New-Object System.Windows.Forms.Checkbox 
    $ProgressCheckbox1.Location = New-Object System.Drawing.Size(20,20) 
    $ProgressCheckbox1.Size = New-Object System.Drawing.Size(200,20)
    $ProgressCheckbox1.Text = "Ping device on "+$iPEPS_IP

    $ProgressCheckbox2 = New-Object System.Windows.Forms.Checkbox 
    $ProgressCheckbox2.Location = New-Object System.Drawing.Size(20,40) 
    $ProgressCheckbox2.Size = $ProgressCheckbox1.Size
    $ProgressCheckbox2.Text = "Get device configuration"

    $ProgressCheckbox3 = New-Object System.Windows.Forms.Checkbox 
    $ProgressCheckbox3.Location = New-Object System.Drawing.Size(20,60) 
    $ProgressCheckbox3.Size = $ProgressCheckbox1.Size
    $ProgressCheckbox3.Text = "Set admin password"

    $ProgressCheckbox4 = New-Object System.Windows.Forms.Checkbox 
    $ProgressCheckbox4.Location = New-Object System.Drawing.Size(20,80) 
    $ProgressCheckbox4.Size = $ProgressCheckbox1.Size
    $ProgressCheckbox4.Text = "Upload Configuration"
    
    $OKButton = New-Object System.Windows.Forms.Button
    $OKButton.Location = New-Object System.Drawing.Point(25,200)
    $OKButton.Text = "Zsamo"

    $CancelButton = New-Object System.Windows.Forms.Button
    $CancelButton.Location = New-Object System.Drawing.Point(250,200)
    $CancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $CancelButton.Text = "Cancel"

    $Progress_Groupbox          = New-Object System.Windows.Forms.GroupBox
    $Progress_Groupbox.Location = New-Object System.Drawing.Point(25, 10)
    $Progress_Groupbox.Size     = New-Object System.Drawing.Size(300, 120)
    $Progress_Groupbox.Text     = " Progress "

    $progress_elements = @($ProgressCheckbox1, $ProgressCheckbox2, $ProgressCheckbox3, $ProgressCheckbox4)
    foreach ($item in $progress_elements) { $Progress_Groupbox.Controls.Add($item)}

    $childform_elements = @($Progress_Groupbox, $ProgressBar, $OKButton, $CancelButton)
    foreach ($item in $childform_elements) { $ChildForm.Controls.Add($item)}

    $statusLabel.Text = "Working"
    
    $OKButton.Add_Click({
        $pingik = Ping_test
        if ($pingik) {
            $ProgressBar.Value += 20
            $ProgressCheckbox1.Checked = $true

            # Get current config to determine hw type
            $couldgetconfig = kvmadmintool("getconfig")
            if ($couldgetconfig) {$ProgressBar.Value += 20}
            $ProgressCheckbox2.Checked = $true

            # Set default admin password
            $couldsetpassword = kvmadmintool("setpasswd")
            if ($couldsetpassword) {$ProgressBar.Value += 20}
            $ProgressCheckbox3.Checked = $true

            # Check if the actual device configuration matches the selection
            $iscompatible = compatibilitycheck
            if ($iscompatible) {$ProgressBar.Value += 20}

            # Upload default configuration
            $couldsetconfig = kvmadmintool("setconfig")
            if ($couldsetconfig) {$ProgressBar.Value += 20}
            $ProgressCheckbox4.Checked = $true
        }

        if ($ProgressBar.Value -eq 100){
            $ChildForm.Close()
            $statusLabel.Text = "Done"
        }
        
    })

    $ChildForm.ShowDialog()
}

# Create a new form and define its parameters
$mainForm = New-Object system.Windows.Forms.Form
$mainForm.ClientSize      = '550,350'
$mainForm.text            = "iPEPS Admin Tool GUI"
$mainForm.Icon            = $iconPS
$mainForm.StartPosition   = "CenterScreen"
$statusStrip              = New-Object System.Windows.Forms.StatusStrip
$statusLabel              = New-Object System.Windows.Forms.ToolStripStatusLabel

# Create a panel for advanced controls
$advanced_Panel             = New-Object System.Windows.Forms.Panel
$advanced_Panel.Location    = New-Object System.Drawing.Point(1, 1)
$advanced_Panel.Size        = New-Object System.Drawing.Size(550, 320)
$advanced_Panel.BorderStyle = "none"
$advanced_Panel.Visible     = $False

# Create a panel for basic controls
$basic_Panel             = New-Object System.Windows.Forms.Panel
$basic_Panel.Location    = New-Object System.Drawing.Point(1, 1)
$basic_Panel.Size        = New-Object System.Drawing.Size(550, 320)
$basic_Panel.BorderStyle = "none"
$basic_Panel.Visible     = $True

# Add Button to test if the device is reachable on the network
$Button           = New-Object System.Windows.Forms.Button
$Button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$Button.Location  = New-Object System.Drawing.Point(50,30)
$Button.Size      = New-Object System.Drawing.Size(120,30)
$Button.BackColor = ""
$Button.Text      = "Test connection"

# Add Button for admin password
$Button_pw           = New-Object System.Windows.Forms.Button
$Button_pw.Location  = New-Object System.Drawing.Point(50,80)
$Button_pw.FlatStyle = $Button.FlatStyle
$Button_pw.Size      = $Button.Size
$Button_pw.Text      = "Set admin password"

# Add Button for config file selection
$Button2           = New-Object System.Windows.Forms.Button
$Button2.Location  = New-Object System.Drawing.Point(50,150)
$Button2.FlatStyle = $Button.FlatStyle
$Button2.Size      = $Button.Size
$Button2.Text      = "Select Config file"

# Add Button for uploading configuration
$Button3           = New-Object System.Windows.Forms.Button
$Button3.Location  = New-Object System.Drawing.Point(50,280)
$Button3.FlatStyle = $Button.FlatStyle
$Button3.Size      = $Button.Size
$Button3.Enabled   = $false
$Button3.ForeColor = "White"
$Button3.BackColor = "DarkRed"
$Button3.Text      = "Upload configuration"

# Add Button to change view between Advanced and Basic
$Button4           = New-Object System.Windows.Forms.Button
$Button4.Location  = New-Object System.Drawing.Point(380,290)
$Button4.FlatStyle = $Button.FlatStyle
$Button4.Size      = $Button.Size
$Button4.Enabled   = $true
$Button4.Text      = "Advanced mode"

# Button to select Analog device
$Button_a           = New-Object System.Windows.Forms.Button
$Button_a.Location  = New-Object System.Drawing.Point(20,20)
$Button_a.FlatStyle = $Button.FlatStyle
$Button_a.Size      = New-Object System.Drawing.Size(220,220)
$Button_a.Image     = [System.Drawing.Image]::FromFile($a_image_path)

# Button to select Digital device
$Button_d           = New-Object System.Windows.Forms.Button
$Button_d.Location  = New-Object System.Drawing.Point(290, 20)
$Button_d.FlatStyle = $Button.FlatStyle
$Button_d.Size      = $Button_a.Size
$Button_d.Image     = [System.Drawing.Image]::FromFile($d_image_path)


# Button to start config with default setting
$Button_go           = New-Object System.Windows.Forms.Button
$Button_go.Location  = New-Object System.Drawing.Point(80,280)
$Button_go.FlatStyle = $Button.FlatStyle
$Button_go.Size      = $Button.Size
$Button_go.Text      = "Go!"

$textboxIP = New-Object System.Windows.Forms.TextBox
$textboxIP.Location = New-Object System.Drawing.Point(175,35)
$textboxIP.Text = $iPEPS_IP

$textboxPW = New-Object System.Windows.Forms.TextBox
$textboxPW.Location = New-Object System.Drawing.Point(175,85)
$textboxPW.Text = $iPEPS_PW

# Create a GroupBox for device selection
$Dev_Groupbox          = New-Object System.Windows.Forms.GroupBox
$Dev_Groupbox.Location = New-Object System.Drawing.Point(10, 10)
$Dev_Groupbox.Size     = New-Object System.Drawing.Size(530, 250)
$Dev_Groupbox.Text     = " Select device "

# Create a Groupbox for the usage information
$Usage_Groupbox          = New-Object System.Windows.Forms.GroupBox
$Usage_Groupbox.Location = New-Object System.Drawing.Point(300, 30)
$Usage_Groupbox.Size     = New-Object System.Drawing.Size(220, 120)
$Usage_Groupbox.Text     = " Usage "

# Create a Label to show usage of this tool
$Label_usage          = New-Object System.Windows.Forms.Label
$Label_usage.Location = new-object System.Drawing.Point(10,20)
$Label_usage.AutoSize = $True

# Set the usage information text
$Label_usage.Text     = "Use this tool after device factory reset `r`n"
$Label_usage.Text     += "  1. Test connection `r`n"
$Label_usage.Text     += "  2. Set admin password `r`n"
$Label_usage.Text     += "  3. Select configuration file `r`n"
$Label_usage.Text     += "  4. Upload configuration file `r`n`r`n"
$Label_usage.Text     += "Restart device"

# Create a Label for Config file
$Label_conf           = New-Object System.Windows.Forms.Label
$Label_conf.AutoSize  = $True
$Label_conf.Location  = new-object System.Drawing.Point(50,190)
$Label_conf.ForeColor = "DarkRed"
$Label_conf.Text      = "No configuration selected!"


# Add Button events
$Button.Add_Click({
    # Check if the input is a valid IP address
    $valid_ip = ( $textboxIP.Text -as [ipaddress] -as [bool] )
    if ($valid_ip) {$iPEPS_IP = $textboxIP.Text}
    else {$statusLabel.Text = "Not IP given, using default"}

    if (Ping_test) {
        # For reference download the current configuration of the device temporarily
        $couldgetconfig = kvmadmintool("getconfig")
            
        if ($couldgetconfig -eq "succeeded") {
            $Script:dev_hw = (Get-Content .\oldconfig.tmp | Select-String -Pattern 'ProductType').ToString().Split("=")[1]
            $Script:dev_fw = (Get-Content .\oldconfig.tmp | Select-String -Pattern 'FirmwareVersion').ToString().Split("=")[1]

            #Write-Host "Found device info: " $dev_hw "fw:"$dev_fw -ForegroundColor Green
        }

        $Button.BackColor = "Green"
        $Button.ForeColor = "White"
        $Button.Text      = "Connected"
        $statusLabel.Text = "Found device on "+$iPEPS_IP+" || Device: "+$dev_hw+", Firmware: "+$dev_fw

        # Cleanup the temporary config file
        Remove-Item oldconfig.tmp
    } 
    else {
        [System.Windows.Forms.MessageBox]::Show("iPEPS console Unreachable.", 'Connection', 'OK', 'Error')
        $Button.BackColor      = 'Red'
        $statusLabel.Text      = "iPEPS device unreachable on "+$iPEPS_IP
        $statusLabel.ForeColor = "Red"

        #Write-Host "Can't find device on" $iPEPS_IP -ForegroundColor Red
    }
})

$Button_pw.Add_Click({

    $file_exist = Test-Path $usersfile -PathType Leaf
    if ($file_exist){
    $couldsetpassword = kvmadmintool("setpasswd")
    }
    else {
        $usersfile = $PSScriptRoot+"\users2.csv"
        # throw an error or something
        $statusLabel.Text = "No users file present"
        $content = @("admin,,", "P4ssword_,,", ("admin,"+$textboxPW.Text+",LMRP"), "test,pAsswd1_,LMR")
        foreach ($line in $content) {Add-Content -Path $usersfile -Value $line}
    }
    if ($couldsetpassword -eq "succeeded"){
        [System.Windows.Forms.MessageBox]::Show("Admin password has been set." , "Password set", "OK", "Information")
        $Button_pw.BackColor = "Green"
        $Button_pw.ForeColor = "White"
        $Button_pw.Text      = "Admin password set"
    }
})

$Button2.Add_Click({
    $Script:inputfile = Get-FileName "~"

    if ($inputfile -eq "") {
        $statusLabel.Text = "Operation Cancelled"
    }
    else {
        Write-Host "Selected Configuration:" $inputfile
        $hw = (Get-Content $inputfile | Select-String -Pattern 'ProductType').ToString().Split("=")[1]
        $fw = (Get-Content $inputfile | Select-String -Pattern 'FirmwareVersion').ToString().Split("=")[1]

        $Label_conf.ForeColor = "DarkGreen"
        $Label_conf.Text      = "Selected Configuration:" + "`r`n"

        # Show some important details of the configuration file
        $Label_conf.Text += $inputfile + "`r`n" + "`r`n"
        $Label_conf.Text += $hw + "`r`n"
        $Label_conf.Text += $fw

        $iscompatible = compatibilitycheck

        if ($iscompatible -eq "true"){
            $Button2.BackColor = "Green" 
            $Button2.ForeColor = "White"
            $Button3.Enabled   = $true
        }
        else {
            $Label_conf.ForeColor = "Red"
            $Button2.BackColor    = "Red"
            $Button3.Enabled      = $false
        }
    }
})

$Button3.Add_Click({    
    $msgBoxInput = [System.Windows.Forms.MessageBox]::Show("This will overwrite device configuration?","You sure?", "OKCancel", 'Warning')
    switch  ($msgBoxInput) {
        'OK' {
            ## kvmadmin -setconfig $inputfile $iPEPS_IP
            $couldsetconfig = kvmadmintool("setconfig")

            if ($couldsetconfig -eq "succeeded") {
                [System.Windows.Forms.MessageBox]::Show("Configuration has been uploaded" , "Success!", "OK", "Information")
                $Button3.BackColor = "Green"
            }
        }
        'Cancel' {
            $statusLabel.Text = "Configuration upload cancelled"
        }
    } 
})

$Button4.Add_Click({
    # Toggle between the panels
    $advanced_Panel.Visible  = !$advanced_Panel.Visible
    $basic_Panel.Visible     = !$basic_Panel.Visible
    # Also change button text accordingly
    if ($basic_Panel.Visible) {$Button4.Text = "Advanced mode"}
    else {$Button4.Text = "Back to basic"}
})

$Button_a.Add_Click({
    $Button_a.BackColor = "DarkCyan"
    $Button_d.BackColor = ""
    $selected_device = "analog"
    ChildForm $statusLabel
})

$Button_d.Add_Click({
    $Button_d.BackColor = "DarkCyan"
    $Button_a.BackColor = ""
    $selected_device = "digital"
    ChildForm $statusLabel
})


# Status Bar Label
[void]$statusStrip.Items.Add($statusLabel)
$statusLabel.AutoSize  = $true
$statusLabel.Text      = "Ready"

# Add elements to the groupboxes
$Usage_Groupbox.Controls.Add($Label_usage)
$Dev_Groupbox.Controls.Add($Button_a)
$Dev_Groupbox.Controls.Add($Button_d)

# Add the elements of the advanced panel
$advanced_elements = @($Button, $textboxIP, $Button_pw, $textboxPW, $Button2, $Button3, $Usage_Groupbox, $Label_conf)
foreach ($item in $advanced_elements) { $advanced_Panel.Controls.Add($item)}

# Add buttons of the basic panel
$basic_Panel.Controls.Add($Dev_Groupbox)

# Add the elements of the main form
$mainform_elements = @($Button4, $advanced_Panel, $basic_Panel, $statusStrip)
foreach ($item in $mainform_elements) { $mainForm.Controls.Add($item)}

# Display the main form
[void]$mainForm.ShowDialog()