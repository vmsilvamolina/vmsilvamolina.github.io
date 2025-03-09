---
title: 'Lync Server 2013 - SIP/2.0 504 Server time-out'
date: 2015-01-29T17:21:17+00:00
author: Victor Silva
layout: post
permalink: /lync-server-2013-sip2-0-504-server-time-out/
dsq_thread_id:
  - "4487967654"
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";s:68:"https://cdn-images-1.medium.com/fit/c/200/200/0*Sz3Js055VwE6KyPu.jpg";s:10:"author_url";s:33:"https://medium.com/@vmsilvamolina";s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";s:12:"3d69dbdc9c39";s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:6:"public";s:3:"url";s:91:"https://medium.com/@vmsilvamolina/lync-server-2013-sip-2-0-504-server-time-out-3d69dbdc9c39";}'
categories:
  - Skype for Business Server
tags:
  - "1008"
  - "1009"
  - No match for domain in DNS SRV results
  - SIP/2.0 504 Server time-out
  - Unable to resolve DNS SRV Record
---
Como dice el título, implementando un Edge Server podemos encontrarnos con este error en los logs, pero con algunas particularidades.

Mayoritariamente estos errores se presentan a la hora de realizar una federación. Agregar también que otro sintoma presentado en estas situaciones es ver en la presencia del usuario, luego de agregarlo a nuestros contactos, como "Presence unknown" (presencia desconocida).

Si el error que se presenta en los logs del cliente de Lync 2013 es de este estilo:

> SIP/2.0 504 Server time-out &#8230; ms-diagnostics=1008;"
Unable to resolve DNS SRV Record"
 &#8230;

Acá les comparto una captura correspondiente:

<img src="https://lh3.googleusercontent.com/-oP0Qct7IzMU/VNEfMf6xzcI/AAAAAAAAGzE/bAHsUd7lzmE/w430-h324-no/LYNC_504_1.png" width="430" height="324" class="alignnone" />

<img src="https://lh6.googleusercontent.com/-VLfpTnEh_Wk/VNEgxrlKYHI/AAAAAAAAGzY/bRmYxtPogEg/w574-h234-no/LYNC_504_2.png" width="574" height="234" class="alignnone" />

Se debe a que en la interfaz externa del Edge tiene bloqueados los puertos **_TCP 54_** y **_UDP 53_**, requeridos en la implementación, necesarios para resolver las consultas de DNS. Debido a esto, el servidor Edge era incapaz de resolver los nombres y comunicar con dominios que eran desconocidos.

Por más información sobre los puertos requeridos ingresar al siguiente [enlace](https://technet.microsoft.com/en-us/library/gg398798.aspx).

El error SIP/2.0 504 Server time-out no es el único tipo, puede presentarse esto mismo pero con otro diagnostico:

> SIP/2.0 504 Server time-out ... ms-diagnostics=1009;"No match for domain in DNS SRV results" ...

Lo primero que deberíamos revisar en este caso es que se encuentren los registros DNS correctos para el dominio en cuestión; al ser una federación el escenario en que se presenta debemos chequear que estén creados correctamente los siguientes registros:

| FQDN                                       | Tipo | Puerto | IP/Destino                   |
| ------------------------------------------ | ---- | ------ | ---------------------------- |
| sip.dominio.com                            | A    | N/A    | IP pública de acceso al Edge |
| &#95;sip.&#95;tls.contoso.com              | SRV  | 443    | sip.dominio.com              |
| &#95;sipfederationtls.&#95;tcp.contoso.com | SRV  | 5061   | sip.dominio.com              |

En caso de que los registros en el DNS estén correctos. La opción que queda es que el dominio agregado en el Panel de Control de Lync Server, dentro de la sección Federación, sea incorrecto o esté mal ingresado. Por lo que es altamente recomendable consultar los datos con los administradores del dominio que se desea agregar a nuestra organización.

Espero poder ayudar con estos datos.

Happy scripting!