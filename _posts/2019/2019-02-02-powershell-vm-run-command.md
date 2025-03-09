--- 
title: "Run command en Azure VMs con PowerShell"
author: Victor Silva
date: 2019-02-16T11:51:00+00:00 
layout: post 
permalink: /powershell-vm-run-command/ 
excerpt: 'Azure ofrece nuevas funcionalidades todo el tiempo, por lo que no es raro estar utilizando el portal y ver una nueva opción o feature lista para usar. Revisando dentro del blade de las VMs encontré una opción llamada "Run Command" dentro de las opciones de la sección "Operations". No recordaba haber visto esa opción antes, por lo que le hice clic y me sorprendió lo que obtuve...' 
categories: 
  - Azure
  - PowerShell
tags: 
  - Azure
  - PowerShell
  - Scripting
--- 

Azure ofrece nuevas funcionalidades todo el tiempo, por lo que no es raro estar utilizando el portal y ver una nueva opción o feature lista para usar. Revisando dentro del blade de las VMs encontré una opción llamada **Run Command** dentro de las opciones de la sección "Operations". No recordaba haber visto esa opción antes, por lo que le hice clic y me sorprendió lo que obtuve...

Si bien existen varios caminos para ejecutar comandos o scripts en Azure, dependen de lo que se necesite implementar. Se pueden utilizar Runbooks con Azure Automation, scripts de Desire State Configuration (DSC), Azure DevOps pipelines y otras
There are several ways to run commands and scripts on Azure VMs depending on the design you need to implement. You can use runbooks, Desired State Configuration (DSC) scripts, Azure DevOps pipelines, and many other third-party solutions for this. There's also a pretty simple standalone solution to execute commands on Azure VMs, which is a built-in feature in Azure Portal and is also usable through PowerShell.

<img src="https://jx5buq.ch.files.1drv.com/y4mm-aXbXELiBBex0DbqNbGTcXlfgzV7VpVWVTrWKu20c4F5KN2FRfYmq4J_2bm8rw39FKRQPZwq6ZWkdgWjZZ8KQ1Y6Kkc8HGObEGqYTEdR2ta2iGEBHKDLflO1vwpBWCZKaH25-tDScKtUUH_ZczPHrwrrvIMLFJ1v4Jt5XvACtZEeOoQ--XMV-a52QNpKzAflrRbIEWiI5duQnelZPRKHQ?width=1555&height=767&cropmode=none" alt="Run command" class="alignnone" />

Una lista con una variedad de opciones que permite, de forma sencilla y ágil, realizar ciertas tareas de gestión de recursos o resolución de problemas sin salir de la consola de Azure.

Indudablemente una de las opciones existentes es ejecutar un script de ***PowerShell***, pero también se encuentra disponible la ejecución de los clásicos comandos de **cmd**. Adicional a lo anterior tenemos algunos "shorcuts", como lo es la ejecución del comando `ipconfig /all` o la habilitación del usuario administrador.

## Ejecutar PowerShell desde el portal

Para ejecutar PowerShell basta seleccionar la opción **RunPowerShellScript** y escribir el código dentro del recuadro. Luego seleccionar el botón **Run** y analizar la salida. Para el ejemplo vamos a escribir una consulta seleccionando los 10 servicios en ejecución que más consumen CPU:

<img src="https://fqc29g.ch.files.1drv.com/y4md9e6MtXkZcIgpebDljrKZKh7No3SemCSWustnpnEvs0VCIjLjnk3D9Rybxrr6AWqmzIPI4sgTG9GJGmhZDuKT0IooqHoKP0XHgLVJf21M-lgLMcw60VGQKbwNZDSilSofSh1dS5bT3Q-LtETPhTSMDuy-DHaDzk2dJst356SGI2mveY6nCHHz2g1Jm1AMgU6GBltIo9u7B8pSV4_18XcFw?width=1281&height=630&cropmode=none" alt="Get-Process Run Command" class="alignnone" />

Obteniendo como resultado la siguiente salida:

<img src="https://5hspva.ch.files.1drv.com/y4me2aFjAF2xMG0QkgXUnOZ70AP4OoDGN430Q8qEfUjn64SJnQC-FBp7A3-E8t4DkSIH3f2qS8ZQ0-zpKXpZLpDel86FoQysdeL59EEL8W-TUpDeFrLtGo58e5iugeVnrE5as42wgt18N42_RzQBhTTT7j8doTPe25CM1kwjQtnFfTDSOWqdIxE5wyhLIddqPUe_fYINpUWmfcZnxBu3-pq4w?width=1281&height=600&cropmode=none" alt="Ejemplo de salida de Run Command" class="alignnone" />

Para los que gustan de contar con más detalles, la versión que utiliza esta funcionalidad es la `5.1` edición "Desktop". Es decir que no utiliza la versión Core :(

### Restricciones

Si bien tiene muchos usos prácticos, también es cierto que existen limitaciones:

- La salida tiene un límite de hasta 4096 bytes
- Demora alerdedor de unos 20 segundos ejecutar el script
- Únicamente se puede ejecutar uno a la vez
- No está soportado el modo interactivo (prompt)
- No se puede cancelar una ejecución
- El tiempo máximo que un script puede correr es 90 minutos, luego genera un time out
- Los scripts se ejecutan como System (se puede comprobar ejecutando `whoami`)
- La VM necesita tener conectividad para retornar el resultado de la ejecución (básicamente tiene que tener conectividad a las IPs públicas de Azure por el puerto 443)

## Utilizar Azure CLI y Azure PowerShell

También podemos realizar lo mismo que el portal sin salir de nuestra sesión en Azure CLI o Azure PowerShell, gracias a los siguientes ejemplos:

### Azure CLI

{% highlight posh%}
  az vm run-command invoke --resource-group test --name linux-runcommand --scripts "sudo touch /newFile.txt" --command-id RunShellScript
{% endhighlight %}

Más información en la documentación oficial: [az vm run-command](https://docs.microsoft.com/en-us/cli/azure/vm/run-command?view=azure-cli-latest)

### Azure PowerShell

{% highlight posh%}
  Invoke-AzVMRunCommand -ResourceGroupName test -VMName win-runcommand -CommandId RunPowerShellScript -ScriptPath ./run-command.ps1
{% endhighlight %}


## Seguridad

La funcionalidad **Run Command** permite limitar el acceso a ésta funcionalidad. Para poder hacer uso de la misma es necesario contar con el siguiente nivel de permiso:

`Microsoft.Compute/virtualMachines/runCommand/action`

El cual ya viene incluído en el rol Virtual Machine Contributor (u otros roles con mayores privilegios).

Vale la pena recordar que es posible crear roles *custom* en donde es posible asignar este privilegio en particular para tener un mayor control en los recursos.

Happy scripting!