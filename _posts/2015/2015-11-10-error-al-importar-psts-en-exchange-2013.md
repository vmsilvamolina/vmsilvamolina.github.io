---
title: 'Error al importar PSTs en Exchange 2013'
date: 2015-11-10T22:05:53+00:00
author: Victor Silva
layout: post
permalink: /error-al-importar-psts-en-exchange-2013/
dsq_thread_id:
  - "4497414768"
categories:
  - Exchange
  - PowerShell
tags:
  - Exchange
  - Exchange 2013
  - Get-MailboxImportRequest
  - Get-MailboxImportRequestStatistics
  - LargeItemLimit
  - New-MailboxImportRequest
---
## Importar el PST

Intentando migrar unas cuentas a una implementación de Exchange, resulta que al ejecutar el comando New-MailboxImportRequest luego de unos segundos, el estado que genera es Failed.

Rápidamente comento que para importar un PST a un Mailbox en Exchange 2013 hay que ejecutar el siguiente comando:

    New-MailboxImportRequest -Mailbox vmsilvamolina -FilePath \\Servidor\PST\vmsilvamolina.pst
    

Donde _vmsilvamolina_ es el usuario (o alias) donde se va a importar el PST, y _\Servidor\PST\vmsilvamolina.pst_ la ruta y el nombre del archivo en cuestión.

## El error&#8230;

Al ejecutar lo anterior, me econtré con un error al importar PSTs en Exchange 2013, que me indica lo siguiente:

    TooManyLargeItemsPermanentException
    

¿Cómo llegué a ese error? Fácil, ejecutando lo siguiente:

    Get-MailboxImportRequest -Status Failed | Get-MailboxImportRequestStatistics -IncludeReport | fl > C:\Reporte.txt
    

Con el comando anterior obtengo un reporte detallado de las importaciones fallidas en el Exchange. En mi caso aparecía el error que les compartí un poco más arriba.

Para poder resolver este problema, decidí revisar la documentación oficial del cmdlet _New-MailboxImportRequest_. Acá el [enlace](https://technet.microsoft.com/en-us/library/ff607310%28v=exchg.160%29.aspx) a la TechNet (si bien es para la versión 2016, a mí me funcionó perfecto). La documentación nos nombra un parámetro llamado **_LargeItemLimit_**.

Con éste parámetro, podemos "
declarar"
 de alguna manera, la cantidad de elementos de gran tamaño permitidos en la importación antes de que ésta genere un error o un estado **_Failed_**.

Entrando más en detalle, esta opción considera un elemento grande como un mensaje en el buzón de origen que supera el tamaño máximo definido en el buzón destino. Si el buzón de destino no tiene un valor de tamaño máximo de mensaje configurado específicamente, se utiliza el valor de toda la organización.

Entonces para poder ejecutar la importación de nuestro PST al mailbox requerido y previniendo generar un error por elementos de gran tamaño, tenemos que ejecutar el siguiente comando:

    New-MailboxImportRequest -Mailbox vmsilvamolina -FilePath "\\Servidor\PST\vmsilvamolina.pst" -LargeItemLimit 20
    

Donde el valor **_20_** es la cantidad de elementos que voy a "
permitir"
 migrar y que no genere error.

Saludos,