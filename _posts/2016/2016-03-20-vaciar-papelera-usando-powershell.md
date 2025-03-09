---
title: Vaciar papelera usando PowerShell
date: 2016-03-20T01:09:09+00:00
author: Victor Silva
layout: post
permalink: /vaciar-papelera-usando-powershell/
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";N;s:10:"author_url";N;s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";N;s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:4:"none";s:3:"url";N;}'
dsq_thread_id:
  - "4727770303"
categories:
  - PowerShell
tags:
  - Clear-RecycleBin
  - Get-RecycleBin
  - PowerShell 5.0
  - WMF 5.0
format: aside
---
Windows Management Framework 5.0 (WMF 5.0) trajo muchas novedades, entre ellas, varios comandos muy útiles para poder realizar las tareas de administración y/o automatización de manera más efectiva, y como ejemplifica el título hoy nos vamos a centrar en _Vaciar papelera usando PowerShell_.

Hoy voy a compartir un Cmdlet simple pero funcional:

**[Clear-RecycleBin](https://technet.microsoft.com/es-es/library/mt427394.aspx)**

Vaciar papelera usando PowerShell puede parecer algo sencillo y cotidiano, pero ahora gracias a ésta actualización de PowerShell podemos contar con este Cmdlet dentro de nuestro bagage de comandos!

La sintaxis es muy simple:

    Clear-RecycleBin
    

Podemos usar el parámetro -Foce $false

<img src="https://lh3.googleusercontent.com/Sxi5IDSt1-p4hwdBxbG9gE69NWZyKvlxMfSuB1qt6SsYIbjNFXs5_kd_xvH029faFv83x853lbn6j7lmfS4V_Rf4hujKzIa2EkZ4jeaf5028FmdeZVGgtA3MJ9ZRHmIAZGHbfjNggKnN1d7wh1nXBH5jwG7XdfHzKXog9wrSGmMIfc0IH7VYmjsu_RF2AeSMe-tJtNwvod28rkPuNEtFmnBvWvlhq80foa2YmCeuXPeLKJu8wzzaSZK711ITVa0CZNJAZfgmsfA467ctpXYVxh8Yr2rPv0CmqqFxSvxLCYCCbeg0HpHnpB1TX5Wt3Lav0BIdaAgDnzjwqBxHSZEWq3Gdl3uLqdk2KTt5pYe2IYKL8EzeXp5qGS7n8c9u2iI5-Or0gC_yapB0BgTuZGX9lonFqjuXOhv4G5kAqrPOqptJqqACIwSGqR7xYALQB-fviG8TSgQWd0qveb9QNiNA2aWhkuCYgFbIFb716z_uTyoky0tVtLaW-iAKpLt8RvFfoWHH0qCMUyTD18up9vBC-CR1fMT9YpNd_RS6pYyhHPBvUX_NgWg1Bd2KO0q7Vscqi6p4=w859-h197-no" width="859" height="197" alt="Vaciar papelera usando PowerShell" class="alignnone" />

Ahora, pero que sucede si también queremos saber que vamos a eliminar dentro de la papelera?

Para ello tenemos el Cmdlet:

**Get-RecycleBin**

Ejecutando el Cmdlet anterior, vamos a obtener como resultado un lista de los archivos que se encuentren en la papelera en ese momento.

Saludos,
