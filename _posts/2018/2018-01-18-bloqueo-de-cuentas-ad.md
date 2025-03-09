---
title: Bloqueo de cuentas en Active Directory
date: 2018-01-18T19:30:46
author: Victor Silva
layout: post
permalink: /bloqueo-cuentas-ad/
categories:
  - PowerShell
  - Windows Server
  - Active Directory
tags:
  - PowerShell
  - Active Directory
  - scripting
  - Desbloqueo de cuentas
  - Bloqueo de cuentas
---

La gestión de identidades es uno de los pilares de los administradores de sistemas. Ya sea por lo tedioso que se tornan algunos temas, como dar de alta usuarios nuevos, algunas tareas son automatizadas o se resuelven por medio de software de terceros. Otras, en cambio, son tareas que dependen de la capacidad de investigación del administrador para poder ser resueltas. Es por ello que hoy quiero conversar sobre el bloqueo de las cuentas y el desbloqueo de las mismas.

¿Quién no ha pasado por la situación de tener un usuario al que se le bloquea la cuenta más de 20 veces en el día sin motivo aparente? Ahí salimos a buscar pistas, ver en que puesto trabaja, que software usa, etc. Para determinar si por alguna casualidad dejó tildada la opción de recordar la contraseña y ahora, con una diferente, a cada momento aparece el pop-up de ingreso de credenciales.

Un administrador que se respete debe contar con herramientas que solucionen los problemas que van surgiendo día a día y como nosotros siempre damos un paso más, gracias al scripting, vamos a generar nuestras propias herramientas.

## Eventos, nuestros aliados de batalla

En el ecosistema Microsoft, los eventos y más puntualmente el visor de eventos deben ser nuestra información de referencia sobre lo que sucede en los sistemas. Es por ello, que debemos tener bien claro que se nos ofrece para poder sacar el mayor provecho. Voy a compartir una lista con los principales IDs y títulos de eventos relacionados a los estados que podría tener un usuario de dominio que nos van a servir a lo largo del post. Éstos eventos los vamos a encontrar en la sección **Security** del visor de eventos:


| ID.	| Mensaje |
| ------------- | ------------- |
| 4720	| Se ha creado una cuenta de usuario.|
| 4722| Se habilitó una cuenta de usuario.|
| 4723 |	Se ha intentado cambiar la contraseña de cuenta.|
|4724	| Se ha intentado restablecer la contraseña de cuenta.|
|4725	|Se ha deshabilitado una cuenta de usuario. |
|4726	| Se ha eliminado una cuenta de usuario. |
|4740	| Se ha bloqueado una cuenta de usuario. |
|4767	| Se ha desbloqueado una cuenta de usuario. |

Obviamente que no vamos a utilizar todos los detallados de la lista, pero simplemente para tener una idea más amplia de la información que podemos obtener desde los registros de eventos. También es válido comentar que no son los únicos IDs que hacen referencia a los estados por los que pasa una cuenta de dominio. Básicamente nos vamos a centrar en los eventos con *ID 4740*, que son los que se refieren a las cuentas bloqueadas:


<img src="https://nrq9xg.ch.files.1drv.com/y4mNiGwYAdgVqAaTj3sIP2YxHr0x2oGXjPrOA-hu-aqcrfr7SnYUH5NLfvZyUyZ51XN48JY9q95ChiTTDYkGvxPHHWWyLHlrFtEUEFxqAhW9O-q3EzpsH43uKLV1NuSgS7LO6_SH-mfbMwp70EqDAIJO-wMFyh3_dCclZya9eMCu_NfA2A4GmuzNnhwl9vDw6IY2nLzIjFn9uY68ApF88W9Wg?width=840&height=575&cropmode=none" alt="Eventos de Seguridad con ID 4740" class="alignnone size-full" />

La imagen anterior muestra el visor de eventos con el filtro aplicado para que despliegue solamente los eventos con *ID 4740*.

Ahora bien, dentro de ese evento generado vamos a contar con información relevante al momento en que se bloqueó la cuenta que estamos intentando investigar. Dentro de la información que tenemos a disposición, existen 2 valores que son los que nos interesan en esta oportunidad. El primero obviamente es el nombre del usuario, para poder filtrar la información que no nos interesa. El segundo valor es el equipo en donde se bloqueó el usuario.

