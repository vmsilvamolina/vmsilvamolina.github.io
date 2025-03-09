---
title: New-MailboxExportRequest error
date: 2016-04-13T23:03:30+00:00
author: Victor Silva
layout: post
permalink: /new-mailboxexportrequest-error/
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";s:68:"https://cdn-images-1.medium.com/fit/c/200/200/0*Sz3Js055VwE6KyPu.jpg";s:10:"author_url";s:33:"https://medium.com/@vmsilvamolina";s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";s:12:"e36a95732c72";s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:6:"public";s:3:"url";s:77:"https://medium.com/@vmsilvamolina/new-mailboxexportrequest-error-e36a95732c72";}'
dsq_thread_id:
  - "4745319100"
categories:
  - Exchange
tags:
  - New-MailboxExportRequest
---
Los que intentaron exportar un PST de un mailbox (o importar un PST a un mailbox, usando New-MailboxImportRequest) en Exchange 2010 SP1+ se pudieron haber encontrado con el siguiente error:

> El termino "New-MailboxExportRequest" no se reconoce como nombre de archivo de un cmdlet, funcion, archivo de script o programa ejecutable.

O en inglés:

> The term "New-MailboxExportRequest" is not recognized as the name of a cmdlet, function, script file, or operable program.

<img src="https://lh3.googleusercontent.com/igs1MN5Ki5pAEzbOZdglQoZR6QDxInVJv6_NXOEWQJdPfBPzbRNkGXV2YckGOaKSxGrwK_qHdvzbGfox9wGzk6g6i-4PEvEXO29saccTBhWE9wrjm7hai5ZmdKlw44yYTqJyPu1q33-FzC68ExRUNap0-IWp5-6RjCGaTKg-r26KjZ-js5W5W0BpW4QkS1wecqibq0UUGMbM7ePldpxu2R-9Pl_1QrmPdoq53o4YLEChlz2aCrzot4No4lGVBQOg-ynoukFX_poMrpiZWbksr6qQO066mEWmJbZ4vGcZIWdAtXHMAEn63kvud53ALQi2dVdd8ZXWurO_-_L6NVAFICc7wJDCV2Whoh8TgBaNhZWpFx1_oqe-f5teb-DrjXClD4ESNzBsDz-c_Ayn1xK-5PRo2tcaLQGxmXHpCBrw1LTB18iOBj-LXS56ob0NgS6UGCVK8gRASxra97nqPu_gagVevBMQQleQq7GKJ6Zr9kajNWXvfV2Ls-O7tsVCBLdQep0hQriNdnCqUgBfx3xXW3Yx5l1PvPNoFVY_8jTNzglzZhc6CNYZMVDswxx1MrmYuDvn=w959-h130-no" width="959" height="130" alt="New-MailboxExportRequest" class="alignnone" />

Por motivos de seguridad, es necesario asignar permisos específicos al usuario que intenta ejecutar: **New-MailboxExportRequest** o **New-MailboxImportRequest**.

El permiso que debemos asignar es el rol _"Import Export Mailbox"_, y como no puede ser de otra manera, lo asignamos usando la **_Exchange Management Shell_** de la siguiente forma:

{% highlight posh%}
  New-ManagementRoleAssignment –Role “Mailbox Import Export” –User "DOMAIN\USER"
{% endhighlight %}

En donde **_DOMAIN\USER_** vamos a tener que definir el usuario el cuál pretende ejecutar el comando.

Una vez ejecutado el código anterior es necesario volver a ejecutar una Exchange Management Shell para que se aplique correctamente el cambio.

Happy scripting!