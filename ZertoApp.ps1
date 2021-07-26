#Author Soundarraj.Ramasamy
#Version 1.0
#Date: 01-07-2021





#region SMTP Configuration
#-------------------------

Param (

    [parameter(
                Mandatory=$false,
                HelpMessage='SMTP Server Address (Like IP address, hostname or FQDN)')]
            
                [string]$MailServer = "SMTP IP",

    [parameter(
                Mandatory=$false,
                HelpMessage='Recipient e-mail address')]
               
                [array]$MailTo = "XYZ@XYZ.COM",

  [parameter(
                Mandatory=$false,
                HelpMessage='Recipient e-mail address')]
               
                [array]$MailCc = "XYZ@XYZ.COM",

    [parameter(
                Mandatory=$false,
                HelpMessage='Recipient e-mail address')]
               
                [array]$MailBcc = "XYZ@XYZ.COM",

    [parameter(
                Mandatory=$false,
                HelpMessage='Sender e-mail address')]
               
                [string]$MailFrom = "Zerto-Daily-Replication-Report@localhost.com"  
)
#endregion SMTP Configuration

################################################
# Configure the variables below
################################################
$LogDataDir = "C:\LogFolder\"
$ZertoServer = "Zerto IP"
$ZertoPort = "9669"
$ZertoUser = "Zerto User Name"
$ZertoPassword = "Zerto Password"
$ZORG = "Z-ORG"



#region Variables
#----------------

# State Colors
[array]$stateBgColors = "", "#ACFA58","#E6E6E6","#FB7171","#FBD95B","#BDD7EE" #0-Null, 1-Online(green), 2-Offline(grey), 3-Failed/Critical(red), 4-Warning(orange), 5-Other(blue)
[array]$stateWordColors = "", "#298A08","#848484","#A40000","#9C6500","#204F7A","#FFFFFF" #0-Null, 1-Online(green), 2-Offline(grey), 3-Failed/Critical(red), 4-Warning(orange), 5-Other(blue), 6-White

Clear-Variable -Name OutVMList

# Date and Time
$Date = Get-Date -Format d/MMM/yyyy
$Time = Get-Date -Format "hh:mm:ss tt"
$TimeZone = Get-TimeZone


################################################
# Setting Cert Policy - required for successful auth with the Zerto API without connecting to vsphere using PowerCLI
################################################
add-type @"
 using System.Net;
 using System.Security.Cryptography.X509Certificates;
 public class TrustAllCertsPolicy : ICertificatePolicy {
 public bool CheckValidationResult(
 ServicePoint srvPoint, X509Certificate certificate,
 WebRequest request, int certificateProblem) {
 return true;
 }
 }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy


################################################ 
# Building Zerto API string and invoking API 
################################################ 
$BaseURL = "https://" + $ZertoServer + ":"+$ZertoPort+"/v1/" 
# Authenticating with Zerto APIs 
$xZertoSessionURL = $BaseURL + "session/add" 
$AuthInfo = ("{0}:{1}" -f $ZertoUser,$ZertoPassword) 
$AuthInfo = [System.Text.Encoding]::UTF8.GetBytes($AuthInfo) 
$AuthInfo = [System.Convert]::ToBase64String($AuthInfo) 
$Headers = @{Authorization=("Basic {0}" -f $AuthInfo)} 
$SessionBody = '{"AuthenticationMethod": "1"}' 
$TypeJSON = "application/JSON" 
$TypeXML = "application/XML" 
Try  
{ 
$xZertoSessionResponse = Invoke-WebRequest -Uri $xZertoSessionURL -Headers $Headers -Method POST -Body $SessionBody -ContentType $TypeJSON 
} 
Catch { 
Write-Host $_.Exception.ToString() 
$error[0] | Format-List -Force 
} 
$xZertoSessionResponse = Invoke-WebRequest -Uri $xZertoSessionURL -Headers $headers -Method POST -Body $sessionBody -ContentType $TypeJSON 
#Extracting x-zerto-session from the response, and adding it to the actual API 
$xZertoSession = $xZertoSessionResponse.headers.get_item("x-zerto-session") 
$ZertoSessionHeader = @{"x-zerto-session"=$xZertoSession; "Accept"=$TypeJSON}

