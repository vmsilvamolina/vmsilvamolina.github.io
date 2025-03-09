---
title: Cambiar puerto por defecto en ADFS
date: 2016-06-15T09:49:52+00:00
author: Victor Silva
layout: post
permalink: /cambiar-puerto-defecto-adfs/
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";s:68:"https://cdn-images-1.medium.com/fit/c/200/200/0*Sz3Js055VwE6KyPu.jpg";s:10:"author_url";s:33:"https://medium.com/@vmsilvamolina";s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";s:12:"62fe158feac7";s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:6:"public";s:3:"url";s:81:"https://medium.com/@vmsilvamolina/cambiar-puerto-por-defecto-en-adfs-62fe158feac7";}'
dsq_thread_id:
  - "4978009080"
categories:
  - Active Directory Federation Services
  - PowerShell
tags:
  - PowerShell
  - ADFS
  - ADFS port
  - Active Directory Federation Services
---
En alguna ocasión podemos llegar a encontrarnos con la necesidad de tener que cambiar puerto por defecto en ADFS en nuestra implementación de Active Directory Federation Services sobre Windows Server 2012 R2, ya que podemos encontrarnos en un escenario que, por ejemplo, comparta varios servicios en una IP pública y por ende, el puerto 443 se encuentre actualmente en otro servicio publicado.

Vamos a tratar de simplificar lo más posible los pasos a seguir, ya que el procedimiento es bastante sencillo.

Primero debemos borrar los registros que definen el puerto por defecto. Y lo vamos a hacer ejecutando una consola de PowerShell como administrador. Vamos a ejecutar:

    netsh http del urlacl https://+:443/adfs/
    netsh http del urlacl https://+:443/FederationMetadata/2007-06/
    

Posteriormente tenemos que agregar las entradas con el puerto que deseamos utilizar, en el ejemplo, el puerto es el 8443:

netsh http add urlacl https://+:8443/adfs/ user=”NT SERVICE\adfssrv” delegate=yes
  
netsh http add urlacl https://+:8443/FederationMetadata/2007-06/ user=”NT SERVICE\adfssrv” delegate=yes

Y finalmente, ejecutar:

    Set-ADFSProperties -HttpsPort 8443
    

Si al intentar ejecutar el comando anterior les generó un error, indicando que no se encuentra el Cmdlet o algo similar, vamos a ejecutar:

    Add-PSSnapin Microsoft.Adfs.PowerShell
    

Para cargar correctamente los Cmdlets correspondientes a la administración del rol.

Como último paso, reiniciar el servicio **_Active Directory Federation Services_**

Ahora bien, **ADFS 3.0** no depende directamente del IIS, pero para que todo lo anterior se vea reflejado correctamente debemos instalar el rol de IIS y luego modificar los enlaces agregando **HTTPS** utilizando el puerto _8443_.

Happy scripting!
