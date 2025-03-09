---
title: Skype for Business Online con PowerShell
date: 2017-05-27T22:44:46+00:00
author: Victor Silva
layout: post
permalink: /sfb-online-con-powershell/
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";N;s:10:"author_url";N;s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";N;s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:4:"none";s:3:"url";N;}'
dsq_thread_id:
  - "6013520402"
categories:
  - Office 365
  - PowerShell
tags:
  - PowerShell
  - SfB Online
  - Skype for Business Online
---
Skype for Business es uno de los productos de Microsoft que ha tenido mayor aceptación en el mercado gracias a su facilidad de uso, sumado a las grandes características que ofrece como solución de comunicaciones en el mundo empresarial. A su vez, gracias a Office 365, contamos con una posibilidad de adopción muy sencilla que permite realizar una implementación de forma muy veloz. Por ello es que hoy vamos a hablar de cómo aprovechar mejor esta grandiosa solución de comunicaciones unificadas en la que voy a compartir como administrar Skype for Business Online con PowerShell en pocas líneas de código.

## Conectarnos a nuestra suscripción

Skype for Business Online, es uno de los servicios que ofrece Office 365 dentro de su suite de soluciones. Es por ello que necesitamos de PowerShell para poder administrar esta solución. Si bien existe el portal de administración, las posibilidades que ofrece son limitadas.

