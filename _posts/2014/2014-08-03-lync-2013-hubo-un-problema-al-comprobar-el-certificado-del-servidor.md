---
title: 'Lync 2013 - Hubo un problema al comprobar el certificado del servidor'
date: 2014-08-03T14:41:56+00:00
author: Victor Silva
layout: post
permalink: /lync-2013-hubo-un-problema-al-comprobar-el-certificado-del-servidor/
dsq_thread_id:
  - "4472283808"
categories:
  - Skype for Business Server
tags:
  - Lync 2013
  - OWA
  - problema al comprobar certificado
---
Al momento de compartir una presentación de PowerPoint, desde nuestro cliente de Lync 2013, podemos llegar a toparnos con un error de certificado.

Un caso en el que puede aplicar y aparecer este error se debe a que el entorno donde se ha implementado la solución de Lync Server, se encuentre en otro dominio diferente a la máquina que intenta compartir la presentación, asi como también una máquina que no se encuentra unida al dominio.

<img class="alignnone" src="https://lh4.googleusercontent.com/-tBLQ_5OSvEM/VA87z_VVX8I/AAAAAAAAFp8/SsUFd-VMxJc/w445-h248-no/Lync_Error_Certificado_OWA.png" alt="" width="445" height="248" />

Este error se soluciona de la siguiente manera:

Dentro de las opciones de Internet Explorer, vamos a acceder al menú Herramientas y luego seleccionar la opción Opciones de Internet.

Dentro de este cuadro de dialogo, debemos seleccionar la solapa Opciones Avanzadas.

Y dentro de la solapa Opciones Avanzadas, buscar y destildar la opción _Comprobar la revocación del certificado del servidor*_

<img class="alignnone" src="https://lh4.googleusercontent.com/-2sRxLukOJTI/VA87z3bngjI/AAAAAAAAFqI/j41Iw_44rBg/w422-h542-no/Lync_IE_Revocation.png" alt="" width="422" height="542" />

Happy scripting!