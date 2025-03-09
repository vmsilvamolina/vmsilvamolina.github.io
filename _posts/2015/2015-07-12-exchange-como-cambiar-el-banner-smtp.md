---
title: 'Exchange Server - Como cambiar el banner SMTP'
date: 2015-07-12T22:12:37+00:00
author: Victor Silva
layout: post
permalink: /exchange-como-cambiar-el-banner-smtp/
dsq_thread_id:
  - "4480204108"
categories:
  - Exchange
  - PowerShell
tags:
  - Banner SMTP
  - Exchange
  - PowerShell
  - Set-ReceiveConnector
---
Según la TechNet:

>El título SMTP es la respuesta de la conexión SMTP que recibe un servidor de mensajería SMTP remoto después de conectarse a un conector de recepción configurado en un equipo que ejecuta Microsoft Exchange Server 2013.

Para modificar este mensaje (por seguridad, para ofrecer menos información de los servidores publicados) lo que tenemos que hacer, obviamente desde PowerShell 🙂, es lo siguiente.

Conectados al servidor de Exchange, o remotamente con el módulo de administración de Exchange ya cargado, ejecutamos:

{% highlight posh%}
Set-ReceiveConnector -Identity "Nombre del conector" -Banner "Mensaje"
{% endhighlight %}

Lo recomendado para definir el mensaje del banner es un texto similar a: "**220 NombreDelServidor**"

Un ejemplo:

<img src="https://lh5.googleusercontent.com/-URt8px1onJM/VZ2_6pDRnbI/AAAAAAAAHDI/rG3xvrJuGi0/w980-h150-no/EX_Banner_1.png" width="980" height="150" class="alignnone" />

Para verificar que realmente quedó configurado, ejecutamos un telnet al servidor al puerto 25, obteniendo como resultado nuestro mensaje configurado correctamente:

<img src="https://lh4.googleusercontent.com/-so_535Xdoxk/VZ2_-BqJryI/AAAAAAAAHDQ/1qz5dfB69g8/w418-h92-no/EX_Banner_2.png" width="418" height="92" class="alignnone" />

Dejo el enlace a la TechNet del comando utilizado: [Set-ReceiveConnector](https://technet.microsoft.com/es-es/library/bb125140%28v=exchg.150%29.aspx)

Happy scripting!