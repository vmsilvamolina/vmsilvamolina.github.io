---
title: Cambiar password en ADFS
date: 2018-07-07T18:57:00+00:00
author: Victor Silva
layout: post
permalink: /cambiar-password-adfs/
excerpt: "ADFS ofrece la posibilidad de habilitar (por defecto se encuentra deshabilitada) una funcionalidad para permitir al usuario cambiar la contraseña desde el propio portal. Esto permite resolver situaciones como usuarios con contraseñas expiradas o nuevos usuarios que deben cambiar la password en el siguiente inicio de sesión."
categories:
  - PowerShell
tags:
  - PowerShell
  - ADFS
  - Password Change
  - Cambiar contraseña
  - AD
---

ADFS ofrece la posibilidad de habilitar (por defecto se encuentra deshabilitada) una funcionalidad para permitir al usuario cambiar la contraseña desde el propio portal. Esto permite resolver situaciones como usuarios con contraseñas expiradas o nuevos usuarios que deben cambiar la password en el siguiente inicio de sesión.

Estas situaciones son encasilladas dentro de "password change", debido a que el usuario conoce su actual contraseña y quiere, o debe, asignar una nueva a su usuario. Hay que considerar que lo anterior no significa un "password reset" donde el usuario no conoce su contraseña y por medio del uso de una credencial alternativa (preguntas de seguridad, número de teléfono o mail) se establece un mecanismo para definir una nueva contraseña.

### Procedimiento

Lo primero es visualizar la configuración actual desde el portal de ADFS, donde figura como un endpoint adicional:

> /adfs/portal/updatepassword

<img src="https://ttgqsa.ch.files.1drv.com/y4miPwvoRtgAqy73PXw6u6Anzk4y9e6m1fEnDgGZOiYCkkKaMKgDRJBNjSBJvE-hCaUzQcqTgncXoSR7v56n4fJ2ZyG305AvJBOxQfCTe0SAv394_Pgzv6splTPzo8PqrHMwj90kRgwJSQIrvI8KzCyP3tRnKgUA8ngsVm-oM31nR0jer4R_JUDN0uowevnEAhqdke9-LbdutGzEs2ll4PWgg?width=731&height=77&cropmode=none" width="731" height="77" alt="Update password endpoint" class="alignnone" />

En caso que hagamos la comprobación desde la consola de PowerShell, debemos utilizar el cmdlet llamado **Get-AdfsEndpoint** (más información en el siguiente [enlace](https://docs.microsoft.com/en-us/powershell/module/adfs/get-adfsendpoint)) de la siguiente manera:

{% highlight posh%}
	Get-AdfsEndpoint
{% endhighlight %}

<img src="https://gsropq.ch.files.1drv.com/y4moH_gyxmHC_PKGES7Luj5bE0wLV8vIWHycE7GCn50Stqcybt7yEy090-zOiObZ3An5GCAAE-aATKUUh3ML0Nsu_hNT0IvxFMUxVepKiG7Q5uQI8i3jAsdd9IXWqewzByx4VYNgFJQcudR8u6IM3HG1kSwHm-ywr570vDSQ-5yMJ6WInGip6Xd9fx0Iqsm_sQrih4vWi-dFoHntIorWZRctQ?width=528&height=328&cropmode=none" width="528" height="328" alt="" class="alignnone" />

Dentro del resultado aparecerá como se resalta en la imagen anterior la configuración para el endpoint **/adfs/portal/updatepassword**.

Para habilitar el cambio de contraseña en el portal, se deberá ejecutar el comando:

{% highlight posh%}	
	Enable-AdfsEndpoint "/adfs/portal/updatepassword"
{% endhighlight %}

<img src="https://p6qf7q.ch.files.1drv.com/y4maa5h0I7L4XkLe0sDY8RULkXad19VaAw2LHkGCbGDxjRYxdewlMo1LN9eZdEVlSCy0TItWtkV0awptWBK9s7BfJmOB9Phbh547QyELKxZGuBG4iqwR5ZEDflVzQ20RdnYKMGW-J-I-Pa9Lw0-lYSgBUyGVViKrKjlbGjeokKmISMrEf08Qqvi02tUBfhcFO7AXWThlPv8eSkc07gXTu9BmA?width=839&height=69&cropmode=none" width="839" height="69" alt="" class="alignnone" />

Luego de ejecutar el comando anterior, es necesario reiniciar el servicio de ADFS para que se aplique el cambio correctamente.

Ahora, si ingresamos con una cuenta de AD que se encuentre con una contraseña expirada, al ingresar al portal nos vamos a encontrar con lo siguiente:

<img src="https://ddbesg.ch.files.1drv.com/y4mrrHb4DvxvidKTCCYfo6qqfkZKJLPk63o4gmUGw3QC7OoS1nYwz92sPu8GkEWJygZl5Z0a1qQSQp2MiAMhayb4bJI7FNcCM54H5g8Erwkn_26EenPs2x3mdytgfxvCwy2TZZeu0gld-V6tz2nMyFkvwBXD4WorIQKeQXnwLoH_2mFiBKsxithiEnSuNcpARE6YGzpcLP7l6JDvcyynAdO4Q?width=407&height=387&cropmode=none" width="407" height="387" alt="" class="alignnone" />

Donde vamos a poder actualizar nuestra contraseña sin salir del portal, ni ingresar a otra URL de forma manual.

También es posible acceder directamente a la siguiente URL para realizar el cambio de contraseña en caso que se requiera instanciar esta funcionalidad de forma manual:

[https://adfs.contoso.com/adfs/portal/updatepassword/](https://adfs.contoso.com/adfs/portal/updatepassword/)

Hace un tiempo escribí un artículo sobre ADFS y cómo personalizar el portal para que muestr logos personalizados y más. El enlace es el siguiente: [https://blog.victorsilva.com.uy/customizar-la-web-adfs/](https://blog.victorsilva.com.uy/customizar-la-web-adfs/).

Happy scripting!