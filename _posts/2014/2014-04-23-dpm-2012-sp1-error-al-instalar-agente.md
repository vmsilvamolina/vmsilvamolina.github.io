---
title: 'DPM 2012 SP1 - Error al instalar agente'
date: 2014-04-23T21:22:20+00:00
author: Victor Silva
layout: post
redirect_from: /dpm-2012-sp1-error-al-instalar-agente/
permalink: /dpm2012sp1-error-agente/
dsq_thread_id:
  - "4473421333"
categories:
  - Data Protection Manager
tags:
  - DPM
  - Error ID 270
  - Error ID 308
  - Event ID 10016
---
Al intentar realizar la instalación del agente de DPM 2012 SP1 en un servidor, nos encontramos con un evento que indica un error a la hora de actualizar el estado del agente.

El siguiente error en la consola de Data Protection Manager es el que aparece en este escenario:

> Data Protection Manager Error ID: 270
> 
> The agent operation failed on because DPM could not communicate with the DPM protection agent. The computer may be protected by another DPM server, or the protection agent may have been uninstalled on the protected computer.

Si nos fijamos en los eventos del servidor donde queremos instalar el agente nos aparece el evento con **ID 10016.**

Lo primero que vamos a revisar es que el servidor que aloja la instalación de DPM se encuentre en los siguientes grupos:

  * Distributed COM Users
  * DPMRADCOMTrustedMachines
  * DPMRADmTrustedMachines

Luego debemos revisar los permisos para las aplicaciones DCOM. Para ello, debemos ir a Inicio, Herramientas administrativas, Component Services.

Desde allí seleccionar la aplicación de DPM (si nos fijamos, coincide el SID del evento 10016), clic derecho propiedades y luego en los permisos agregar el servidor de DPM.

Vamos a la consola de DPM y seleccionamos refresh para ver el status del agente.

En esta oportunidad nos indica el siguiente error:

> Data Protection Manager Error ID: 308
>  
> The protection agent operation failed because DPM could not communicate with the Protection Agent service on.

Para solucionar el anterior error, debemos desinstalar el agente desde el panel de control, programas y características desde el servidor y luego ir al servidor de DPM y desinstalar desde la consola.

Ahora si volver a ejecutar la instalación y todo debería de funcionar correctamente.

Happy scripting!