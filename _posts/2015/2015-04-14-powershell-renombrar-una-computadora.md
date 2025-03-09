---
title: 'PowerShell - Renombrar una computadora'
date: 2015-04-14T16:30:44+00:00
author: Victor Silva
layout: post
permalink: /powershell-renombrar-una-computadora/
dsq_thread_id:
  - "4474230275"
categories:
  - PowerShell
tags:
  - Cmdlets
  - rename
  - Rename-Computer
  - renombrar computadora
  - renombrar servidor
---
Una tarea sencilla, pero que no todos saben como se hace. Cada día estoy más seguro que podemos hacer casi todo tipo de tareas desde PowerShell, desde las mas complejas a las mas simples. Y renombrar una computadora o servidor es una de ellas.

Existe un Cmdlet llamado **[Rename-Computer](https://technet.microsoft.com/en-us/library/hh849792.aspx)** que está desarrollado para este fin.

Este comando tiene varios parámetros, entre ellos:

  * ComputerName: Nombre del equipo que queremos modificar (si lo obviamos, toma por defecto la maquina local).
  * DomainCredential: Permite establecer las credenciales de dominio que tengan los permisos necesarios para cambiar el nombre.
  * LocalCredential: Para permisos locales
  * New-Name: Para definir el nuevo nombre que tendrá el equipo.
  * Restart: Para reiniciar el equipo. Necesario para hacer efectivo el cambio.

Si bien hay más parámetros, éstos son los principales.

Un ejemplo de uso es el siguiente; Queremos renombrar el servidor local a **Server044**, con las credenciales de dominio **Domain/Admin**, el comando a ejecutar es:

{% highlight posh %}
Rename-Computer -NewName Server044 -DomainCredential Domain\Admin -Restart
{% endhighlight %}

Listo!

Happy scripting!