---
id: 12
title: 'Lync Control Panel: Problem 4003 Insufficient access rights to perform operation'
date: 2014-04-20T12:48:26+00:00
author: Victor Silva
layout: simple
guid: http://vmsilvamolina.wordpress.com/?p=12
permalink: /lync-control-panel-problem-4003-insufficient-access-rights-to-perform-operation/
dsq_thread_id:
  - "4491978451"
categories:
  - Skype for Business Server
tags:
  - Error
  - Habilitar usuarios
  - Insufficient access rights
  - Lync 2013
  - Lync Server
---
Active Directory operations failed on “Front End FQDN”. You cannot retry this operation: “Insufficient access rights to perform
  
the operation 00002098: SecErr: DSID-03150E8A, problem 4003 (INSUFF\_ACCESS\_RIGHTS)

<!--more-->

Este error aparece al intentar dar de alta un usuario en Lync Server (2010 y 2013)

<img class="alignnone" src="https://lh5.googleusercontent.com/-c3V6s0Fhbwk/U2hJdVlSarI/AAAAAAAAEX8/kVF4sxVZrBc/w765-h172-no/ADerror_Lync.jpg" alt="" width="765" height="172" />

Para solucionar esto simplemente abrir la consola Usuarios y equipos de Active Directory (ejecutar dsa.msc),  ir al menú **View** y seleccionar la opción **Advanced Features**.

Luego seleccionar con el botón derecho sobre el dominio en **Find&#8230;**

En el cuadro de busqueda, insertar el nombre del usuario que se quiere habilitar en Lync Server.

Abrir las propiedades de ese usuario y en la solapa **Security**, click en **Advanced** y luego en el botón **Enable Inheritance**.

Despues de este procedimiento realizar el proceso de habilitación nuevamente.

Saludos,