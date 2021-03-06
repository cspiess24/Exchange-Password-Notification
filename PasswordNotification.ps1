#Created on December 21, 2013 by Connor Spiess
#Rev. 1.1
#--Rev 1.0--
#Initial Release
#--Rev 1.1--
#Changed config file from a simple text file to an XML file. 
#Previously used to separate powershell scripts. One that was just the script and another that was scripted through an installer. Merged the two scripts into one. 

#Gets the current directory where the script is running from
$myDir = Split-Path -Parent $MyInvocation.MyCommand.Path
#Retrieves config from Settings.xml file
#$info = Get-Content 'C:\Program Files\Password Notification\Config.txt'
[xml]$ConfigFile = Get-Content "$MyDir\Settings.xml"
#Set your company name below. 
$CompanyName = $ConfigFile.Settings.OtherSettings.CompanyName
#Below is where the log of users with expiring passwords will be written.
#Example: C:\Program Files\Password Notification\Log
#If this path does not exist you will need to create the folder structure from above.
$path = $env:PROGRAMFILES + '\Password Notification\Log'
#Set your mail server IP Address or Hostname below
$smtpserver = $ConfigFile.Settings.EmailSettings.SMTPServer
#Set the email From address
$SearchBase = $ConfigFile.Settings.OtherSettings.SearchBase
$FromEmail = $ConfigFile.Settings.EmailSettings.FromEmail
$SupportEmail = $ConfigFile.Settings.EmailSettings.SupportEmail
$MailURL = $ConfigFile.Settings.OtherSettings.MailURL
$HelpdeskURL = $ConfigFile.Settings.OtherSettings.HelpdeskURL
$HelpdeskNumber = $ConfigFile.Settings.OtherSettings.HelpdeskNumber
$logdate = Get-Date -format yyyyMMdd
$Debug = 1

If($Debug -eq 1)
{
    Write-Host "Working Directory=$myDir"
	Write-Host "Company=$CompanyName"
    Write-Host "SmtpServer=$smtpserver" 
    Write-Host "SearchBase=$SearchBase" 
    Write-Host "FromEmail=$FromEmail" 
    Write-Host "SupportEmail=$SupportEmail" 
    Write-Host "MailURL=$MailURL" 
    Write-Host "HelpdeskURL=$HelpdeskURL" 
    Write-Host "HelpdeskNumber=$HelpdeskNumber"
}

Import-Module ActiveDirectory
Get-ADUser -filter * -properties PasswordLastSet,EmailAddress,GivenName,PasswordNeverExpires,PasswordExpired,Enabled -SearchBase $SearchBase |
Where-Object {$_.PasswordNeverExpires -ne "False" -and $_.PasswordExpired -ne "False" -and $_.Enabled -eq "True" -and $_.EmailAddress -ne $null} |
foreach {
   $PasswordSetDate=$_.PasswordLastSet
   $maxPasswordAgeTimeSpan = $null
   $maxPasswordAgeTimeSpan = (Get-ADDefaultDomainPasswordPolicy).MaxPasswordAge 
   $today=get-date
   $ExpiryDate=$passwordSetDate + $maxPasswordAgeTimeSpan
   $daysleft=$ExpiryDate-$today
   $display=$daysleft.days
   $UserName=$_.GivenName
   $EmailAddress=$_.EmailAddress
if ($display -lt 9 -and $display -gt 0){

$EmailBody = @"
	Dear $UserName
  
	Please change your password to prevent loss of access to your $CompanyName systems`n
	If you are on the $CompanyName network proceed with the following:
	 -press ctrl-alt-delete
	 -Select Change Password
	 -Type in your old password and then type the new one (you cannot use one of the previously used passwords)
	 -After the change is complete you will be prompted with information that password has been changed.`n
	If you are not on the $CompanyName network proceed with the following:
	 -Open your web browser and go to $MailURL
	 -Login with you current username and password
	 -In the top right select Options
	 -Select Change Your Password
	 -Type in your old password and then type the new one (you cannot use one of the previously used passwords)
	 -After the change is complete you will be prompted with information that password has been changed.`n
    If you are unable to change your password, please contact the help desk at by entering a ticket through $HelpdeskURL or calling $HelpdeskNumber`n
	With Regards,
	The Help Desk
 
*** This is automatically generated email ***

"@
$subject = "Your Network password will expire in $display day(s) please change your password." 
send-mailmessage -to $_.EmailAddress -From $FromEmail -Subject $subject -body $EmailBody  -smtpserver $smtpserver
Write-Host "Email was sent to $EmailAddress on $today, and current password expires: $ExpiryDate"
Add-Content $path\maillog$logdate.txt  "Email was sent to $EmailAddress on $today, and current password expires: $ExpiryDate"
}
}
Send-MailMessage -To $SupportEmail -From $FromEmail -Subject "Password change log for $today" -Body "This is the log from $today" -Attachments $path\maillog$logdate.txt -SmtpServer $smtpserver
#This will get the current date and go back 15 days. 
$limit = (Get-Date).AddDays(-15)
#Write-Host "$limit and $path"
#This will go into the log folder and delete any files older the 14 days. 
Get-ChildItem -Path $path -Force | Where-Object { !$_.PSIsContainer -and $_.CreationTime -lt $limit } | Remove-Item -Force