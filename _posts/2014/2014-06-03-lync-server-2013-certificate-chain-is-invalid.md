---
title: 'Lync Server 2013 - Certificate chain is invalid'
date: 2014-06-03T20:09:17+00:00
author: Victor Silva
layout: post
permalink: /lync-server-2013-certificate-chain-is-invalid/
dsq_thread_id:
  - "4472517512"
categories:
  - Skype for Business Server
tags:
  - Lync Server 2013
  - CA
  - Certificate error
  - Chain is invalid
---
Durante la instalación de Lync Server 2013, puede que nos aparezca el siguiente mensaje de error: **Warning: The chain of the certificate XXXX is invalid** durante la solicitud de certificados. A continuación una imagen de ejemplo del error:

<img class="alignnone" src="https://lh5.googleusercontent.com/-srrkZbhEUPw/U54pZzxHOBI/AAAAAAAAFB8/HRKHdRqeLno/w406-h306-no/Lync_Cert_error_chain.png" alt="" width="406" height="306" />

La razón de este error se debe a que la entidad certificadora que esta emitiendo los certificados no se encuentra en la lista de la Trusted Root Certification Authorities.

Por lo que para solucionar este inconveniente basta con agregar nuestra Entidad Certificadora a esta lista, para ello debemos hacer lo siguiente:

  1. Acceder a la URL donde solicitamos los certificados de nuestra CA (por ejemplo: http://miservidor.midominio/certsrv)
  2. Click en **Download a CA certificate, certificate chain, or CRL**.
  3. Click en **Download CA certificate chain**.
  4. Importar el certificado descargado dentro de Trusted Root Certification Authorities (Ejecutar: MMC > File > Add/remove Snap-in > Certificates > Computer Account > Trusted Root Certification Authorities > Click derecho > Certificates > All Tasks > Import).

Luego de realizado los pasos anteriores, resta volver a ejecutar la solicitud de certificados para corroborar de que funciona todo correctamente.

Happy scripting!