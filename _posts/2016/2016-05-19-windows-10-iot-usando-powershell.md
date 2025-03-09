---
title: Windows 10 IoT usando PowerShell
date: 2016-05-19T16:26:45+00:00
author: Victor Silva
layout: post
permalink: /windows-10-iot-usando-powershell/
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";s:68:"https://cdn-images-1.medium.com/fit/c/200/200/0*Sz3Js055VwE6KyPu.jpg";s:10:"author_url";s:33:"https://medium.com/@vmsilvamolina";s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";s:12:"f4770193d39a";s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:6:"public";s:3:"url";s:79:"https://medium.com/@vmsilvamolina/windows-10-iot-usando-powershell-f4770193d39a";}'
dsq_thread_id:
  - "4938614420"
categories:
  - PowerShell
  - Windows IoT
tags:
  - IoT
  - PowerShell
  - Raspberry Pi
  - WIndows 10 IoT
  - Windows IoT
---
Hace un tiempo que existe una gran demanda e interés por **_IoT_**. Microsoft apostó a integrar dentro de su gama de servicios esta nueva ola de "
el internet de las cosas"
. Como lo hizo? Lanzando una versión de Windows especifica para trabajar sobre dispositivos de esta índole, otorgando la posibilidad de crear soluciones mezclando el uso de software y hardware. Hoy quiero compartir como administrar Windows 10 IoT usando PowerShell.

Windows 10 IoT es un SO específico para utilizar en ciertos dispositivos, como por ejemplo Raspberry Pi.

## PS Session

Para poder administrar nuestro dispositivo vamos a ver como crear una sesión directamente desde PowerShell.

Lo primero que debemos hacer es ejecutar una consola de PowerShell como administrador, y luego ejecutar:

{% highlight posh%}
  net start WinRM
{% endhighlight %}
    

Para habilitar las conexiones remotas. Ahora estamos en condiciones de ejecutar (donde dice NombreDelDispositivo también puede ingresarse la IP):

{% highlight posh%}
  Set-Item WSMan:\localhost\Client\TrustedHosts -Value "NombreDelDispositivo"
{% endhighlight %}
    

Pulsamos _"Y"_, para aceptar y posteriormente ejecutamos:

{% highlight posh%}
  Enter-PSSession -ComputerName "NombreDelDispositivo" -Credential "NombreDelDispositivo\Administrator"
{% endhighlight %}
    
<img src="https://lh3.googleusercontent.com/3q5o6RLRM3USqOhgZm6pVUbJEHAJ3DHgUs0IxJdtlbsB_MYHTBLfoTimpWvl-sEb2m6spfV--1jsVoXNKWcCBoX8AI27McIKfJbEY1LefVi28uB-hUlb0j5LTyVrxvGrp2VPVogACk9iwzy4h36iXDE_wUBuJXDnb-QvSHRyKxrIPEqKDbPjdf_t90SBderuOjzlCitJoBG2K4qYR7BthAp5MIPCdAdkXWKqfQPo2oIZU4sM-vOmyoKaR6BdFzTARuKFVhaiBXoWF5vpONJOW2Y0B47b-4cWNaIDePUbvpxbs0blznQ_UebVfXUW1WkFkOF6HIVTzRHa7rfYivkKtsZet2RzifknMXTNJHMtk6YorAQWk1OPS1yi84Hs80XvsOGUCeT8JGgDP0H_RzppWsY3EUhyF8gVQyWv-Chs1SLm8TGcC-ay2Xf-lbvOScucv1ijJEwWWkIjw1JjnGLsyRGwLeRyAW8aq7ZK2vVEmlvkrnCtcjO8Ijx512s6orweG25kg22AWAu1P5gZKM1IEMZ7_8ZvPn75fAhJTqJu4Dk7FYkh4Ne51kQ0dLiECJbiK_HlSpoIQbAMY5ZKZtxhcMsk7ES-KS0=w815-h599-no" width="859" height="632" class alt="Windows 10 IoT usando PowerShell" />

La contraseña por defecto luego del proceso de instalación es **_p@ssw0rd_**. Si todo va bien, deberíamos de ver en la consola algo como esto:

<img src="https://lh3.googleusercontent.com/MW44-z0dFx7E0XUCswY8qXDVtVdr_zNuC1ZxQzV9LAFXnXfEHiqzPdXvx6RFfNhL4KLC_jykNDBHJ2hL2m7gZ_t56RYiS0zR67cYmKV1LwNgzDMJp1uRx6_0MVCDOFPXQrmBsDn6hSiiZdjuD57tkJTmCKF5W2pXryA4-nHJ0np_cp-cis9-0OnuGFZeI4VgjyD0av-Xx5x8VxMUocJNWXMfOUaSCMkaQ7wreu5fPlWCAR11ioBAIz7qZVQQoKAW0hYX38OZjDzkh6esIhC968uIGFH-F_jMAh_XVSlMTr0vQ73Ows70T2ueYGsFX0Hb68v8tHayuPk4aPuZmwqXG-PfStv67o3LCdInkoyB7yuVzbcGyW_0wJ2cNQTTVPsVetCENv_uspaE66P9VQzH7xNUMkZu98K8XRhYpNtS9i-HnJSlJOQR9ICiIsOHRKkE06ELaQHhLJcQ8u68X-5AR024bFkRAE1-gkXqVMLeK1iJ-z8yXFeZ3QabQu0HECl53nGfweK8z4dI_GpE04wHKxx-vUJOPz--BLSP28kJIW17_wbS2ATrSh1VqlMVmH9N_-2hRN4683UNuqfAUkjqahi7h1RW3tE=w859-h159-no" width="859" height="159" class alt="PSSession a la RaspberryPi" />

## Cambiar contraseña

Ahora que estamos conectados al dispositivo vamos a cambiarle la contraseña al usuario Administrator, simplemente ejecutando:

{% highlight posh%}
  set user Administrator ContraseñaNueva
{% endhighlight %}

## Cambiar nombre del dispositivo

Y continuando con la configuración inicial vamos a cambiar el nombre del dispositivo:

{% highlight posh%}
  setcomputername NombreNuevoDelDispositivo
{% endhighlight %}

Después de ejecutar lo anterior es necesario reiniciar el dispositivo para que aplique los cambios correctamente:

{% highlight posh%}
  shutdown /r /t 0
{% endhighlight %}

## Acceder con la nueva configuración

Ahora que tenemos nueva contraseña del usuario Administrator y también se ha modificado el nombre del dispositivo es necesario ejecutar los mismos pasos iniciales para poder generar la sesión de PowerShell (PSSession) y poder conectarnos con los datos actualizados:

{% highlight posh%}
  $Dispositivo = "NombreNuevoDelDispositivo"
  Set-Item WSMan:\localhost\Client\TrustedHosts -Value $Dispositivo
  Enter-PSSession -ComputerName $Dispositivo -Credential "$Dispositivo\Administrator"
{% endhighlight %}

Con eso ya estaríamos en condiciones de empezar a programar y probar cosas nuevas sobre nuestro nuevo dispositivo con Windows 10 IoT.

Happy scripting!