Para comenzar a trabajar es necesario contar con el módulo llamado [Skype for Business Online Connector](https://www.microsoft.com/en-us/download/details.aspx?id=39366). La instalación es muy sencilla; simplemente avanzar en el asistente y listo.

En segundo lugar vamos a ejecutar desde una consola de PowerShell:

{% highlight posh %}
Import-Module LyncOnlineConnector
$userCredential = Get-Credential
$sfbSession = New-CsOnlineSession -Credential $userCredential
Import-PSSession $sfbSession
{% endhighlight %}

<img src="https://cu0o0a-ch3302.files.1drv.com/y4mSlsFvAZ4LB2w7mafjO1psyGObpRAmbhZMVh9HDHs9FIAWrVmEVL4uLqL4XgpqFpjXo_jUMEcS2biSbDMb_UdkOgMwsKCkF35wiO9uYIqqcWdssjKwWXGrPpgdh-c9NekOzYD_KBrOrIjY7nswTNuQzjAPlwprZAEuaVvogoWKNRuGEbKQgQHf8idg0DaItq4QSQCXH6WMCTSQ5d0LhHHXw?width=858&#038;height=272&#038;cropmode=none" width="858" height="272" alt="Inicio de sesión" class="alignnone size-medium" />

> Es importante cerrar y volver a abrir la consola luego de la instalación del módulo, ya que puede generar un error al intentar importar el módulo.

Ingresar las credenciales de nuestra suscripción para poder realizar la conexión de forma satisfactoria.

## Obteniendo información básica

El primer cmdlet que vamos a ver es Get-CsOnlineUser, que básicamente lo que hace es desplegar información sobre un usuario o usuarios habilitados. Por ejemplo si queremos obtener información del usuario _Victor Silva_ podemos ejecutar lo siguiente:

{% highlight posh %}
Get-CsOnlineUser -Identity "Victor Silva"
{% endhighlight %}

Y que podemos obtener de este cmdlet, información como por ejemplo cual es el la dirección sip, números de teléfono asociados, a que servidores se registra y más. Para obtener la dirección sip ejecutamos:

{% highlight posh %}
Get-CsOnlineUser -Identity "Victor Silva" | select SipAddress
{% endhighlight %}

Para obtener información sobre la organización, como por ejemplo; el estado de configuración de la comunicación externa, es necesario utilizar el cmdlet Get-CsExternalAccessPolicy, de la siguiente forma:

{% highlight posh %}
Get-CsExternalAccessPolicy -Identity "FederationAndPICDefault"
{% endhighlight %}

En donde se define la identidad **_FederationAndPICDefault_** que permite identificar en que estado se encuentra cada feature como el acceso externo a la organización o la comunicación con usuarios federados:

<img src="https://cu0q0a-ch3302.files.1drv.com/y4mfl3pqqFLk241SVJu6jkCFsJSH9YlxMQYw6B2wkm9Ot7gl7Vf59KRy476ibH0dKGAdDKuv3rl3Crwptt0hEe7xLQ90CyA1sVGJgfhq2rnW-ErP2BJYmur9S1GzJ6lhWzrEoo7ZiaJrqUFVQ9T4DotP1Y7wfw6j679k7SVrePPcC2ejf2POjOjC-xcF2ilGua2AN_9vDInrqlpt8WEYaomUQ?width=673&#038;height=210&#038;cropmode=none" width="673" height="210" alt="Skype for Business Online con PowerShell" class="alignnone size-medium" />

## Políticas de usuarios

Las políticas son un conjunto de parámetros que permiten a los usuarios hacer o no hacer cosas dentro de Skype for Business. En caso de que no existan políticas asignadas a usuarios de forma personalizada, la política global es la que se aplica.

Para listar las políticas existentes en Skype for Business Online con PowerShell, usamos el cmdlet:

{% highlight posh %}
Get-CsConferencingPolicy | select Identity
{% endhighlight %}

<img src="https://cu0p0a-ch3302.files.1drv.com/y4m28MrdsyJPm5Jbg0GjVYpv-Cc47MTrRX8EpagZ_m5Iyad7XEyKkwmdOhle8DaNSCov6vMZcaZpVqfHxeCRBzIQXoUHsXIdpWFMUjRkenI8NtegiMdTAe4AnO1vhWjEvL3GoitELAqkpM1X9_1R25cf66sH6vCv11nNXpKLeGCFOhjJGzmWFwGaY-Y7dm9DEDj8f4Erg0X_G7nptnWQJmbYw?width=926&#038;height=543&#038;cropmode=none" width="926" height="543" alt="Get-CsConferencingPolicy" class="alignnone size-medium" />

¿Y que sucede si necesitamos crear una política nosotros? Para ello utilizamos **_New-CsConferencingPolicy_**. Como ejemplo vamos a tomar el requerimiento que un cliente hace unos días me solicitó: Crear una política para que los usuarios no puedan compartir su escritorio. Para cumplir con la solicitud anterior vamos a ejecutar:

{% highlight posh %}
New-CsConferencingPolicy -Identity DeshabilitarCompartirEscritorio -EnableAppDesktopSharing None
{% endhighlight %}

En donde _Identity_ es el nombre que le vamos a dar a nuestra política y la feature _EnableAppDesktopSharing_ es la que vamos a deshabilitar. Así de simple. Ahora nos resta aplicar la política a un usuario en particular:

{% highlight posh %}
Get-CsOnlineUser “Victor Silva” | Grant-CsConferencingPolicy -PolicyName DeshabilitarCompartirEscritorio
{% endhighlight %}

Y listo! El usuario Victor Silva no va a poder compartir escritorio al utilizar Skype for Business Online. Para comprobar si se aplicó correctamente la política:

{% highlight posh %}
Get-CsConferencingPolicy -ApplicableTo "Victor Silva"
{% endhighlight %}

<img src="https://dp0x0a-ch3302.files.1drv.com/y4mHIIPS15-3-JexQj-ZQ8ED18RX96Yr-5fdEE6iIalLZ03xk_nHISsciDVEn-qhVYH2YFP6V26c-V0Qk9lc7Uh6pWWWpTvCtlsdSh3KNQvrRB87U-QAUgumHv_bhdt_AHvOUAlqAuaF_wKgFw3tGWFDmGCpVbSGgXkZx80md_WXWU7lj9q1dqmftWJwRRiBhMuQpQQo-KFW8jmNHDVx2h2UA?width=859&#038;height=633&#038;cropmode=none" width="859" height="633" alt="Comprobar política de Skype for Business Online con PowerShell" class="alignnone size-medium" />

Happy scripting!