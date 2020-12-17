    [CmdletBinding()]
Param
(
    [Parameter(Mandatory=$True)]
    $ScomServer
)
  
    Import-Module OperationsManager
    New-SCOMManagementGroupConnection -ComputerName $ScomServer
    Out-File -FilePath "C:\TEMP\scominfra.txt" -InputObject "Server Host Name,Server IP Address,Server Role"
   
    #BEGIN-- compile an array of the Gateway servers to exclude them from script actions
    $gateways = Get-SCOMGatewayManagementServer | Select-Object DisplayName, IPAddress
    $gatelist = $gateways.DisplayName
    foreach($gateway in $gateways){
        $thegateway = $gateway.DisplayName
        $thegatewayip = $gateway.IPAddress.Split(",")
        $systype = 'Operations Manager Gateway Management Server'
        $filetext = $thegateway + "," + $thegatewayip[0] + "," + $systype
        Out-File -FilePath "C:\TEMP\scominfra.txt" -InputObject $filetext -Append
        }

    $managementservers = Get-SCOMManagementServer | Select-Object DisplayName,IPAddress | Where-Object {$_.DisplayName -notin $gatelist} | Sort-Object DisplayName
    foreach($managementserver in $managementservers){
        $thems = $managementserver.DisplayName
        $themsip = $managementserver.IPAddress.Split(",")
        $systype = 'Operations Manager Management Server'
        $filetext = $thems + "," + $themsip[0] + "," + $systype
        Out-File -FilePath "C:\TEMP\scominfra.txt" -InputObject $filetext -Append
        #If the management server has the ACS monitoring service installed, shut it down
        if (Invoke-Command -ComputerName $thems -Command {Get-Service -Name AdtServer -ErrorAction SilentlyContinue}){
            $systype = 'Operations Manager Audit Collection Server'
            $filetext = $thems + "," + $themsip[0] + "," + $systype
            Out-File -FilePath "C:\TEMP\scominfra.txt" -InputObject $filetext -Append
            $odbclist = Invoke-Command -ComputerName $thems -Command {Get-ChildItem “HKLM:\SOFTWARE\ODBC\ODBC.INI\” | Where-Object Name -notmatch "ODBC Data Sources"}
            #Get the name of the ACS database server from this ACS Collector, and add it to the array of database server names
            foreach($ds in $odbclist){
                $datasource = $ds.Name
                $datasource = $datasource.Replace('HKEY_LOCAL_MACHINE','HKLM:')
                $getvalues = Invoke-Command -ComputerName $thems -Command {Get-ItemProperty $args[0] -Name Description,Server} -ArgumentList "$datasource"
                $servername = $getvalues.Server
                $description = $getvalues.Description
                if($description -match 'Audit Collection Services'){
                    if($servername -like '*\*'){
                        #Database server name with instance
                        $serverName = [System.Net.Dns]::GetHostEntry($servername.Split(‘\’)[0]).HostName
                    }elseif($servername -like '*,*'){
                        #Database server name with no instance, but a port
                        $serverName = [System.Net.Dns]::GetHostEntry($servername.Split(‘,’)[0]).HostName
                    }else{
                        #Database server name by itself
                        $serverName = [System.Net.Dns]::GetHostEntry($servername).HostName
                    }
                
                    $dbns = Resolve-DnsName -Type A -Name $servername
                    $dbip = $dbns.IPAddress
                    $systype = 'Operations Manager Audit Collection Services Collector Database Server'
                    $filetext = $servername + "," + $dbip + "," + $systype
                    Out-File -FilePath "C:\TEMP\scominfra.txt" -InputObject $filetext -Append

               }
            }
        }
     }

    $webconsole = Get-SCOMClass -DisplayName 'Web Console Watcher' | Get-SCOMClassInstance | Select-Object Path
    $webhost = $webconsole.Path
    $webconsolens = Resolve-DnsName -Type A -Name $webhost
    $webconsoleip = $webconsolens.IPAddress
    $filetext = $webhost + "," + $webconsoleip + ",Operations Manager Web Console"
    Out-File -FilePath "C:\TEMP\scominfra.txt" -InputObject $filetext -Append

    $reportserver = Get-SCOMClass -DisplayName 'Report Console Watcher' | Get-SCOMClassInstance | Select-Object Path
    $ssrshost = $reportserver.Path
    $ssrsns = Resolve-DnsName -Type A -Name $ssrshost
    $ssrsip = $ssrsns.IPAddress
    $filetext = $ssrshost + "," + $ssrsip + ",Operations Manager Reporting Services"
    Out-File -FilePath "C:\TEMP\scominfra.txt" -InputObject $filetext -Append

    #Database servers
    $dbquery = Invoke-Command -ComputerName $ScomServer -Command {Get-ItemProperty “HKLM:\SOFTWARE\Microsoft\Microsoft Operations Manager\3.0\Setup\” | Select-Object DatabaseServerName, DataWarehouseDBServerName}
    $omdb =   $dbquery.DatabaseServerName
    $dwdb =   $dbquery.DataWarehouseDBServerName
    #BEGIN - deconstruct the names of the database servers, as several formats are valid, but we just want the hostname
    #we make certain here that they are all uniform, and are the FQDN of the server itself.
    if($omdb -like '*\*'){
        #Database server name with instance
        $omdbserverName = [System.Net.Dns]::GetHostEntry($omdb.Split(‘\’)[0]).HostName
    }elseif($omdb -like '*,*'){
        #Database server name with no instance, but a port
        $omdbserverName = [System.Net.Dns]::GetHostEntry($omdb.Split(‘,’)[0]).HostName
    }else{
        #Database server name by itself
        $omdbserverName = [System.Net.Dns]::GetHostEntry($omdb).HostName
    }
    $omdbns = Resolve-DnsName -Type A -Name $omdbserverName
    $omdbip = $omdbns.IPAddress
    $filetext = $omdbserverName + "," + $omdbip + ",Operations Manager Database Server"
    Out-File -FilePath "C:\TEMP\scominfra.txt" -InputObject $filetext -Append

    if($dwdb -like '*\*'){
        #Database server name with instance
        $dwdbserverName = [System.Net.Dns]::GetHostEntry($dwdb.Split(‘\’)[0]).HostName
    }elseif($dwdb -like '*,*'){
        #Database server name with no instance, but a port
        $dwdbserverName = [System.Net.Dns]::GetHostEntry($dwdb.Split(‘,’)[0]).HostName
    }else{
        #Database server name by itself
        $dwdbserverName = [System.Net.Dns]::GetHostEntry($dwdb).HostName
    }
    
    $dwdbns = Resolve-DnsName -Type A -Name $dwdbserverName
    $dwdbip = $dwdbns.IPAddress
    $filetext = $dwdbserverName + "," + $dwdbip + ",Operations Manager Data Warehouse Database Server"
    Out-File -FilePath "C:\TEMP\scominfra.txt" -InputObject $filetext -Append
    
    #END - deconstruct the names of the database servers, as several formats are valid, but we just want the hostname
    #Get ACS Report Servers - requires a special manual membership group named "ACS Report Servers"
    $acsgrp = Get-SCOMGroup -DisplayName "ACS Report Servers"
    if($null -ne $acsgrp){
        $acssys = $acsgrp.GetRelatedMonitoringObjects()
        foreach($acsssrs in $acssys){
            $thename = $acsssrs.DisplayName
            $acsssrsns = Resolve-DnsName -Type A -Name $thename
            $acsssrsip = $acsssrsns.IPAddress
            $filetext = $thename + "," + $acsssrsip + ",Operations Manager Audit Collection Report Server"
            Out-File -FilePath "C:\TEMP\scominfra.txt" -InputObject $filetext -Append
        }
    }