# Querying API 
$VMListURL = $BaseURL+"vms" 
$VMList = Invoke-RestMethod -Uri $VMListURL -TimeoutSec 100 -Headers $zertoSessionHeader -ContentType $TypeJSON 
# $VMListTable = $VMList | select  VmName, Priority, ThroughputInMB, OutgoingBandWidthInMbps, LastTest
# $VMListTable | format-table -AutoSize 


#region HTML Start
#----------------


# HTML Head
$outHtmlStart = "<!DOCTYPE html>
<html>
<head> 
<title> Zerto AG Daily Report </title>
<style>
/*Reset CSS*/
html, body, div, span, applet, object, iframe, h1, h2, h3, h4, h5, h6, p, blockquote, pre, a, abbr, acronym, address, big, cite, code, del, dfn, em, img, ins, kbd, q, s, samp,
small, strike, strong, sub, sup, tt, var, b, u, i, center, dl, dt, dd, ol, ul, li, fieldset, form, label, legend, table, caption, tbody, tfoot, thead, tr, th, td,
article, aside, canvas, details, embed, figure, figcaption, footer, header, hgroup, menu, nav, output, ruby, section, summary, 
time, mark, audio, video {margin: 0;padding: 0;border: 0;font-size: 100%;font: inherit;vertical-align: baseline;}
ol, ul {list-style: none;}
blockquote, q {quotes: none;}
blockquote:before, blockquote:after,
q:before, q:after {content: '';content: none;}
table {border-collapse: collapse;border-spacing: 0;}
/*Reset CSS*/

body{
    width:100%;
    min-width:1024px;
    font-family: Verdana, sans-serif;
    font-size:14px;
    line-height:1.5;
    color:#222222;
    background-color:#fcfcfc;
}

p{
    color:222222;
}

strong{
    font-weight:600;
}

h1{
    font-size:30px;
    font-weight:300;
}

h2{
    font-size:20px;
    font-weight:300;
}

#ReportBody{
    width:95%;
    height:500;
    margin: 0 auto;
}

table{
    width:100%;
    min-width:1280px;
    border: 1px solid #CCCCCC;
}

/*Row*/
tr{
    font-size: 12px;
}

/*Column*/
td {
    padding:10px 8px 10px 8px;
    font-size: 12px;
    border: 1px solid #CCCCCC;
    text-align:center;
    vertical-align:middle;
}

/*Table Heading*/
th {
    background: #f3f3f3;
    border: 1px solid #CCCCCC;
    font-size: 14px;
    font-weight:normal;
    padding:12px;
    text-align:center;
    vertical-align:middle;
}

.Deployment-Overview{
    width:100%;
    float:left;
    margin-bottom:30px;
}

table#Deployment-Overview-Table tr:nth-child(odd){
    background:#F9F9F9;
}

.Roles{
    width:100%;
    float:left;
    margin-bottom:30px;
}

table#Roles-Table tr:nth-child(odd){
    background:#F9F9F9;
}

.GateWay{
    width:100%;
    float:left;
    margin-bottom:30px;
}

table#GateWay-Table tr:nth-child(odd){
    background:#F9F9F9;
}

.Session-Host{
    width:100%;
    float:left;
    margin-bottom:30px;
}

table#Session-Host-Table tr:nth-child(odd){
    background:#F9F9F9;
}

.Virtualization-Host{
    width:100%;
    float:left;
    margin-bottom:22px;
    line-height:1.5;
}

table#Virtualization-Host-Table tr:nth-child(odd){
    background:#F9F9F9;
}
</style>
</head>
<body>
<br><br>


<center><b><p style=""font-size:30px;color:#4989c7"">TATA Communications Ltd</p></b></center>
<center><p style=""font-size:18px;color:#4989c7"">Zerto Replication Daily Report</p></center>
<center><p style=""font-size:12px;color:#4989c7"">Generated on $($Date) at $($Time) $($TimeZone.Id)</p></center>


<br>
<div id=""ReportBody""><!--Start ReportBody-->"
#endregion HTML Start



#region Gathering Zerto Details Start

