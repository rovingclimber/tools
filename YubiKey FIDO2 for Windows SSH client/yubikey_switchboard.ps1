# ==============================================================================
# YubiKey SSH Switchboard
# ==============================================================================

# --- Hardware Guard ---
# Check if a Yubico device is actually present. Exit silently if not.
if (-not (Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -match "VID_1050" })) {
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$sshDir = Join-Path $HOME ".ssh"
$configFile = Join-Path $sshDir "config"

# Static Mapping Table
$KeyMap = @{
    "YubiKey 18061656"     = "id_ed25519_sk_rk_justin1_6a757374696e31407373680097ee7b0e42e0e023bce2915d1cfe09dae87a1a12"
    "YubiKey 12022824"     = "id_ed25519_sk_rk_justin2_6a757374696e324073736800f897beee994cc8d9944b7c67e4bb99eceb0eb05a"
    "YubiKey BIO 17290719" = "id_ed25519_sk_rk_justin3_6a757374696e334073736800bda6abebbcc00b8eaabe4840a53e6192396a1d49"
}

# --- GUI Setup ---
$form = New-Object Windows.Forms.Form
$form.Text = "YubiKey SSH Switchboard"
$form.Size = New-Object Drawing.Size(400, 360)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.TopMost = $true
$form.BackColor = [Drawing.Color]::FromArgb(30, 30, 30)

# (Remainder of GUI code from previous version...)
$label = New-Object Windows.Forms.Label
$label.Text = "Select Active YubiKey"
$label.ForeColor = [Drawing.Color]::White
$label.Font = New-Object Drawing.Font("Segoe UI", 14, [Drawing.FontStyle]::Bold)
$label.Location = New-Object Drawing.Point(20, 20)
$label.Size = New-Object Drawing.Size(360, 30)
$label.TextAlign = "MiddleCenter"
$form.Controls.Add($label)

$timeLeft = 10
$timerLabel = New-Object Windows.Forms.Label
$timerLabel.Text = "Closing in $($timeLeft)s..."
$timerLabel.ForeColor = [Drawing.Color]::DimGray
$timerLabel.Font = New-Object Drawing.Font("Segoe UI", 8)
$timerLabel.Location = New-Object Drawing.Point(20, 50)
$timerLabel.Size = New-Object Drawing.Size(360, 20)
$timerLabel.TextAlign = "MiddleCenter"
$form.Controls.Add($timerLabel)

$autoCloseTimer = New-Object Windows.Forms.Timer
$autoCloseTimer.Interval = 1000
$autoCloseTimer.Add_Tick({
    $script:timeLeft--
    $timerLabel.Text = "Closing in $($script:timeLeft)s..."
    if ($script:timeLeft -le 0) { $autoCloseTimer.Stop(); $form.Close() }
})
$autoCloseTimer.Start()

$yPos = 80
foreach ($keyName in $KeyMap.Keys | Sort-Object) {
    $btn = New-Object Windows.Forms.Button
    $btn.Text = $keyName
    $btn.Location = New-Object Drawing.Point(50, $yPos)
    $btn.Size = New-Object Drawing.Size(300, 45)
    $btn.FlatStyle = "Flat"
    $btn.ForeColor = [Drawing.Color]::White
    $btn.BackColor = [Drawing.Color]::FromArgb(60, 60, 60)
    $btn.Add_MouseEnter({ $this.BackColor = [Drawing.Color]::FromArgb(0, 120, 215) })
    $btn.Add_MouseLeave({ $this.BackColor = [Drawing.Color]::FromArgb(60, 60, 60) })
    $btn.Add_Click({
        $autoCloseTimer.Stop()
        $fileName = $KeyMap[$this.Text]
        Set-Content -Path $configFile -Value "Host *`n    IdentityFile ~/.ssh/$fileName`n    IdentityAgent none`n    IdentitiesOnly yes"
        $this.BackColor = [Drawing.Color]::ForestGreen
        Start-Sleep -Seconds 1
        $form.Close()
    })
    $form.Controls.Add($btn)
    $yPos += 60
}

$form.ShowDialog() | Out-Null