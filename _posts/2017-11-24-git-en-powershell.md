---
title: Git en PowerShell
date: 2017-11-24T7:24:21+00:00
author: Victor Silva
layout: single
permalink: /git-en-powershell/
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

#### Git for Windows
Para descargar Git for Windows es necesario acceder al siguiente enlace: [Git for Windows](https://git-for-windows.github.io/) y seguir el asistente de instalación.

Luego de la instalación, vamos a ejecutar lo siguiente:

{% highlight posh %}
git config --global user.name 'nombre'
git config --global user.email 'email address'
{% endhighlight %}

Con lo anterior definimos el usuario y mail que vamos a utilizar en nuestros repositorios. En el caso de GitHub es necesario para poder hacer commits y que aparezca en la gráfica de contribuciones de nuestro perfil.

#### Posh-Git
En el caso de Posh-Git, debemos considerar que es un módulo de PowerShell, por lo que podemos descargarlo e instalarlo desde la gallery. Para ello vamos a ejecutar:

{% highlight posh %}
Install-Module -Name posh-git -Force
{% endhighlight %}

Saludos,