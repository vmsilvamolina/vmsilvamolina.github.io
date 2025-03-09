---
title: Verificar permisos de admin en PowerShell
date: 2016-05-01T19:09:46+00:00
author: Victor Silva
layout: post
permalink: /verificar-permisos-de-admin-en-powershell/
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";s:68:"https://cdn-images-1.medium.com/fit/c/200/200/0*Sz3Js055VwE6KyPu.jpg";s:10:"author_url";s:33:"https://medium.com/@vmsilvamolina";s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";s:12:"f688c7868df3";s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:6:"public";s:3:"url";s:88:"https://medium.com/@vmsilvamolina/verificar-permisos-de-admin-en-powershell-f688c7868df3";}'
dsq_thread_id:
  - "4847230596"
categories:
  - PowerShell
---
Algunas tareas necesitan ciertos privilegios de administrador para poder ejecutarse, por lo que conocer si nuestra sesión dispone, o no, de esta capacidad es una información relevante a la hora de trabajar desde PowerShell. Hoy vamos a ver como verificar permisos de admin en PowerShell para poder tener mayor control de nuestros scripts y, de paso, seguir aprendiendo.

Existe dentro de la documentación de Microsoft un artículo en la base de conocimiento que define el SID (Security Identifier) que presentan los administradores dentro de nuestro Sistema Operativo. El artículo que hace referencia a esta información es [KB243330](https://support.microsoft.com/en-us/kb/243330) y el SID que presentan los administradores es **_S-1-5-32-544_**.

Veamos el extracto que habla sobre el mismo:

> SID: S-1-5-32-544 Name: Administrators Description: A built-in group. After the initial installation of the operating system, the only member of the group is the Administrator account. When a computer joins a domain, the Domain Admins group is added to the Administrators group. When a server becomes a domain controller, the Enterprise Admins group also is added to the Administrators group.

Ahora que tenemos este dato, necesitamos saber si el usuario de nuestra sesión actual, tiene estos privilegios o no. Para poder obtener esta información vamos a utilizar la clase **[System.Security.Principal.WindowsIdentity](https://msdn.microsoft.com/en-us/library/system.security.principal.windowsidentity.aspx)**. Esta clase cuenta con un método llamado **_GetCurrent()_**, que su función principal es generar una lista con los permisos referentes a el usuario que se encuentra ejecutando la sesión.

{% highlight posh%}
  [System.Security.Principal.WindowsIdentity]::GetCurrent()
{% endhighlight %}
    
<img src="https://lh3.googleusercontent.com/JQwBonvNHRoktt4m3eZEnKvdZp4ykkvWVcpdWd1_S-1yMZ60qODtXs0lTdoKKc6yHwGHedk5ZIXd6Rv-RGfuW07UAxPpjN1nUTFx458WFAt11R4VsweZLPubwmMJsCzokDCnaulYFexsMGZ4CZkV8Fhl9PfTjvqkYdDu-jO06_5BLOqN41sD15vBuGDq5w4O7mbC1tyZtjnrIqt2g9VEsaSiZarFZiDfQ_4MJZGuhEVz964xDdFjmt6WIM4--GZ6pBjJUEqOwpqlXE5ZefoVpAr8SGavHNBoam8JnKKR42eA2uhb0sWv5X2LqGg4A3o4_A6PmDJELWOKKhtZYcCw-jM2MzzXAeHxAwWTwAKHIW3IAWoRtfRgs5tFbI3l8aM8QT_vkvbVbJDF7SKRs50grGdVrkjI9IszgP1rTPQXnXEbsRtLl5XhajezEnJtuU0wm-yLmOgDb1xEtZwvzy6H38kkJjTuUEDuCjM5AKNzFLV3jmbAwyAySnHmI-TM5LWsDT1C3skKrdb-Yuva48Hnu5fkqwmIJqGoNGNOsyUSMynaaHsUxPKjMG5l8vXgrcvINoz9DmpNKdBKjrb1TFBbjuTLx_IsIKk=w979-h486-no" width="979" height="486" alt="Verificar permisos de administrador en PowerShell" class="alignnone" />

Dentro de esta clase, existe la propiedad **_Groups_** que se encarga de enlistar la&#8230; :

{% highlight posh%}
  ([System.Security.Principal.WindowsIdentity]::GetCurrent()).Groups
{% endhighlight %}

<img src="https://lh3.googleusercontent.com/PXddF3zQh7Okg53_hbyaJxaZBGtq7Akk6JZIOKgG8M66VtmlM3vULSXdnVGWV1GnCInm3QRc0QfF0EZVd13pMMUi0cdgHi6z4gxHf9iRJ5JEZ5pDGnE4Cfu5KdrUID0pjJaogyxvwJoBN5cWpTMpZ92dVrFL2i9nx_jxzrmscHhL-TIZW9ppiTbyeEOSBo-M2_QRGsr_yC54mP0GqV6ifFk8M3gMrZocWSlxf3RMROp4mDQBqZwrDsIogaqlD30_I3OrG1VzbnxEaQ72u7_hjfvwRzedSNa23q1nyQmuZOV1yk03zKLZPT3UkTWasayp3pZjVgNE7My-c3YAOo6XBSImuTP-hqyvMih43q3T_7LOPQJN4xfNTx4mUIDysKlI98oTQ72GMHHV2XvOnRsMKUfSH08oG4c6PxoetEAVKFCXjsLmr-UuIikTXm2i-MpMymEqY8PHh4X1J8DWdWtBgxp9UomUzB2_wi1EiCTcFhsezPa49LrmmIYrI9VCiQjbcA8K24pqjhAif_HTjmq9hMWnG_5ASjl0_i-3gi9AYjOZcwweJO0_WPQ35MOy-QOV-McS-cFHJSJVINpXjPyYJ0etM8Bem3U=w979-h241-no" width="979" height="241" alt="Verificar permisos de admin en PowerShell" class="alignnone" />

Si a la información anterior le sumamos el SID que nos proporciona el KB que refiere a los grupos de Windows, podemos hacer una condicional simple para comprobar el estado de nuestro usuario:

{% highlight posh%}
  [bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match"S-1-5-32-544")
{% endhighlight %}
    

Que nos va a devolver un **True** o **False**, dependiendo de los privilegios en la sesión en cuestión.

Happy scripting!