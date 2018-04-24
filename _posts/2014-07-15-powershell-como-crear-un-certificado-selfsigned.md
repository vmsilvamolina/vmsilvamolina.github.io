---
title: 'Powershell &#8211; Como crear un certificado SelfSigned?'
date: 2014-07-15T13:41:52+00:00
author: Victor Silva
layout: single
permalink: /powershell-como-crear-un-certificado-selfsigned/
dsq_thread_id:
  - "4584003331"
categories:
  - PowerShell
tags:
  - Certificados
  - Cmdlets
  - PowerShell
  - SelfSigned
format: aside
---
A partir de la versión 4.0 de PowerShell (ya incluida en Windows 8.1 y Windows Server 2012 R2) se incluye un Cmdlet que permite crear un certificado selfsigned desde nuestra consola y con una simple línea de código.

El cmdlet <strong>New-SelfSignedCertificate</strong> crea un certificado auto-firmado (SelfSigned) para realizar pruebas. Utilizando el parámetro <em>CloneCert</em>, se puede crear un certificado sobre la base de un certificado existente con todos los datos del certificado original a excepción de la clave pública. Se creará una nueva llave basada en el mismo algoritmo y longitud. Para obtener mas datos sobre este procedimiento les dejo el enlace a la <a title="New-SelfSignedCertificate" href="http://technet.microsoft.com/en-us/library/hh848633.aspx" target="_blank">TechNet.</a>

En este ejemplo se crea un certificado de servidor SSL SelfSigned alojado en el servidor <em>Server01</em>, con el Subject Alternative Name, Subject e Issuer <em>blog.victorsilva.com.uy</em>:

<pre class="lang:ps decode:true ">New-SelfSignedCertificate -DnsName blog.victorsilva.com.uy -CertStoreLocation cert:LocalMachineServer01</pre>

Happy scripting!