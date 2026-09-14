$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$configFile = Join-Path $scriptDir "helper_config.xml"
$inputFile = Join-Path $scriptDir "incoming_qrz_requests.csv"
$sentLogFile = Join-Path $scriptDir "sent_history.csv"
$errorLog = Join-Path $scriptDir "error_log.txt"
$previewFile = Join-Path $scriptDir "last_preview.csv"

function Pause-Enter([string]$Text = "Press Enter to continue") { [void](Read-Host $Text) }
function Encode([string]$s) { return [System.Uri]::EscapeDataString($s) }

function Show-Banner {
    Clear-Host
    Write-Host "====================================================================" -ForegroundColor Cyan
    Write-Host " QRZ CONFIRMATION EMAIL HELPER" -ForegroundColor Cyan
    Write-Host "====================================================================" -ForegroundColor Cyan
    Write-Host " Created by Thomas Bernard - ZL3TOM" -ForegroundColor DarkCyan
    Write-Host " https://zl3tom.com" -ForegroundColor DarkCyan
    Write-Host "====================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Get-XmlText($node, [string]$localName) {
    if ($null -eq $node) { return "" }
    $item = $node.SelectSingleNode("*[local-name()='$localName']")
    if ($null -eq $item) { return "" }
    return [string]$item.InnerText
}

function Proper-Name([string]$s) {
    if ([string]::IsNullOrWhiteSpace($s)) { return "" }
    try { return (Get-Culture).TextInfo.ToTitleCase($s.Trim().ToLower()) }
    catch { return $s.Trim() }
}

function Format-QsoDate([string]$DateText) {
    try {
        $d = [datetime]::ParseExact($DateText, "yyyy-MM-dd", [Globalization.CultureInfo]::InvariantCulture)
        return $d.ToString("d MMMM yyyy", [Globalization.CultureInfo]::GetCultureInfo("en-US"))
    } catch { return $DateText }
}

function SecureToPlain([System.Security.SecureString]$SecureString) {
    $b = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($b) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b) }
}

function Send-SmtpMessage {
    param(
        [string]$Server, [int]$Port, [bool]$EnableSsl,
        [string]$Username, [string]$Password,
        [string]$FromAddress, [string]$FromName,
        [string]$ToAddress, [string]$Subject, [string]$Body
    )
    $mail = New-Object System.Net.Mail.MailMessage
    $smtp = New-Object System.Net.Mail.SmtpClient($Server, $Port)
    try {
        $mail.From = New-Object System.Net.Mail.MailAddress($FromAddress, $FromName)
        [void]$mail.To.Add($ToAddress)
        $mail.Subject = $Subject
        $mail.Body = $Body
        $mail.IsBodyHtml = $false
        $mail.BodyEncoding = [System.Text.Encoding]::UTF8
        $mail.SubjectEncoding = [System.Text.Encoding]::UTF8

        $smtp.EnableSsl = $EnableSsl
        $smtp.UseDefaultCredentials = $false
        $smtp.Credentials = New-Object System.Net.NetworkCredential($Username, $Password)
        $smtp.Timeout = 30000
        $smtp.Send($mail)
    } finally {
        $mail.Dispose()
        $smtp.Dispose()
    }
}

