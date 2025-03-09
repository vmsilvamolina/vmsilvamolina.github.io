---
title: 'Error al acceder a los informes desde una consola remota en SCCM 2012'
date: 2014-04-10T17:59:21+00:00
author: Victor Silva
layout: post
redirect_from: /error-al-acceder-a-los-informes-desde-una-consola-remota-en-sccm-2012/
permalink: /error-consola-remota-sccm2012/
dsq_thread_id:
  - "4513590867"
categories:
  - Configuration Manager
  - System Center
tags:
  - Certificados
  - Error
  - SCCM 2012
  - SSL/TLS
---
Si estamos trabajando con System Center Configuration Manager 2012, y deseamos instalar la consola en un equipo cliente, puede surgir un error de conexión que nos impida la correcta ejecución de la misma.

El error y el mensaje puede ser el siguiente:

> The underlying connection was closed: Could not establish trust relationship for the SSL/TLS secure channel.

Para poder resolver este problema basta con exportar el certificado personal del servidor de la base de datos e importarlo dentro del almacén **Trusted Root Certification Authorities.**

Luego simplemente reiniciar la consola y... todo perfecto!

Happy scripting!