De más está decir que dentro del evento contamos con más detalles sobre esa acción, Adjunto una captura de un evento para que quede en evidencia el resto de la información.

<img src="https://nrrcxg.ch.files.1drv.com/y4meIAD-liN9Eczuur_6hvVNzizuZFjz7KeQlnHGmOV7tNCHY19owPfcqHvTFBj_NTxa68o1_kb7dQkC9nrfFGBoVTSTNco7lPwsustX612zdJQTPFUHpLzcRqsQE5zSBihrl7nSP5FmQ5awW_cGTrHV6SBVkE5aSFR4ulreXsB_1OgAOEzzp4Xv12jz0NiTVyNNGUnzy2hlzk5NIlr5zeHuQ?width=818&height=575&cropmode=none" alt="Evento de Seguridad con ID 4740 para la cuenta vsilva" class="alignnone size-full" />  

En donde el valor de la etiqueta *"Nombre de equipo del autor de la llamada"* es el valor del equipo/servidor donde se bloqueó la cuenta, en este caso, del usuario **vsilva**. Según la imagen, la cuenta se bloqueó en el servidor **DC01**.

Como dato adicional antes de comenzar a ver con PowerShell ésta información, vale la pena recordar que estos eventos se registran en los controladores de dominio.

## Manos a la obra

No vamos a necesitar más herramientas que nuestra consola de PowerShell para poder llevar a cabo lo que necesitamos: desplegar información detallada sobre el bloqueo de un usuario en particular.

Primero debemos entender que comando nos va a permitir obtener los eventos que necesitamos con información al respecto de nuestra necesidad. El cmdlet central que vamos a usar es [Get-WinEvent]().

Como vimos anteriormente, el ID que indica que una cuenta se encuentra bloqueada es el 4740, por lo que vamos a usar la siguiente sintaxis para guardar todos los eventos con ese ID:

{% highlight posh %}
$eventos = Get-WinEvent -FilterHashtable @{logname='Security'; ID=4740; }
{% endhighlight %}

También agregamos el tipo de log, *Security* en este caso, ya que los eventos de auditoría se registran en esa categoría.

Ya tenemos en nuestra variable *$eventos* todos los registros que informan sobre un bloqueo de cuenta de usuario. Ahora debemos de manipular toda la información que nos proporcionan los eventos para poder obtener la información deseada: **saber en que equipo/servidor se bloqueó la cuenta**.

Así que armé esta pequeña función que manipula el resultado de lo anteriormente detallado y lo presenta como un objeto:

{% highlight posh %}
function Get-UsuarioBloqueado {
  param(
    [string]$Usuario
  )

    $eventos = Get-WinEvent -FilterHashtable @{logname='Security'; ID=4740; }
    $datos = 'TargetDomainName', 'TargetUserName'
    $eventos | ForEach-Object {
      ([xml]$_.ToXml()).Event.EventData | ForEach-Object {
        $props = @{}

        $_.Data |
          Where-Object { $datos -contains $_.Name} |
          ForEach-Object { $props[$_.Name] = $_.'#text' }

        New-Object -Type PSObject -Property $props | where {$_.TargetUserName -ge $usuario }
      }
    }
  }
{% endhighlight %}

Y la utilizamos de la siguiente manera:

{% highlight posh %}
Get-UsuarioBloqueado -Usuario vsilva
{% endhighlight %}

<img src="https://nrrdxg.ch.files.1drv.com/y4mxniJ2AqHPaq_-PGgnZOtwu_dpZoYrXPjD-VzeJmLTNkHpHCCZnNHni7tdHaqq6HaNqOHKTYGyqlwGrriMPbTOyBxfMReSrP1AhRsNxWXiI7ihhb6Y7geq8wTBqg-oZTrNdA92R25aMBwo19kO4pkxA5gZuKZWPpoZIvgAuNFk9nt3V2ClFFhJT07vnem4RvAgjXu0MjIyxGB-fln-7UQQA?width=906&height=293&cropmode=none" alt="Resultado de ejecutar la función Get-UsuarioBloqueado" class="alignnone size-full" />

Como se muestra en el ejemplo, en caso de ejecutar la función sin especificar un nombre de usuario en particular, vamos a obtener todos los registros que se generaron al bloquearse una cuenta, desplegando la información del nombre del usuario y en que equipo sucedió el bloqueo.

Happy scripting!