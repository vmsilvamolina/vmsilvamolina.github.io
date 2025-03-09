---
title: Disponer de PowerShell en Linux
date: 2017-02-11T15:55:15+00:00
author: Victor Silva
layout: post
permalink: /powershell-en-linux/
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";s:68:"https://cdn-images-1.medium.com/fit/c/200/200/0*Sz3Js055VwE6KyPu.jpg";s:10:"author_url";s:33:"https://medium.com/@vmsilvamolina";s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";s:12:"8ddf31a0d57a";s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:6:"public";s:3:"url";s:78:"https://medium.com/@vmsilvamolina/disponer-de-powershell-en-linux-8ddf31a0d57a";}'
dsq_thread_id:
  - "5971722912"
categories:
  - PowerShell
tags:
  - Linux
  - Linux Mint
  - PowerShell
  - PowerShell 6.0
  - PowerShell en Linux
---
PowerShell en Linux debe ser una de las cosas que más llamó la atención de los administradores de sistemas debido a las nuevas posibilidades que aparecen a la hora de trabajar en ambientes donde no existe una plataforma unificada (es decir, que no utilizan Windows de forma única). Desde hace tiempo que la gente del equipo de desarrollo de PowerShell está trabajando sobre la usabilidad de Windows PowerShell enfocados en la multiplataforma. No es nuevo el amor que está demostrando Microsoft sobre Linux y MAC, por ello es que quiero hablar un poco de la manera de trabajar con esta grandiosa herramienta desde un SO que no sea de Microsoft.

Para el post de hoy voy a usar una VM con Linux Mint 18.2 y la versión de PowerShell 6.0 (beta, ya que aún continua en desarrollo). Elegí esta versión, ya que la gente de [Distrowatch](https://distrowatch.com/) indica que es la más popular en los últimos meses!

## Instalar PowerShell en Linux Mint

Lo primero que debemos hacer es

{% highlight posh %}
#Registrar el repositorio de Microsoft para RedHat
sudo wget https://github.com/PowerShell/PowerShell/releases/download/v6.0.0-beta.3/powershell_6.0.0-beta.3-1ubuntu1.16.04.1_amd64.deb
{% endhighlight %}
    

<img src="https://du04fw-ch3302.files.1drv.com/y4mzjqg4xO_SDidOyEppe5Z2tO827xOUhu5MzWvFPKhv_M7377pTonTjafprhAqWGfPhtWYnicoAQ9_geKyJP3SDENjSyLAV506MiAvdSNwvYE01PDjgaMPRirfe4ASRS6cBB4Y5t5KS1jJSI9gqMMjtfa4-Fo-cPI5L4VgaYe7aLh1-tItItapE5aU_JdKgHF7sJ2Gx-aeKKowe8UX9VMy9Q?width=1152&#038;height=542&#038;cropmode=none" width="1152" height="542" alt="Descarga del paquete" class="alignnone size-medium" />

Continuando lo anterior y, antes de iniciar la instalación, PowerShell necesita dos paquetes adicionales que necesitamos instalar primero. Por lo tanto, debemos ejecutar el siguiente comando:

{% highlight posh %}
#Instalar paquetes necesarios
sudo apt-get install libunwind8 libicu55
{% endhighlight %}

Finalmente vamos a completar el proceso de instalación ejecutando:

{% highlight posh %}
#Instalación de PowerShell
sudo dpkg -i powershell_6.0.0-alpha.9-1ubuntu1.16.04.1_amd64.deb
{% endhighlight %}

<img src="https://du03fw-ch3302.files.1drv.com/y4m8KDNQVKMMSpxq0EdYjSEic1-bXzrtPQ8LWMwZ8UitX0CnpJ8ggcalyK1P_8bcPaDjMEqH0LdQ7rkCZ4FDsVcgr9j9dvUMdXgxyub0HSsztGdizGU6WCijS1JQMIopXo7aNrLS_jip6NK7oXuD9jndo_Rc0bPdPs3aja64zARDVLa4dRmBObvUIkOuwJmchEBxYyTz2UucJaYSk5XgEjiZw?width=1152&#038;height=542&#038;cropmode=none" width="1152" height="542" alt="Instalación de PowerShell en Linux" class="alignnone size-medium" />

Y luego de completada la instalación, debemos iniciarlo desde la consola, con una acción tan simple como ejecutar lo siguiente:

{% highlight posh %}
#Iniciar PowerShell
PowerShell
{% endhighlight %}
    

Perfecto! Ahora tenemos PowerShell en Linux! Lo primero que vamos a revisar es concretamente que versión tenemos ejecutando en nuestro sistema. Para ello, ingresar lo siguiente:

{% highlight posh %}
$PSVersionTable
{% endhighlight %}

<img src="https://du02fw-ch3302.files.1drv.com/y4mcM6y_9KO9b6Fp8UhkzHV8TMuqsv-OaXM7zLFnqYWNHyPfkbOk4SYk7NANk7IhXurl7qGNPblwvDIJYQ84xxyoNXAuc7TGDPH2vQp8SY63uy0W9Uj3rV27p2zQtJw3QyFCg4h7uaxP0vBFhK-jPEIby4ok6tbI1MU8GHailHApUXn6UMU_3GWp9I9IvqX-2x8JmhjRgsmnQU-Wgex017tYg?width=938&#038;height=387&#038;cropmode=none" width="938" height="387" alt="$PSVersionTable en Linux Mint" class="alignnone size-medium" />

Para comprobar los comandos disponibles de PowerShell en nuestra flamante instalación vamos a utilizar el comando:

{% highlight posh %}
Get-Command
{% endhighlight %}

Y en el caso de querer conocer que módulos se encuentran presentes y disponibles:

{% highlight posh %}
Get-Module -ListAvailable
{% endhighlight %}

Ahora estamos en condiciones para utilizar PowerShell en Linux Mint!!! Por lo que recomiendo revisar algunos de mis anteriores post sobre [PowerShell](http://blog.victorsilva.com.uy/?s=powershell&submit=Buscar) para empezar a sacarle provecho a esta gran herramienta.

Happy scripting!