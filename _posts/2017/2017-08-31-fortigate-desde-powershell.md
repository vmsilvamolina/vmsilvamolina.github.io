---
title: Administración de FortiGate desde PowerShell
date: 2017-08-31T14:22:45+00:00
author: Victor Silva
layout: post
permalink: /fortigate-desde-powershell/
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";s:68:"https://cdn-images-1.medium.com/fit/c/200/200/0*Sz3Js055VwE6KyPu.jpg";s:10:"author_url";s:33:"https://medium.com/@vmsilvamolina";s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";s:12:"d4127a8690ee";s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:6:"public";s:3:"url";s:96:"https://medium.com/@vmsilvamolina/administraci%C3%B3n-de-fortigate-desde-powershell-d4127a8690ee";}'
dsq_thread_id:
  - "6184136723"
categories:
  - PowerShell
tags:
  - FortiGate
  - Fortinet
  - PowerShell
---

Hace un tiempo comencé a ver temas relacionados con Fortinet, en particular con el producto FortiGate. Lo divertido de esto fue que al verme frente a la consola web de administración de FortiGate, lo primero que dijeron fue: "¿Por qué no administras FortiGate sobre PowerShell?". Luego de esa pregunta es que me puse a escribir este artículo intentando armar algo para trabajar con FortiGate desde PowerShell.

En primer lugar voy comentar que Fortigate es una solución de networking que contiene, entre otros, firewall, filtrado de contenido, VPN, antivirus y antispam. Y una de las formas que tenemos para acceder a este appliance es vía SSH.

No voy a entrar en la forma que debemos configurar nuestro FortiGate para que cumpla con las buenas prácticas recomendadas. Para este laboratorio va a estar configurado el _puerto 2223 para SSH_ y va a existir un usuario _superadmin_ como usuario de acceso.

## Conexión al FortiGate

Lo primero que vamos a ver como resolver es la conexión al equipo en sí, utilizando SSH. Tal como habíamos mencionado hace un momento, es requisito contar con SSH en nuestro equipo. Para ello hace un tiempo en este blog escribí una entrada sobre como instalar SSH en PowerShell ([enlace](http://blog.victorsilva.com.uy/ssh-en-powershell/)).

Luego contar con el requerimiento anterior vamos a hacer una simple prueba: Desde la consola de PowerShell vamos a comprobar que no tenemos respuesta de ping a la interface que queremos acceder y luego vamos a habilitarla por medio de la conexión SSH.

Así que lo primero ejecutamos:

{% highlight posh %}
ping 192.168.200.1 -n 1
{% endhighlight %}

Con el parámetro **_-n_** indicamos la cantidad de paquetes que vamos a utilizar. Luego nos conectamos por SSH, ejecutando e ingresando la contraseña correspondiente:

{% highlight posh %}
ssh superadmin@192.168.200.1 -p 2223
{% endhighlight %}    

La estructura anterior indica que al host _192.168.200.1_ nos vamos a conectar con el usuario _superadmin_ utilizando el _puerto 2223_ como habíamos definido anteriormente.

Ya conectados a nuestro equipo Fortigate vamos a ejecutar el siguiente bloque de código para habilitar el ping en la interface que estamos utilizando para conectarnos:

{% highlight posh %}
config system interface
edit port1
set allowaccess ping https ssh
end
{% endhighlight %}

Y por último vamos a comprobar que ahora tenemos respuesta al ping, ejecutando nuevamente:

{% highlight posh %}
ping 192.168.200.1 -n 1
{% endhighlight %}

<img src="https://cu2sww-ch3302.files.1drv.com/y4mHkQVgMjDhWRkfNQ246iwgsQKnyZRpgZE6XgDusv9C1a723G-PZbzwpcBLl9bD21Y5i2_JXHBl0tliZh0jPRR9OJ6ip7g1YO471ZCwwzc87j89s70-gPkjBcrmQjptvv530bDHkxxBftosdUM2K1DaKWT4Je1erqx4VQXad5xyJBw2gIKmSUkW6zNMMqdnX-kQDQJOu74liprPaZLqzMfHw?width=859&#038;height=632&#038;cropmode=none" width="859" height="632" alt="Fortigate desde PowerShell" class="alignnone size-full" />

## Primer función en PowerShell

Ahora que tenemos un poco más claro como conectarnos a nuestro FortiGate, vamos a definir una función para definir acciones sobre el equipo. Una acción que es necesaria al momento de comenzar a configurar el dispositivo es habilitar los diferentes accesos en las interfaces. Para ello definimos la siguiente función:

{% highlight posh %}
function Set-FortigateAccess {
    [OutputType([String])]
    param
    (
        [Parameter(Mandatory=$true)]
        [String]$HostAddress,
        [Parameter(Mandatory=$false)]
        [Int]$HostPort = 22,
        [Parameter(Mandatory=$true)]
        [String]$Credential,
        [Parameter(Mandatory=$false)]
        [String]$Interface,
        [Parameter(Mandatory=$false)]
        [String]$AllowAccessOptions
    )

$Command = @"
config system interface
edit $Interface
set allowaccess $AllowAccessOptions
end
"@

try {
    ssh $HostAddress -p $HostPort -l $Credential $Command | Out-Null
} catch {
    Write-Warning -Message $error[0].exception.message
}
}
{% endhighlight %}
    

En la que básicamente armamos un bloque con los comandos para habilitar las opciones por medio de **_allowaccess_**para permitir el acceso desde SSH, HTTPS o HTTP, por ejemplo.

Y listo! con lo anterior tenemos nuestra primer función para comenzar a trabajar sobre nuestro módulo de FortiGate desde PowerShell.

Happy scripting!