function Get-ProviderPreset {
    while ($true) {
        Show-Banner
        Write-Host "FIRST-LAUNCH SETUP - EMAIL PROVIDER" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "1. Gmail / Google Workspace"
        Write-Host "2. Outlook.com / Hotmail / Live"
        Write-Host "3. Microsoft 365"
        Write-Host "4. Yahoo Mail"
        Write-Host "5. AOL Mail"
        Write-Host "6. Fastmail"
        Write-Host "7. Apple iCloud Mail"
        Write-Host "8. Zoho Mail"
        Write-Host "9. Manual / Other provider"
        Write-Host ""
        $choice = (Read-Host "Select 1-9").Trim()

        switch ($choice) {
            "1" { return [PSCustomObject]@{Provider="Gmail / Google Workspace";Server="smtp.gmail.com";Port=587;Ssl=$true;Hint="Use your full email address. Google accounts using 2-Step Verification can use a Google App Password for apps that do not support Sign in with Google."} }
            "2" { return [PSCustomObject]@{Provider="Outlook.com / Hotmail / Live";Server="smtp-mail.outlook.com";Port=587;Ssl=$true;Hint="Use your full Microsoft email address. Microsoft may restrict password-based SMTP on some accounts. If it is rejected, check your Microsoft account/provider SMTP settings."} }
            "3" { return [PSCustomObject]@{Provider="Microsoft 365";Server="smtp.office365.com";Port=587;Ssl=$true;Hint="Use your full Microsoft 365 email address. SMTP AUTH must be allowed for your mailbox/tenant; some organisations disable it."} }
            "4" { return [PSCustomObject]@{Provider="Yahoo Mail";Server="smtp.mail.yahoo.com";Port=587;Ssl=$true;Hint="Use your full Yahoo email address and a Yahoo third-party app password."} }
            "5" { return [PSCustomObject]@{Provider="AOL Mail";Server="smtp.aol.com";Port=587;Ssl=$true;Hint="Use your full AOL email address. AOL may require an app password for third-party mail programs."} }
            "6" { return [PSCustomObject]@{Provider="Fastmail";Server="smtp.fastmail.com";Port=587;Ssl=$true;Hint="Use your full Fastmail login address and a Fastmail app password. Fastmail Basic does not provide SMTP access."} }
            "7" { return [PSCustomObject]@{Provider="Apple iCloud Mail";Server="smtp.mail.me.com";Port=587;Ssl=$true;Hint="Use your full iCloud Mail address and an Apple app-specific password."} }
            "8" { return [PSCustomObject]@{Provider="Zoho Mail";Server="smtp.zoho.com";Port=587;Ssl=$true;Hint="Use your full Zoho email address. Server details can vary by Zoho account/data centre; use Manual/Other if your Zoho account specifies different settings."} }
            "9" {
                Show-Banner
                Write-Host "MANUAL / OTHER SMTP PROVIDER" -ForegroundColor Yellow
                $srv = (Read-Host "SMTP server (example: smtp.example.com)").Trim()
                [int]$prt = Read-Host "SMTP port (commonly 587)"
                $sslText = (Read-Host "Use TLS/SSL? [Y/N]").Trim().ToUpper()
                return [PSCustomObject]@{Provider="Manual / Other";Server=$srv;Port=$prt;Ssl=($sslText -ne "N");Hint="Use the SMTP credentials and security settings supplied by your email provider."}
            }
            default {
                Write-Host "Please select a number from 1 to 9." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
}

function Run-SetupWizard {
    while ($true) {
        Show-Banner
        Write-Host "FIRST-LAUNCH SETUP WIZARD" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "This setup is saved only after a TEST email succeeds." -ForegroundColor Green
        Write-Host "Your email password/app password is protected using Windows user-specific encryption."
        Write-Host "QRZ credentials are NOT saved and are requested every time you run the helper."
        Write-Host ""

        $operatorName = (Read-Host "Your name (example: Jane Smith)").Trim()
        $primaryCall = (Read-Host "Your primary callsign").Trim().ToUpper()
        $location = (Read-Host "Your location (example: Christchurch, New Zealand)").Trim()
        $website = (Read-Host "Website (optional, press Enter to skip)").Trim()

        if ([string]::IsNullOrWhiteSpace($operatorName) -or [string]::IsNullOrWhiteSpace($primaryCall)) {
            Write-Host "Your name and primary callsign are required." -ForegroundColor Red
            Pause-Enter
            continue
        }

        $preset = Get-ProviderPreset

        Show-Banner
        Write-Host "EMAIL SETUP - $($preset.Provider)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "SMTP server: $($preset.Server)"
        Write-Host "Port:        $($preset.Port)"
        Write-Host "TLS/SSL:     $($preset.Ssl)"
        Write-Host ""
        Write-Host $preset.Hint -ForegroundColor Yellow
        Write-Host ""

        $smtpUser = (Read-Host "SMTP login / username (usually your full email address)").Trim()
        $fromAddress = (Read-Host "From email address (Enter = same as SMTP login)").Trim()
        if ([string]::IsNullOrWhiteSpace($fromAddress)) { $fromAddress = $smtpUser }

        $fromName = (Read-Host "From display name (Enter = $operatorName | $primaryCall)").Trim()
        if ([string]::IsNullOrWhiteSpace($fromName)) { $fromName = "$operatorName | $primaryCall" }

        Write-Host ""
        Write-Host "Enter the SMTP password or APP PASSWORD required by your provider." -ForegroundColor Yellow
        Write-Host "It will not be displayed while you type."
        $securePassword = Read-Host "SMTP password / app password" -AsSecureString
        $plainPassword = SecureToPlain $securePassword

        $testTo = (Read-Host "Send test to (Enter = $fromAddress)").Trim()
        if ([string]::IsNullOrWhiteSpace($testTo)) { $testTo = $fromAddress }

        Write-Host ""
        Write-Host "Sending a test message before saving these settings..." -ForegroundColor Cyan

        $testBody = @"
QRZ Confirmation Email Helper SMTP test

If you received this message, your outgoing email settings are working.

Configured callsign: $primaryCall
Provider: $($preset.Provider)
SMTP server: $($preset.Server):$($preset.Port)

Created by Thomas Bernard - ZL3TOM
https://zl3tom.com
"@

        try {
            Send-SmtpMessage -Server $preset.Server -Port $preset.Port -EnableSsl $preset.Ssl `
                -Username $smtpUser -Password $plainPassword -FromAddress $fromAddress -FromName $fromName `
                -ToAddress $testTo -Subject "QRZ Confirmation Email Helper - SMTP Test" -Body $testBody

            Write-Host ""
            Write-Host "SUCCESS - the test email was sent." -ForegroundColor Green
            Write-Host "The setup will now be saved for future runs." -ForegroundColor Green

            $config = [PSCustomObject]@{
                Version = "1.0"
                OperatorName = $operatorName
                PrimaryCallsign = $primaryCall
                Location = $location
                Website = $website
                Provider = $preset.Provider
                SmtpServer = $preset.Server
                SmtpPort = $preset.Port
                SmtpSsl = $preset.Ssl
                SmtpUsername = $smtpUser
                FromAddress = $fromAddress
                FromName = $fromName
                ProtectedPassword = ($securePassword | ConvertFrom-SecureString)
            }
            $config | Export-Clixml -Path $configFile

            $plainPassword = $null
            Pause-Enter
            return
        }
        catch {
            $plainPassword = $null
            Write-Host ""
            Write-Host "SORRY - the test email failed, so NOTHING was saved." -ForegroundColor Red
            Write-Host ""
            Write-Host "Error:" -ForegroundColor Yellow
            Write-Host $_.Exception.Message
            Write-Host ""
            Write-Host "Common causes include:"
            Write-Host " - wrong username or app password"
            Write-Host " - an app password is required instead of your normal password"
            Write-Host " - SMTP AUTH is disabled by the provider/account"
            Write-Host " - the provider uses different SMTP details"
            Write-Host " - the From address is not allowed by the account"
            Write-Host ""
            $again = (Read-Host "Run email setup again? [Y/N]").Trim().ToUpper()
            if ($again -ne "Y") {
                Write-Host "Setup cancelled. No configuration was saved."
                Pause-Enter
                exit 1
            }
        }
    }
}

function Load-Config {
    if (-not (Test-Path $configFile)) { return $null }
    try {
        $c = Import-Clixml $configFile
        $secure = $c.ProtectedPassword | ConvertTo-SecureString
        return [PSCustomObject]@{
            OperatorName = [string]$c.OperatorName
            PrimaryCallsign = [string]$c.PrimaryCallsign
            Location = [string]$c.Location
            Website = [string]$c.Website
            Provider = [string]$c.Provider
            SmtpServer = [string]$c.SmtpServer
            SmtpPort = [int]$c.SmtpPort
            SmtpSsl = [bool]$c.SmtpSsl
            SmtpUsername = [string]$c.SmtpUsername
            FromAddress = [string]$c.FromAddress
            FromName = [string]$c.FromName
            SecurePassword = $secure
        }
    } catch { return $null }
}

function Get-SentKeyTable {
    $table = @{}
    if (Test-Path $sentLogFile) {
        try {
            Import-Csv $sentLogFile | ForEach-Object {
                if ($_.Status -eq "SENT" -and $_.QSOKey) {
                    $table[$_.QSOKey] = $true
                }
            }
        } catch {}
    }
    return $table
}

function Add-History {
    param($Item, [string]$Status, [string]$Details)
    foreach ($date in $Item.RawDates) {
        $key = "$($Item.MyCallsign)|$($Item.Callsign)|$date"
        $row = [PSCustomObject]@{
            TimestampLocal = [DateTimeOffset]::Now.ToString("yyyy-MM-dd HH:mm:ss zzz")
            Status = $Status
            QSOKey = $key
            MyCallsign = $Item.MyCallsign
            TheirCallsign = $Item.Callsign
            QSODate = $date
            Recipient = $Item.ToEmail
            Operator = $Item.OperatorDisplay
            Subject = $Item.Subject
            Details = $Details
        }
        if (Test-Path $sentLogFile) {
            $row | Export-Csv $sentLogFile -NoTypeInformation -Encoding UTF8 -Append
        } else {
            $row | Export-Csv $sentLogFile -NoTypeInformation -Encoding UTF8
        }
    }
}

try {
    if (-not (Test-Path $configFile)) {
        Run-SetupWizard
    }

    $cfg = Load-Config
    if ($null -eq $cfg) {
        Show-Banner
        Write-Host "The saved setup could not be read." -ForegroundColor Red
        Write-Host "Run RESET_SETUP.bat and configure the helper again."
        Pause-Enter
        exit 1
    }

    Show-Banner
    Write-Host "IMPORTANT - QRZ XML SUBSCRIPTION REQUIRED" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This helper uses QRZ's XML data service to retrieve operator information"
    Write-Host "such as name and email address. A QRZ subscription that provides XML"
    Write-Host "Logbook Data access is required for the full lookup data used by this tool."
    Write-Host ""
    Write-Host "QRZ LOGIN IS REQUIRED EVERY TIME." -ForegroundColor Green
    Write-Host "Your QRZ username/password are never saved by this helper."
    Write-Host ""
    Pause-Enter "Press Enter to continue to QRZ Login"

    Show-Banner
    Write-Host "QRZ LOGIN" -ForegroundColor Yellow
    Write-Host ""
    $qrzUser = (Read-Host "QRZ username / callsign").Trim()
    $qrzSecure = Read-Host "QRZ password (hidden)" -AsSecureString
    $qrzPassword = SecureToPlain $qrzSecure

    Write-Host ""
    Write-Host "Signing in to QRZ XML..." -ForegroundColor Cyan

    $loginUrl = "https://xmldata.qrz.com/xml/current/?username=$(Encode $qrzUser)&password=$(Encode $qrzPassword)&agent=QRZConfirmationEmailHelper-1.0-ZL3TOM"
    [xml]$loginXml = (Invoke-WebRequest -Uri $loginUrl -UseBasicParsing -TimeoutSec 30).Content
    $qrzPassword = $null
    $qrzSecure = $null

    $session = $loginXml.SelectSingleNode("//*[local-name()='Session']")
    $sessionKey = Get-XmlText $session "Key"
    if ([string]::IsNullOrWhiteSpace($sessionKey)) {
        $err = Get-XmlText $session "Error"
        if ([string]::IsNullOrWhiteSpace($err)) { $err = "QRZ did not return a session key." }
        throw "QRZ login failed: $err"
    }

    Write-Host "QRZ login successful." -ForegroundColor Green
    Write-Host ""

    if (-not (Test-Path $inputFile)) {
        throw "incoming_qrz_requests.csv was not found. See README.txt for the required CSV format."
    }

    $rows = @(Import-Csv $inputFile)
    if ($rows.Count -eq 0) {
        throw "incoming_qrz_requests.csv contains no request rows."
    }

    foreach ($required in @("their_callsign","qso_date","my_callsign")) {
        if (-not ($rows[0].PSObject.Properties.Name -contains $required)) {
            throw "CSV is missing required column: $required"
        }
    }

    $sentKeys = Get-SentKeyTable
    $newRows = @()
    $oldRows = @()

    foreach ($r in $rows) {
        $their = ([string]$r.their_callsign).Trim().ToUpper()
        $mine = ([string]$r.my_callsign).Trim().ToUpper()
        $date = ([string]$r.qso_date).Trim()

        if ([string]::IsNullOrWhiteSpace($their) -or [string]::IsNullOrWhiteSpace($mine) -or [string]::IsNullOrWhiteSpace($date)) {
            continue
        }

        try {
            [void][datetime]::ParseExact($date, "yyyy-MM-dd", [Globalization.CultureInfo]::InvariantCulture)
        } catch {
            throw "Invalid date '$date' for $their. Dates must use YYYY-MM-DD, for example 2026-09-14."
        }

        $key = "$mine|$their|$date"
        if ($sentKeys.ContainsKey($key)) { $oldRows += $r }
        else { $newRows += $r }
    }

    Write-Host "Requests loaded:       $($rows.Count)"
    Write-Host "Already emailed:       $($oldRows.Count)" -ForegroundColor Yellow
    Write-Host "New requests to check: $($newRows.Count)" -ForegroundColor Green
    Write-Host ""

    if ($newRows.Count -eq 0) {
        Write-Host "There are no new requests to email." -ForegroundColor Green
        Pause-Enter
        exit 0
    }

    $groups = $newRows | Group-Object their_callsign, my_callsign
    $items = @()

    Write-Host "Looking up operators on QRZ..." -ForegroundColor Cyan

    foreach ($g in $groups) {
        $first = $g.Group[0]
        $theirCall = $first.their_callsign.Trim().ToUpper()
        $myCall = $first.my_callsign.Trim().ToUpper()

        Write-Host "  $theirCall"
        $lookupUrl = "https://xmldata.qrz.com/xml/current/?s=$(Encode $sessionKey)&callsign=$(Encode $theirCall)"
        [xml]$x = (Invoke-WebRequest -Uri $lookupUrl -UseBasicParsing -TimeoutSec 30).Content

        $callNode = $x.SelectSingleNode("//*[local-name()='Callsign']")
        $lookupSession = $x.SelectSingleNode("//*[local-name()='Session']")

        $email = ""; $fname = ""; $lname = ""; $nickname = ""; $nameFmt = ""; $country = ""; $lookupNote = ""
        if ($callNode) {
            $email = Get-XmlText $callNode "email"
            $fname = Get-XmlText $callNode "fname"
            $lname = Get-XmlText $callNode "name"
            $nickname = Get-XmlText $callNode "nickname"
            $nameFmt = Get-XmlText $callNode "name_fmt"
            $country = Get-XmlText $callNode "country"
        } else {
            $lookupNote = ((Get-XmlText $lookupSession "Error") + " " + (Get-XmlText $lookupSession "Message")).Trim()
        }

        $fp = Proper-Name $fname
        $lp = Proper-Name $lname
        $np = Proper-Name $nickname
        $fullName = if ($nameFmt) { $nameFmt.Trim() } elseif (($fp + " " + $lp).Trim()) { ($fp + " " + $lp).Trim() } else { "" }
        $greetName = if ($np) { $np } elseif ($fp) { ($fp -split "\s+")[0] } else { "" }
        $greeting = if ($greetName) { "Hi $greetName ($theirCall)," } else { "Hi $theirCall," }
        $operatorDisplay = if ($fullName) { "$fullName ($theirCall)" } else { $theirCall }

        $rawDates = @($g.Group | Sort-Object qso_date | ForEach-Object { $_.qso_date.Trim() })
        $prettyDates = @($rawDates | ForEach-Object { Format-QsoDate $_ })
        $dateLines = ($prettyDates | ForEach-Object { " - $_" }) -join "`r`n"
        $count = $rawDates.Count

        if ($count -eq 1) {
            $intro = "I'm currently going through my QRZ Logbook and noticed that I have an outstanding confirmation request from you for our QSO on $($prettyDates[0]) using my callsign $myCall."
            $clear = "I'd really like to get this outstanding request cleared up and our contact properly confirmed on QRZ."
            $dateHeading = "The QSO date showing on QRZ is:"
            $ask = "Would you please be able to check your original log and send me the details you have recorded for this contact?"
            $finish = "Once I have the details, I'll enter/check them in my $myCall QRZ Logbook so hopefully we can get the outstanding confirmation matched and cleared."
            $thanks = "Thank you very much for your help, and thank you for the QSO!"
            $subject = "QRZ Logbook confirmation - $myCall / $theirCall"
        } else {
            $intro = "I'm currently going through my QRZ Logbook and noticed that I have $count outstanding confirmation requests from you for QSOs using my callsign $myCall."
            $clear = "I'd really like to get these outstanding requests cleared up and our contacts properly confirmed on QRZ."
            $dateHeading = "The QSO dates showing in my QRZ confirmation requests are:"
            $ask = "Would you please be able to check your original log and send me the details you have recorded for each of these contacts?"
            $finish = "Once I have the details, I'll enter/check them in my $myCall QRZ Logbook so hopefully we can get the outstanding confirmations matched and cleared."
            $thanks = "Thank you very much for taking the time to help me sort these out, and thank you for our QSOs!"
            $subject = "QRZ Logbook confirmations ($count QSOs) - $myCall / $theirCall"
        }

        $signature = "73,`r`n`r`n$($cfg.OperatorName) | $myCall`r`nAmateur Radio Operator"
        if (-not [string]::IsNullOrWhiteSpace($cfg.Location)) { $signature += "`r`n$($cfg.Location)" }
        if (-not [string]::IsNullOrWhiteSpace($cfg.Website)) { $signature += "`r`n$($cfg.Website)" }
        $signature += "`r`n$($cfg.FromAddress)"
        $signature += "`r`nQRZ: https://www.qrz.com/db/$myCall"
        $signature += "`r`n`r`n73 & Good DX!"

        $body = @"
$greeting

$($cfg.OperatorName) here, $myCall.

$intro

$clear Unfortunately, I don't have all of the original QSO details needed to correctly match the contact(s).

$dateHeading

$dateLines

$ask

For each QSO, I need:

 - UTC time
 - Band or frequency
 - Mode

You can simply reply to this email with the information from your original log.

$finish

Please send the details you genuinely have recorded rather than changing or guessing anything just to make the confirmation match. I want to make sure my log is accurate as well.

$thanks

$signature
"@

        $items += [PSCustomObject]@{
            ToEmail = $email
            FullName = $fullName
            OperatorDisplay = $operatorDisplay
            Callsign = $theirCall
            MyCallsign = $myCall
            Country = $country
            QSOCount = $count
            RawDates = $rawDates
            QSODates = ($rawDates -join "; ")
            Subject = $subject
            Message = $body
            QRZLookupNote = $lookupNote
            Approved = $false
        }

        Start-Sleep -Milliseconds 250
    }

    $items | Select-Object ToEmail,FullName,Callsign,MyCallsign,Country,QSOCount,QSODates,Subject,QRZLookupNote |
        Export-Csv $previewFile -NoTypeInformation -Encoding UTF8

    $reviewable = @($items | Where-Object { -not [string]::IsNullOrWhiteSpace($_.ToEmail) })
    $noEmail = @($items | Where-Object { [string]::IsNullOrWhiteSpace($_.ToEmail) })

    Write-Host ""
    Write-Host "Email addresses found: $($reviewable.Count)" -ForegroundColor Green
    Write-Host "No email returned:     $($noEmail.Count)" -ForegroundColor Yellow

    if ($noEmail.Count -gt 0) {
        Write-Host ""
        Write-Host "No email address was returned by QRZ for:" -ForegroundColor Yellow
        foreach ($n in $noEmail) {
            Write-Host "  $($n.Callsign) - $($n.QRZLookupNote)"
        }
    }

    Write-Host ""
    Write-Host "Nothing has been sent. You will now preview each available email." -ForegroundColor Green
    Pause-Enter

    foreach ($item in $reviewable) {
        while ($true) {
            Show-Banner
            Write-Host "EMAIL PREVIEW - NOTHING SENT YET" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "TO:          $($item.ToEmail)"
            Write-Host "OPERATOR:    $($item.OperatorDisplay)"
            Write-Host "THEIR CALL:  $($item.Callsign)"
            Write-Host "YOUR CALL:   $($item.MyCallsign)"
            Write-Host "COUNTRY:     $($item.Country)"
            Write-Host "QSO DATES:   $($item.QSODates)"
            Write-Host ""
            Write-Host "SUBJECT:" -ForegroundColor Cyan
            Write-Host $item.Subject
            Write-Host ""
            Write-Host "MESSAGE:" -ForegroundColor Cyan
            Write-Host "--------------------------------------------------------------------"
            Write-Host $item.Message
            Write-Host "--------------------------------------------------------------------"
            Write-Host ""
            $answer = (Read-Host "[A] Approve  [S] Skip  [Q] Stop reviewing").Trim().ToUpper()
            if ($answer -eq "A") { $item.Approved = $true; break }
            if ($answer -eq "S") { $item.Approved = $false; break }
            if ($answer -eq "Q") { break 2 }
        }
    }

    $approved = @($items | Where-Object { $_.Approved })

    Show-Banner
    Write-Host "FINAL SEND REVIEW" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Approved emails: $($approved.Count)"
    Write-Host "Provider:        $($cfg.Provider)"
    Write-Host "From:            $($cfg.FromName) <$($cfg.FromAddress)>"
    Write-Host ""

    foreach ($a in $approved) {
        Write-Host "  $($a.OperatorDisplay) <$($a.ToEmail)> - $($a.MyCallsign) - $($a.QSODates)"
    }

    if ($approved.Count -eq 0) {
        Write-Host ""
        Write-Host "Nothing approved, so nothing will be sent."
        Pause-Enter
        exit 0
    }

    Write-Host ""
    $confirm = Read-Host "Type SEND exactly to transmit the approved messages"
    if ($confirm -cne "SEND") {
        Write-Host "Cancelled. Nothing sent."
        Pause-Enter
        exit 0
    }

    $smtpPassword = SecureToPlain $cfg.SecurePassword
    $sent = 0
    $failed = 0

    foreach ($item in $approved) {
        Write-Host "Sending to $($item.OperatorDisplay)..." -NoNewline
        try {
            Send-SmtpMessage -Server $cfg.SmtpServer -Port $cfg.SmtpPort -EnableSsl $cfg.SmtpSsl `
                -Username $cfg.SmtpUsername -Password $smtpPassword `
                -FromAddress $cfg.FromAddress -FromName $cfg.FromName `
                -ToAddress $item.ToEmail -Subject $item.Subject -Body $item.Message

            Write-Host " SENT" -ForegroundColor Green
            Add-History -Item $item -Status "SENT" -Details "Sent successfully."
            $sent++
        } catch {
            Write-Host " FAILED" -ForegroundColor Red
            Add-History -Item $item -Status "FAILED" -Details $_.Exception.Message
            $failed++
        }
        Start-Sleep -Seconds 2
    }

    $smtpPassword = $null

    Write-Host ""
    Write-Host "Finished." -ForegroundColor Green
    Write-Host "Sent:   $sent"
    Write-Host "Failed: $failed"
    Write-Host ""
    Write-Host "Successful QSO requests are remembered in sent_history.csv."
    Write-Host "If the same callsign + your callsign + date appears again, it is skipped."
    Pause-Enter
}
catch {
    $message = @"
[$([DateTimeOffset]::Now.ToString("yyyy-MM-dd HH:mm:ss zzz"))]
$($_.Exception.ToString())

"@
    Add-Content -Path $errorLog -Value $message -Encoding UTF8

    Write-Host ""
    Write-Host "====================================================================" -ForegroundColor Red
    Write-Host " THE PROGRAM STOPPED WITH AN ERROR" -ForegroundColor Red
    Write-Host "====================================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host $_.Exception.Message -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Full technical details were saved to:"
    Write-Host $errorLog
    Write-Host ""
    Pause-Enter
    exit 1
}
