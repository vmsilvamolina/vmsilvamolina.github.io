---
title: 'Hyper-V Replica para todos!!!'
date: 2014-07-01T21:43:55+00:00
author: Victor Silva
layout: post
permalink: /hyper-v-replica-para-todos/
dsq_thread_id:
  - "4486883912"
categories:
  - Hyper-V
  - PowerShell
  - Replica
  - Windows Server
tags:
  - Hyper-V
  - PowerShell
  - DRP
  - HA
  - Cmdlets
  - Maquinas Virtuales
  - Replica
  - Windows Server 2012 R2
---
Si hablamos de Hyper-V tenemos en claro que existen métodos para poder mejorar la disponibilidad de nuestras maquinas virtuales, como lo son **Live Migration** y **Quick Migration**, pero ninguno cumple con una rápida recuperación ante desastres.

Cuando se trata de alta disponibilidad en Hyper-V Server 2012 R2, existen dos opciones ya mencionadas:

**Quick Migration –** Nos da la posibilidad de mover la maquina virtual hacia otro nodo del clúster. El mecanismo funciona apagando los servicios antes de mover la maquina, y luego en el nodo destino, los vuelve a iniciar automáticamente. En este modelo de migración tenemos una perdida de tiempo de inactividad.

**Live Migration –** La migración en vivo permite mover de manera transparente máquinas virtuales en ejecución de un nodo a otro nodo del mismo clúster, sin que se interrumpa la conexión de red o se perciba tiempo de inactividad alguno.

Como se comentó anteriormente, ambas opciones tienen la intención de mejorar la disponibilidad de nuestras maquinas virtuales, pero no se puede ejecutar un plan ante desastres con ninguna de ellas.

A partir de Windows Server 2012, dentro de las características del rol de Hyper-V se incluyo una nueva funcionalidad llamada Hyper-V Replica.

## Que es Hyper-V Replica?

Si buscamos el formalismo, según la TechNet la definición sería:

> Esta característica permite replicar máquinas virtuales entre sistemas de almacenamiento, clústeres y centros de datos ubicados en dos sitios para ofrecer continuidad empresarial y recuperación ante desastres.

Un dato muy importante es que Hyper-V replica no necesita de Failover Clúster para su funcionamiento. A su vez el esquema para implementarlo es bastante simplificado: basta con tener 2 servidores con la funcionalidad habilitada y correctamente configurada para poder empezar a trabajar con nuestro plan ante desastres.
  
A parte de ser totalmente gratis (viene incluida dentro del rol de Hyper-V), nos ofrece los siguientes beneficios:

  * No es necesario contar con el mismo hardware en el servidor "Primario" y el servidor de "Replica".  
  * Puede funcionar sobre dos modelos de seguridad: Grupo de trabajo y Dominio (agregando ambos servidores al mismo dominio).
  * No es necesario contar con almacenamiento compartido para poder implementar la solución.
  * Permite restaurar una copia exacta de nuestra maquina virtual en el sitio de Replica.
  * Al realizarse la copiar por la red, incorpora compresión y cifrado en los datos al replicar las maquinas virtuales.
  * Estrechamente integrado con Volume Shadow Copy Service, permitiendo crear varios "puntos de restauración".

Un dato no menor es que a partir de Windows Server 2012 R2, no estamos limitados a una réplica de un servidor sino que podemos tener una segunda réplica (la original y dos réplicas).

## Conceptos y modo de funcionamiento

En un escenario de implementación, definimos dos sitios, en primer lugar el *sitio primario* que es básicamente la ubicación donde el entorno virtualizado opera normalmente. En segundo lugar, tenemos el *sitio de réplica* que es en donde se van a recibir los datos replicados desde el sitio primario.

En el sitio principal, el core es el servidor físico (o clúster) que hospeda una o más maquinas virtuales. Y en el sitio de réplica, de manera similar, se encuentran las maquinas replicadas.

