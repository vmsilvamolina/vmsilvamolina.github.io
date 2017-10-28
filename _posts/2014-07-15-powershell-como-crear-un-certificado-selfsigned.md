---
id: 470
title: 'Powershell &#8211; Como crear un certificado SelfSigned?'
date: 2014-07-15T13:41:52+00:00
author: Victor Silva
layout: simple
guid: http://blog.victorsilva.com.uy/?p=470
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
A partir de la versión 4.0 de PowerShell (ya incluida en Windows 8.1 y Windows Server 2012 R2) se incluye un Cmdlet que permite crear un certificado seflsigned desde nuestra consola y con una simple línea de código.

<span id="result_box" lang="es"><span class="hps">El</span> <span class="hps">cmdlet <strong>New</strong></span><strong><span class="atn">&#8211;</span>SelfSignedCertificate</strong> <span class="hps">crea</span> <span class="hps">un certificado auto</span><span class="atn">&#8211;</span>firmado (SelfSigned) <span class="hps">para realizar pruebas.</span> <span class="hps">Utilizando</span> <span class="hps">el parámetro</span> <em><span class="hps">CloneCert</span></em>, <span class="hps">se puede crear</span> un certificado <span class="hps">sobre la base de</span> <span class="hps">un certificado existente</span> <span class="hps">con todos los </span><span class="hps">datos del</span> <span class="hps">certificado original</span> <span class="hps">a excepción de</span> <span class="hps">la clave pública</span>. <span class="hps">Se creará una nueva llave basada en el mismo algoritmo y longitud.</span>  Para obtener mas datos sobre este procedimiento les dejo el enlace a la <a title="New-SelfSignedCertificate" href="http://technet.microsoft.com/en-us/library/hh848633.aspx" target="_blank">TechNet.</a> </span>

<span id="result_box" lang="es"><span class="hps">En este ejemplo se</span> <span class="hps">crea</span> <span class="hps">un certificado de servidor</span> <span class="hps">SSL</span> <span class="hps">SelfSigned</span> <span class="hps">alojado en el servidor <em>Server01</em>,</span><span class="hps"> con el</span> Subject Alternative Name, Subject e Issuer <em>blog.victorsilva.com.uy</em>:</span>

<pre class="lang:ps decode:true ">New-SelfSignedCertificate -DnsName blog.victorsilva.com.uy -CertStoreLocation cert:LocalMachineServer01</pre>

Saludos,