---
title: 'Auditar VMs en VMware desde PowerShell'
date: 2015-12-18T23:49:18+00:00
author: Victor Silva
layout: post
permalink: /auditar-vms-en-vmware-desde-powershell/
dsq_thread_id:
  - "4473477638"
categories:
  - PowerShell
tags:
  - Audit
  - Auditoría
  - PowerShell
  - VMware
---
No todo en el mundo es Microsoft, y hoy por hoy debemos manejar herramientas que también lideran el mercado, en este caso, el de la Virtualización. Hoy quiero compartir como auditar VMs en VMware desde PowerShell.

Por estos días, el tema de la auditoría es bastante solicitado y muchas veces por seguridad se pretende tener controlados los cambios de configuración que se le realizan a una máquina virtual determinada. Si bien hay soluciones a medida para realizar estas auditorías, creo que es necesario poder compartir esta pequeña información para poder desarrollar mejores cosas y obtener mejores resultados.

El fuerte de la auditoría en VMware son los eventos y cómo consumirlos, por decirlo de alguna manera. En particular es importante revisar la sección [VmReconfiguredEvent](http://pubs.vmware.com/vsphere-60/index.jsp?topic=/com.vmware.wssdk.apiref.doc/vim.event.VmReconfiguredEvent.html) que incluye una propiedad muy importante; [configSpec](http://pubs.vmware.com/vsphere-60/index.jsp?topic=/com.vmware.wssdk.apiref.doc/vim.event.VmReconfiguredEvent.html). Ésta propiedad se encarga de recolectar la información de los cambios de configuración (por ejemplo CPU, memoria, CD-ROM, HDD, etc.)

## Primeros pasos

Para comenzar vamos a ver por partes un script que genera un reporte de los cambios en todas las máquinas registradas. Este reporte se guardará como un archivo .csv en una ruta determinada.

Lo primero que debemos hacer es conectarnos al vCenter, para poder obtener los datos:

    $Cred = Get-Credential
    $vcServer = 'IP del vcenter'
    Connect-VIServer -Server $vcServer -Credential $Cred -InformationAction SilentlyContinue | Out-Null
    

Agregamos el parámetro InformationAction con el valor SilentlyContinue, para que no aparezcan las advertencias de,por ejemplo, certificados selfsigned.

Ya teniendo la conexión iniciada, vamos a empezar a definir los requisitos para nuestro script.

    $Hours = 36 # Tiempo de búsqueda en el pasado
    $TaskNumber = 999 # Tamaño para el task collector
    $EventNumber = 100 # Tamaño para el event collector
    $Report = @()
    $TaskMgr = Get-View TaskManager
    $EventMgr = Get-View EventManager
    

En el bloque anterior se declara básicamente, la cantidad de horas que va a ir a buscar en la base. El resto de los valores es a gusto del consumidor, ya que no hay nada definido como regla.

    $TaskFilter = New-Object VMware.Vim.TaskFilterSpec
    $TaskFilter.Time = New-Object VMware.Vim.TaskFilterSpecByTime
    $TaskFilter.Time.beginTime = (Get-Date).AddHours(-$hours)
    $TaskFilter.Time.timeType = "startedTime"
    $TaskFilter = Get-View ($taskMgr.CreateCollectorForTasks($TaskFilter))
    

Ahora pasamos a generar los objetos que vamos a utilizar para volcar la información que relevemos. Es acá donde tenemos que indicar el lapso de tiempo para realizar la consulta a la base de datos y también donde filtramos la cantidad de datos a recolectar.

    $tasks = $TaskFilter.ReadNextTasks($tasknumber)
    while($tasks){
        $tasks | where {$_.Name -eq "ReconfigVM_Task"} | % {
            $task = $_
            $EventFilter = New-Object VMware.Vim.EventFilterSpec
            $EventFilter.eventChainId = $task.EventChainId
            $EventCollector = Get-View ($eventMgr.CreateCollectorForEvents($EventFilter))
            $events = $EventCollector.ReadNextEvents($eventnumber)
            while($events){
                $events | % {
                    $event = $_
                    switch($event.GetType().Name){
                        "VmReconfiguredEvent" {
                            $event.ConfigSpec.DeviceChange | % {
                                if($_.Device -ne $null){
                                    $report += New-Object PSObject -Property @{
                                        Nombre = $task.EntityName
                                        Inicio = $task.StartTime
                                        Fin = $task.CompleteTime
                                        Resultado = $task.State
                                        Usuario = $task.Reason.UserName
                                        Dispositivo = $_.Device.GetType().Name
                                        Operación = $_.Operation
                                    }
                                }
                            }
                        }
                        Default {}
                    }
                }
                $events = $EventCollector.ReadNextEvents($eventnumber)
            }
            $EventCollector.DestroyCollector()
        }
        $tasks = $TaskFilter.ReadNextTasks($tasknumber)
    }
    $TaskFilter.DestroyCollector()
    

En el bloque anterior creamos el objeto ordenado, con las propiedades que nos interesan y pensando en como lo vamos a exportar.

Ahora, sí. Para exportarlo, tendremos que agregar estas últimas líneas:

    $FileName = C:\Users\Victor\Desktop\Reporte.csv
    $Report | Sort-Object -Property Start | Export-Csv $FileName -NoTypeInformation -UseCulture
    

## Finalizado

Acá les comparto el script final, con algunos detalles agregados (solicitud de usuario y pass, IP del vCenter, ruta del archivo):