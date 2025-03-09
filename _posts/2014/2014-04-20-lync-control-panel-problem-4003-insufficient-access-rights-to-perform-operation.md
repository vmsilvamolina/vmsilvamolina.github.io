---
title: 'Lync Control Panel - Problem 4003 Insufficient access rights to perform operation'
date: 2014-04-20T12:48:26+00:00
author: Victor Silva
layout: post
redirect_from: /lync-control-panel-problem-4003-insufficient-access-rights-to-perform-operation/
permalink: /lync-4003-error/
dsq_thread_id:
  - "4491978451"
categories:
  - Skype for Business Server
tags:
  - Lync Server 
  - Insufficient access rights
  - Problem 4003
---
Al momento de habilitar usuarios en Lync Server, en algunas ocasiones me he encontrado con el siguiente error:

>Active Directory operations failed on “Front End FQDN”. You cannot retry this operation: “Insufficient access rights to perform the operation 00002098: SecErr: DSID-03150E8A, problem 4003 (INSUFF\_ACCESS\_RIGHTS)

Este error aparece al intentar dar de alta un usuario en Lync Server (2010 y 2013) con privilegios elevados en Active Directory.

<img class="alignnone" src="https://lh5.googleusercontent.com/-c3V6s0Fhbwk/U2hJdVlSarI/AAAAAAAAEX8/kVF4sxVZrBc/w765-h172-no/ADerror_Lync.jpg" alt="" width="765" height="172" />

Para solucionar esto simplemente abrir la consola Usuarios y equipos de Active Directory (ejecutar dsa.msc), ir al menú **View** y seleccionar la opción **Advanced Features**.

Luego seleccionar con el botón derecho sobre el dominio en **Find...**

En el cuadro de búsqueda, insertar el nombre del usuario que se quiere habilitar en Lync Server.

Abrir las propiedades de ese usuario y en la solapa **Security**, clic en **Advanced** y luego en el botón **Enable Inheritance**.

Después de este procedimiento realizar el proceso de habilitación nuevamente de los usuarios en cuestión para poder aprovechar esta gran solución de comunicaciones unificadas.

Happy scripting!