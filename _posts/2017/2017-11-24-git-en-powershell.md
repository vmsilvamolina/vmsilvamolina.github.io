---
title: Git en PowerShell
date: 2017-11-24T7:24:21+00:00
author: Victor Silva
layout: post
permalink: /git-en-powershell/
excerpt: "Actualmente creo que nadie que trabaja en áreas de tecnologías de la información desconoce lo que es Git. O al menos, creo que nadie debería continuar por la vida sin tener ni la más mínima idea de lo beneficioso que es el mundo del control de versiones. Git es un sistema de control de versiones (Version Control System o VCS en inglés) distribuidas y 'open source'. Por más información, adjunto el enlace a la web oficial aquí: https://git-scm.com/."
categories:
  - PowerShell
tags:
  - PowerShell
  - Git
  - Posh-Git
---

Actualmente creo que nadie que trabaja en áreas de tecnologías de la información desconoce lo que es Git. O al menos, creo que nadie debería continuar por la vida sin tener ni la más mínima idea de lo beneficioso que es el mundo del control de versiones. Git es un sistema de control de versiones (Version Control System o VCS en inglés) distribuidas y *open source*. Por más información, adjunto el enlace a la web oficial [aquí](https://git-scm.com/).

En este post, voy a tomar como requisito puntualmente lo siguiente:

* Git for Windows
* Posh-Git

## Git for Windows
Para descargar Git for Windows es necesario acceder al siguiente enlace: [Git for Windows](https://git-for-windows.github.io/) y seguir el asistente de instalación.

Luego de la instalación, vamos a ejecutar lo siguiente:

{% highlight posh %}
git config --global user.name 'nombre'
  git config --global user.email 'email address'
{% endhighlight %}

Con lo anterior definimos el usuario y mail que vamos a utilizar en nuestros repositorios. En el caso de GitHub es necesario para poder hacer commits y que aparezca en la gráfica de contribuciones de nuestro perfil.

## Posh-Git
En el caso de Posh-Git, debemos considerar que es un módulo de PowerShell, por lo que podemos descargarlo e instalarlo desde la gallery. Para ello vamos a ejecutar:

{% highlight posh %}
Install-Module -Name posh-git -Force
{% endhighlight %}

## PowerShell profile

Ya tenemos todos los requisitos para utilizar Git desde PowerShell, aunque resta modificar el perfil nuestro de PowerShell. ¿Por qué? Porque si bien el módulo se encuentra instalado, cada vez que abrimos una consola de PowerShell vamos a tener que importarlo para poder hacer uso del mismo.

Antes de ver que es lo que vamos a agregar en el perfil, es necesario saber si ya tenemos el archivo creado o no. Para ello ejecutamos:

{% highlight posh %}
Test-Path $profile
{% endhighlight %}

Si la salida en consola es "False", entonces debemos crear el archivo, en vez de editarlo. 

> El archivo profile es el siguiente: C:\Users\<userName>\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1

En caso de contar con Visual Studio Code instalado en el equipo, ejecutamos lo siguiente:

{% highlight posh %}
code $profile
{% endhighlight %}

Así podemos editar el archivo existente o comenzar a trabajar sobre él en caso que no exista aún.
Ahora sí, debemos agregar lo siguiente para poder importar el módulo en cada nueva ejecución de la consola:

{% highlight posh %}
cd $home
  Import-Module -Name posh-git -ErrorAction SilentlyContinue
{% endhighlight %}

Y cada vez que nos ubiquemos en una carpeta que sea un repositorio de git, el prompt va a cambiar de la siguiente manera:

<img src="https://oypsow.ch.files.1drv.com/y4mrLXfqnQurLY-X4hClQLzCwwNLLXbeR9Aw1qFTdvro4dTbOzctq-y-O0L6PC0jmHlZHujOygoII6fsrkCzwgEPTnVZG8N22MJHM1pcwQVo_xeuwVZg6AGkAsf2QaqHeeS_J9NpHpXtyDXcieio9vKv26kCGUmRHFPHCgzbBjrotHTOfZR1pLmJyzoIWF7GS6XCZ_3yauIkiN3XkvMo-t-bA?width=758&height=117&cropmode=none" width="758" height="117" alt="Posh-Git" class="alignnone" />

Indicando que branch estamos utilizando y los cambios que aún no se han sincronizado.

Happy scripting!