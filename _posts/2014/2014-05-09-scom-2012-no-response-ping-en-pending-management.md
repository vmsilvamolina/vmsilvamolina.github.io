---
title: 'SCOM 2012 - No response ping en Pending Management'
date: 2014-05-09T19:44:21+00:00
author: Victor Silva
layout: post
permalink: /scom-2012-no-response-ping-en-pending-management/
twitter_cards_summary_img_size:
  - 'a:6:{i:0;i:773;i:1;i:467;i:2;i:3;i:3;s:24:"width="773" height="467"";s:4:"bits";i:8;s:4:"mime";s:9:"image/png";}'
dsq_thread_id:
  - "4483696638"
categories:
  - Operations Manager
tags:
  - Firewall
  - Monitoreo
  - SCOM
  - Ping
  - no response ping
  - Dispositivos de red
---
Tuvimos un caso en el que al utilizar las reglas de detección de dispositivos de red en SCOM 2012 nos encontró una serie de dispositivos con el estado Pending Management, con la notificación No response ping.

Estos mismos dispositivos que aparecían con la notificación de que no respondían el ping, respondían perfectamente la solicitud de ping ejecutada desde la consola (ejecutada en el mismo servidor de administración).

El problema radica en las reglas habilitadas en el Firewall.

Acceder al Firewall de Windows con seguridad avanzada y debemos revisar que las reglas que comienzan con Operations Manager estén habilitadas. Por sobre todo revisar que las que dicen ICMP estén habilitadas (dentro de las reglas de salida y entrada) y las de SNMP (para este escenario no vienen al caso pero ya quedan configuradas).

Luego de habilitarlas esperar unos segundos y volver a ejecutar la regla de detección correspondiente. Si todo va bien aparecerán los dispositivos de red respondiendo correctamente las solicitudes de ping.

A continuación les adjunto las reglas correspondientes que se deben habilitar:

<img class="alignnone" src="https://lh6.googleusercontent.com/9_oDyzFzCYu0_arqawTSDAQHRdqAAdJMQNh29Ww9ukU=w760-h303-no" alt="" width="760" height="303" />

<img class="alignnone" src="https://lh4.googleusercontent.com/-Frhum_zdzfU/U2hAjn7Es0I/AAAAAAAAEXM/u2WjkJ2dfLI/w755-h335-no/outbound_scom_firewall_rules.PNG" alt="" width="755" height="335" />

Happy scripting!