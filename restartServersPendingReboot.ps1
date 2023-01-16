<# 
Simple script to reboot servers that have a pending reboot.
Perfect for admins that wants to have control of servers with the status "pending reboot"(not rebooting servers with pending updates).
Feel free to improve it.
In my case the script is scheduled in task scheduler at night.
Regards Martin Oskarsson.
#> 

# hostnames that will be checked if there is a pending restart.
$companyServers = @(
"server_1",
"server_2",
"server_3",
"server_4",
"server_5",
"server_6",
"server_7")

$serversPendingReboot = @()
$Logfile = "C:\users\$env:UserName\desktop\rebootlog.log"
function WriteLog
{
Param ([string]$LogString)
$Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
$LogMessage = "$Stamp $LogString"
Add-content $LogFile -value $LogMessage
}
$pendingReboot = @(
    @{
        Name = 'Reboot Pending Status: '
        Test = { Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'}
    }
    @{
        Name = 'Reboot Required by Windows Update: '
        Test = { Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'}
    })

foreach($server in $companyServers){

        $computername = $server
        $session = New-PSSession -Computer $computername
        Write-Host "`n SERVERNAMN $computername"

        foreach ($test in $pendingReboot) {
            $result = Invoke-Command -Session $session -ScriptBlock $test.Test
            $test.Name + $result
            $getstatus = $result.ToString()
            if($getstatus -eq "True"){$serversPendingReboot += $computername}
        }
}
# remove duplicates(as duplicates can occur if a server has pending reboot beacause of two registery values: "RebootPending", and "RebootRequired")
$serversPendingReboot = $serversPendingReboot | select -Unique

# remove session
Get-PSSession | Remove-PSSession

$cnt = 1

$ServerAmount = $serversPendingReboot.Count

WriteLog "[reboot script for windows update] Starting reboot script for Windows update..."
WriteLog "[reboot script for windows update] The following servers will be scheduled for instant reboot: $serversPendingReboot"

foreach ($serv in $serversPendingReboot) {

Write-Host "Script is now rebooting servers that requires a reboot(beacause of recently installed updates). This will take around 1 hour... Check the logfile at $Logfile for more details."
    try{

     Restart-Computer -ComputerName $serv -Force
     WriteLog "[reboot script for windows update] $serv have a restart pending. Restarting it now... [server $cnt/$ServerAmount]"
     WriteLog "[reboot script for windows update] A reboot have been scheduled asap for server $serv. Pausing 5 minutes before moving on to next server..."
     
     # in my case im initiating a sleep beacause some of our servers cant be offline at the same time.
     Start-Sleep 300

    }

    catch{

    WriteLog "[reboot script for windows update] Error. Couldn't restart $serv for pending updates. Try to restart the server manually instead..."
    WriteLog "[reboot script for windows update] Moving on to the next server in the list..."
    }

    $cnt++

    # if you have a internal mail server, it will attatch the log & send it to the e-mail provided. Just enter the ip for your mail server(smtp).

    if($ServerAmount -eq $cnt){    
        $fromaddress = "mail@mail.se"
        $toaddress = "mail@mail.se"
        $Subject = "Servers have been rebooted for updates. Log attatched."
        $body = ""
        $attachment = "C:\users\$env:UserName\desktop\rebootlog.log"
        $smtpserver = “192.168.XX.XX”
        $message = new-object System.Net.Mail.MailMessage
        $message.From = $fromaddress
        $message.To.Add($toaddress)
        $message.IsBodyHtml = $False
        $message.Subject = $Subject
        $attach = new-object Net.Mail.Attachment($attachment)
        $message.Attachments.Add($attach)
        $message.body = $body
        $smtp = new-object Net.Mail.SmtpClient($smtpserver)
        $smtp.Send($message)
    }
}
