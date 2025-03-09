---
title: 'Lync 2013 - Error del cliente (vdpsrc.dll)'
date: 2014-08-15T14:39:48+00:00
author: Victor Silva
layout: post
permalink: /lync-2013-error-del-cliente-vdpsrc-dll/
dsq_thread_id:
  - "4604386438"
categories:
  - Skype for Business Server
tags:
  - Error
  - KB2880980
  - Lync 2013
  - vdpsrc.dll
---
En alguna oportunidad nos encontramos con el siguiente problema:

En una notebook con un driver Intel PROSet/Wireless para el software de Bluetooth, encontramos que no inicia el cliente de Lync 2013. Directamente no inicia, aparece un cartel de error.

La causa se debe a que este Software se registra como dispositivo de video. Por lo que genera un evento de error indicando que la dll en concreto es la:

> C:\Program Files\Intel\bluetoothvdpsrc.dll

Para solucionar este inconveniente, basta con instalar el siguiente Update para poder resolver este error:

<a title="KB2880980" href="http://www.microsoft.com/es-ES/download/confirmation.aspx?id=42894" target="_blank">Link de descarga</a>

Happy scripting!