--- 
title: "Excluir VMs de la Azure Automation Account con PowerShell"
author: Victor Silva
date: 2020-07-07T20:16:00+00:00 
layout: post 
permalink: /excluir-vms-azure-automation-powershell/
excerpt: "Azure Automation permite ejecutar de manera automatizada procesos y flujos para, entre otras cosas, controlar costos en Azure. Una de las tareas más comunes es definir horas de actividad en ciertas VMs para así mantener en ejecución las cargas de trabajo cuando realmente sea necesario, aunque en ciertos casos necesitamos hacer exepciones o exclusiones."
categories: 
  - Azure
  - PowerShell
tags: 
  - Azure Automation Account
  - Runbook
  - PowerShell
  - Az
  - Azure

---

<div><b>Actualizado:</b> 7 de Julio de 2021</div>{: .notice}

Azure Automation permite ejecutar de manera automatizada procesos y flujos para, entre otras cosas, controlar costos en Azure. Una de las tareas más comunes es definir horas de actividad en ciertas VMs para así mantener en ejecución las cargas de trabajo cuando realmente sea necesario, aunque en ciertos casos necesitamos hacer exepciones o exclusiones.

## Azure Automation

Automation es un servicio de Azure que nos ofrece la posibilidad de ahorrar costos y ganar tiempo, ya sea por automatizar procesos repetitivos y manuales como por controlar la ejecución de servicios cuando realmente sea necesario. Ya hemos hablado que es posible [trabajar con PowerShell](https://blog.victorsilva.com.uy/azure-automation/) para realizar estas tareas.

En el problema planteado en el post, tenemos resuelto el encendido y apagado de ciertas VMs (las que pertenecen a un Resource Group en particular) y nos encontramos con la necesidad de excluír una de ellas, para que no aplique esta configuración.

## Automation variables

Lo primero que debemos hacer obtener la información necesaria de la automation account. Para ello tenemos el siguiente cmdlet: `Get-AzAutomationAccount`

{% highlight posh%}
Get-AzAutomationAccount -ResourceGroupName Automation
{% endhighlight %}

Para obtener la lista de VMs excluídas debemos ejecutar el siguiente cmdlet, tomando en cuenta la variable `External_ExcludeVMNames`. La misma define la lista de Vms que no van a ser consideradas en la ejecución del runbook:

{% highlight posh%}
Get-AzAutomationVariable -Name External_ExcludeVMNames -AutomationAccountName StartStopVM -ResourceGroupName Automation
{% endhighlight %}

<img src="/assets/images/postsImages/PS_AutomationExclude_0.png" class="alignnone">

Obviamente que el resultado no contiene valores, ya que no se han agregado anteriormente.

Con la información anterior estamos en condiciones de agregar a la lista (ahora vacía) de VMs a excluír, la VM a la que queremos que no aplique el runbook de encendido/apagado:

{% highlight posh%}
Get-AzAutomationVariable -Name External_ExcludeVMNames -AutomationAccountName StartStopVM -ResourceGroupName Automation `
  | Set-AzAutomationVariable -Value "vm-testing"
{% endhighlight %}

<img src="/assets/images/postsImages/PS_AutomationExclude_1.png" class="alignnone">

Listo!

Para la siguiente ejecución del runbook, se va a omitir la VM agregada en la variable `External_ExcludeVMNames`.

### Quitar VMs de la exclusión

En caso que nos encontremos con la necesidad de quitar VMs de esta lista, para que la solución las encienda o apague, necesitamos modificar el string de la variable anteriormente modificada, llamada **External_ExcludeVMNames**. 

A modo de ejemplo vamos a contemplar que la lista definida contenía las siguientes VMs:

<img src="/assets/images/postsImages/PS_AutomationExclude_2.png" class="alignnone">

Donde se ve que la lista de VMs es "azDemoVM, vm-testing, w2019test", para quitar la VM **vm-testing** de la lista de excluídas se deberá ejecutar lo siguiente:

{% highlight posh%}
GetGet-AzAutomationVariable -Name External_ExcludeVMNames -AutomationAccountName StartStopVM -ResourceGroupName Automation `
  | Set-AzAutomationVariable -Value "azDemoVM, w2019test"
{% endhighlight %}

También es posible ejecutar el comando Set-AzAutomationVariable con todos los parámetros necesarios:

{% highlight posh%}
Set-AzAutomationVariable -Name External_ExcludeVMNames -ResourceGroupName Automation -AutomationAccountName StartStopVM -Value "azDemoVM, w2019test" -Encrypted $false
{% endhighlight %}

Happy scripting!