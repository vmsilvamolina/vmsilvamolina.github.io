---
title: 'Skype for Business - Eventos con ID 1000/1026 y servicios detenidos'
date: 2015-06-30T23:31:32+00:00
author: Victor Silva
layout: post
permalink: /skype-for-business-eventos-1000-1026-y-servicios-detenidos/
dsq_thread_id:
  - "4590414241"
categories:
  - Sin categoría
tags:
  - Error ID 1000/1026
  - Skype for Business
  - Centralised Logging Service Agent
  - Replica Replicator Agent
---
Me paso hace relativamente poco instalando la solución de Skype for Business encontrarme luego de finalizar la instalación con el siguiente panorama:

Al ingresar al panel de control de SFB, un símbolo de cruz en color rojo debajo de la sección de replicación. Reviso los eventos del sistema y encuentro los siguientes eventos: ID1000 e ID1026. Luego de ver esto, se me da por revisar los servicios; 2 servicios detenidos (Skype for Business Centralised Logging Service Agent y Skype for Business Replica Replicator Agent).

<img src="https://lh4.googleusercontent.com/--xMn1vxYSuc/VZNCpDRahMI/AAAAAAAAHBQ/gCngpxTGWhs/w904-h410-no/SFB_Error1000_01.png" width="904" height="410" class="alignnone" />

<img src="https://lh4.googleusercontent.com/-p5ZISg1kIc0/VZNCpBkCjmI/AAAAAAAAHBY/urmS9xHNbiA/w904-h410-no/SFB_Error1000_02.png" width="904" height="410" class="alignnone" />

Ok, no tenía muchas pistas pero me sonaba familiar con la versión anterior: **_Lync Server 2013_**.

Si bien no tengo una buena memoria, a veces me sorprendo a mí mismo. Recordé un cmdlet para corroborar el estado de la replicación, por lo que ejecuté:

{% highlight posh%}
Get-CSManagementReplicationStatus
{% endhighlight %}

El resultado fue **false**. Era el esperado, pero por las dudas lo ejecuté igual.

Apoyando a mi memoria nuevamente, recordé una serie de pasos para reconstruir la replica.

El procedimiento es el siguiente:

  * Clic derecho sobre las propiedades de la carpeta **_C:\RtcReplicaRoot\xds-replica_**. 
  * En la pestaña seguridad, seleccionar Opciones avanzadas, clic en Cambiar (propietario).
  * Agregar la cuenta apropiada (preferiblemente la cuenta que se encuentra en el grupo de CsAdministrator) y **OK**.
  * Seleccionar **Reemplazar propietario en subcontenedores y objetos**.
  * Eliminar la carpeta **_xds-replica_**. 
  * Desde programas y características desde panel de control, seleccionar Core Components del grupo de Skype for Business y luego seleccionar Reparar. 
  * Acceder a los servicios (services.msc) y setear **_Skype for Business Centralised Logging Service Agent_** como Automatic (Delayed). 
  * Luego setear el servicio **_Skype for Business Replica Replicator Agent_** como Automatic (Delayed). 
  * Iniciar ambos servicios.

Ejecutar desde una consola de PowerShell:

{% highlight posh%}
Invoke-CsManagementStoreReplication
{% endhighlight %}

Esperar un par de minutos y ejecutar:

{% highlight posh%}
Get-CsManagementStoreReplicationStatus
{% endhighlight %}

Perfecto! Ahora el resultado es true en la replicación. Si abrimos el panel de control de Skype for Business vamos a tener todo en verde, indicando que todo se encuentra funcional.

Happy scripting!