#Roles-Table Heade

    $outVMs="
    <div class=""VMDeatils""><!--VMDeatils-->
        
        <table id=""VMDeatils-Table"">
        <tbody>
            <tr><!--Header Line-->
                <th><p style=""text-align:left;margin-left:-4px"">VM Name</p></th>
                <th><p style=""text-align:left;margin-left:-4px"">VPG Name</p></th>
				<th><p style=""text-align:left;margin-left:-4px"">Priority</p></th>
				<th><p style=""text-align:left;margin-left:-4px"">Provisioned Storage</p></th>
                <th><p style=""text-align:left;margin-left:-4px"">Used Storage</p></th>
                <th><p style=""text-align:left;margin-left:-4px"">IOPs</p></th>
                <th><p style=""text-align:left;margin-left:-4px"">Throughput</p></th>
                <th><p style=""text-align:left;margin-left:-4px"">BandWidth</p></th>
                <th><p style=""text-align:left;margin-left:-4px"">Actual RPO</p></th>
                <th><p style=""text-align:left;margin-left:-4px"">Last Failover Test</p></th>
            </tr>"

             foreach ($VMList in $VMList)
            {
                if ($VMList.OrganizationName -eq $ZORG)
                {

                    $ProvisionedStorage = ($VMList.ProvisionedStorageInMB / 1024)
                    $ProvisionedStorageGB = [math]::round($ProvisionedStorage)

                    $UsedStorage = ($VMList.UsedStorageInMB / 1024)
                    $UsedStorageGB = [math]::round($UsedStorage)

                    $ThroughputMbps = [math]::round($VMList.ThroughputInMB,2)
                    $OutgoingBandWidthInMbps = [math]::round($VMList.OutgoingBandWidthInMbps,2)

          

                    $OutVMList +="
                    <tr><!--Data Line-->
                        <td><p style=""text-align:left;"">$($VMList.VmName)</p></td>
                        <td><p style=""text-align:left;"">$($VMList.VpgName)</p></td>"


                        if ($VMList.Priority -eq '0')
                                {
                                    $OutVMList +="<td bgcolor=""#E6E6E6""><p style=""text-align:left;"">Low</p></td>"
                                }

                        if ($VMList.Priority -eq '1')
                                {
                                    $OutVMList +="<td bgcolor=""#ACFA58""><p style=""text-align:left;"">Medium</p></td>"
                                }
                        if ($VMList.Priority -eq '2')
                                {
                                    $OutVMList +="<td bgcolor=""#FBD95B""><p style=""text-align:left;"">High</p></td>"
                                }         



                    $OutVMList +="
                        
                        <td><p style=""text-align:left;"">$ProvisionedStorageGB GB</p></td>
                        <td><p style=""text-align:left;"">$UsedStorageGB GB</p></td>
                        <td><p style=""text-align:left;"">$($VMList.IOPs) Ps</p></td>
                        <td><p style=""text-align:left;"">$ThroughputMbps Mbps</p></td>
                        <td><p style=""text-align:left;"">$OutgoingBandWidthInMbps Mbps</p></td>"

                            
                        if ($VMList.ActualRPO -gt '360')
                                {
                                    $OutVMList +="<td bgcolor=""#FB7171""><p style=""text-align:left;"">RPO Breached</p></td>"
                                }

                                else 
                                    {
                                        $OutVMList +="<td><p style=""text-align:left;"">$($VMList.ActualRPO)Sec</p></td>"
                                    }

                        if ($VMList.LastTest -eq $Null)
                                {
                                    $OutVMList +="<td bgcolor=""#FB7171""><p style=""text-align:left;"">Test Failover Required</p></td>"
                                }

                                else 
                                    {
                                        $OutVMList +="<td><p style=""text-align:left;"">$($VMList.LastTest)Sec</p></td>"
                                    }
                    
                    $OutVMList +="
                    </tr>"
                }
            }

     $outVMsEND +="
            </tbody>
        </table>
    </div> <!--End GateWay Class-->
"

#endregion


#region HTML End
#---------------

$outHtmlEnd ="
</div><!--End ReportBody--><br>
<p style=""font-size:8px;color:#4989c7""> * This (Point in Time) report only to check the status of VM replication</p><br>
<center><p style=""font-size:12px;color:#4989c7""> Version: 1.1 | Tata Communications Ltd | 2021 </p></center>
<br>
</body>
</html>"

#endregion

$outFullHTML = $outHtmlStart + $outVMs + $OutVMList + $outVMsEND + $outHtmlEnd 

$outFullHTML | Out-File C:\Report\Zerto_Daily_Report.html


Send-MailMessage -To $MailTo -Cc $MailCc -Bcc $MailBcc -From $MailFrom -Subject "Zerto Daily Report" -Attachments C:\Report\Zerto_Daily_Report.html -SmtpServer $MailServer
