---
id: 11
title: 'Error en el &#8220;Share&#8221; al publicar la topología en Lync Server 2013'
date: 2014-04-16T18:08:10+00:00
author: Victor Silva
layout: post
guid: http://vmsilvamolina.wordpress.com/?p=11
permalink: /error-en-el-share-al-publicar-la-topologia-en-lync-server-2013/
dsq_thread_id:
  - "4476855461"
categories:
  - Skype for Business Server
tags:
  - Compartido
  - Error en Lync
  - Instalación de Lync
---
Al realizar la instalación de Lync Server 2013 nos encontramos en un momento en la necesidad de especificar un repositorio compartido, el cual se debe declarar para poder continuar con la instalación.

<!--more-->

  * ACL Error: Access permissions error
  * Error:Failed to save permissions on (CARPETA COMPARTIDA)
  * ACL Error: Failed Adding “Access Write” permission for “XXX” on “share”. Access control list (ACL) might fail on UNIX files shares. Refer to the deployment guide to manually set the ACLs in the file share.

Para solucionar este inconveniente, simplemente debemos de abrir las propiedades del recurso a compartir.

Luego seleccionar la solapa sharing,  luego el botón share.

En el asistente &#8220;File Sharing&#8221;, desde el botón **Add** y luego **Find People**, agregar los siguientes grupos con los permisos **Read/Write**:

  * RTCHS Universal Services
  * RTC Component Universal Services
  * RTC Universal Server Admins
  * RTC Universal Config Replicator

Luego de realizado lo anterior, volver a publicar la topología y continuar con la instalación.

&nbsp;

Saludos,

&nbsp;