Una vez configurado correctamente los host que pertenecerán a la implementación de réplica con Hyper-v, se debe realizar un *replicación inicial*. Se puede llevar a cabo directamente por la red, o copiando los datos utilizando un disco físico para llevar posteriormente los datos al sitio de réplica.

Cuando la replicación esta en curso, cada cierto tiempo definible (en Windows Server 2012 R2 este tiempo puede configurarse entre 30 segundos, 5 minutos o 30 minutos), el sitio primario envía información acerca de este último lapso de tiempo al sitio de réplica, donde se reproduce esta información en la réplica de Hyper-V.

Se trata de un proceso de recuperación de desastres manual de modo que siempre hay intervención por parte del administrador de sistemas. Esto está en contraste con una solución automatizada de alta disponibilidad, tales como la migración en vivo, que no tiene tiempo de inactividad, a menos que ocurra una interrupción no programada.

## Configuración

Luego de ver la parte teórica de esta característica, vamos a empezar a configurar nuestros servidores, para ello vamos a utilizar PowerShell, ya que también contamos con un módulo de administración para esta herramienta.

Para ello desde nuestra consola de PowerShell desde el servidor que va a ser nuestro host en el sitio principal, vamos a ver los comando que tenemos que ejecutar.

Como Hyper-V Réplica viene deshabilitado por defecto en una instalación de Windows Server 2012 R2, lo primero que debemos hacer es habilitar el rol de Hyper-V, ejecutando el siguiente comando:

{% highlight posh %}
Install-WindowsFeature Hyper-V –Restart #Se va a reiniciar nuestro servidor de forma auto
{% endhighlight %}

Luego de que se instale el rol y reinicie correctamente, debemos habilitar el rol de Réplica en el servidor donde se ejecuta este comando, utilizando como locación de los datos de replica la ruta _**E:\Replica**_, corriendo el siguiente código:

{% highlight posh %}
Set-VMReplicationServer -ReplicationEnabled $true -AllowedAuthenticationType Kerberos -ReplicationAllowedFromAnyServer $true -DefaultStorageLocation E:\Replica
{% endhighlight %}

Ahora debemos habilitar en el Firewall el trafico correspondiente, por lo que tendremos que habilitar la regla correspondiente, simplemente con una linea de código:

{% highlight posh %}
Enable-NetFirewallRule -displayname "Hyper-V Replica HTTP Listener (TCP-In)"
{% endhighlight %}

Con los comandos anteriores ya tenemos nuestro servidor en el sitio principal, configurado correctamente. Ahora debemos ejecutar los mismo comandos en el servidor que va a ser nuestro *servidor de réplicas*.

Luego de tener ambos sitios configurados, debemos habilitar la replicación a las maquinas virtuales.

En nuestro escenario de ejemplo, vamos a considerar como servidor principal al ServerHV01 y como servidor de réplicas el ServerHV02. También vamos a definir a una VM para habilitar la replica, esta se va a llamar VM01.

Para poder llevar a cabo la replicación de la VM01 debemos habilitar la funcionalidad a esta maquina virtual:

{% highlight posh %}
Enable-VMReplication -VMName VM01 -ReplicaServerName ServerHV02 -ReplicaServerPort 80 -AuthenticationType Kerberos -CompressionEnabled $true -RecoveryHistory 5
{% endhighlight %}

Si prestamos especial atención al parametro RecoveryHistory, le asignamos el valor 5. Lo que indica que esta VM va a contar con 5 puntos de restauración, es decir, vamos a poder tener 5 "momentos" de los estados de la maquina virtual.

Por mas información comparto los enlaces a la TechNet de los comandos utilizados:

  * [Set-VMReplicationServer](http://technet.microsoft.com/en-us/library/hh848598.aspx)
  * [Enable-VMReplication](http://technet.microsoft.com/en-us/library/jj136049.aspx)


Happy scripting!