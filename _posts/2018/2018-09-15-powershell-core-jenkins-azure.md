---
title: "PowerShell Core y Jenkins en Azure"
date: 2018-09-15T18:57:00+00:00
author: Victor Silva
layout: post
permalink: /powershell-core-jenkins-azure/
excerpt: "Automatizar tareas aburridas es una de las cosas más divertidas para los que amamos el scripting, pero que sucede si nos detenemos a pensar en la cantidad de scripts de PowerShell que hemos escrito para uso personal o del equipo. Módulos y/o funciones que ayudar a automatizar o solucionar problemas de forma más sencilla. A pesar del esfuerzo que lleva realizar este tipo de tareas, la mayoría de las veces se terminan olvidando o dejando de lado."
categories:
  - PowerShell
  - Azure
  - DevOps
tags:
  - PowerShell
  - PowerShell Core
  - Azure
  - Jenkins
  - Scripting
  - Automatización
  - DevOps
---

Automatizar tareas aburridas es una de las cosas más divertidas para los que amamos el scripting, pero... ¿qué sucede si nos detenemos a pensar en la cantidad de scripts de PowerShell que hemos escrito para uso personal o del equipo? Módulos y/o funciones que ayudar a automatizar o solucionar problemas de forma más sencilla son olvidados y/o dejados de lado a pesar del esfuerzo que lleva realizar este tipo de tareas.

<div>
:loudspeaker: ¿Te gustaría enterarte cuando se publique un nuevo post? <a href="https://twitter.com/vmsilvamolina">Follow me on Twitter: @vmsilvamolina</a> :loudspeaker:
</div>{: .notice}

De ésto último, se suman también los problemas al intentar otorgar a los usuarios finales permisos para utilizar estos recursos cuando no son administradores. Existen varias maneras de resolver el problema: utilizar Just Enough Administration, dar acceso remoto a un servidor con una sesión de PowerShell, habilitar PowerShell Web Access... pero la idea es simplificar las tareas, no complejizarlas.

Para ello es que podemos utilizar **Jenkins**.

### ¿Qué es Jenkins?

Jenkins es tradicionalmente utilizado por desarrolladores como una herramienta de integración y continuous integration, que proporciona una interfaz web para crear y ejecutar trabajos manuales y programados. El siguiente video (en inglés) brinda una breve introducción a Jenkins en Linux, para darle una idea de lo que puede hacer.

{% include video id="OfptBK8AB_c" provider="youtube" %}


### Jenkins junto a PowerShell en Azure

Jenkins se puede utilizar para hacer muchas cosas dentro del equipo de operaciones, pero la idea de este post es concentrarnos en aprovechar PowerShell para realizar acciones desde el servidor de Jenkins.

Cualquier cosa que sea posible realizar con PowerShell, puede integrarse con Jenkins para proporcionar una interfaz fácil de usar, brindando un espacio para programar y ejecutar trabajos.

¿Y Azure? Azure ofrece desde el marketplace la opción de desplegar una VM con todo listo para comenzar a trabajar, incluyendo la posibilidad de extender la administración y gestión de los recursos de nube.

<img src="https://hqyb9g.ch.files.1drv.com/y4miGxMZantg6sWfL3Qc3a4amDyhpkOvpR3i9Ii-JUaQ1WxBsBlU0dRV5wZAYMuhixeL7T4EcGSOSi1fPSfsOIwxFjXI6M3pSPv0uy8xVf_haWJRn13NCkwZxnGPOwWM_qekpxkMpeOUr3KFbdD6MsUmdvGjlO9GxB-PCpV2OG-k8jYjmJf4y4Lt0gSUjTy5xq2FYGhn_19ERQwm_9Cvt7nWw?width=585&height=568&cropmode=none" width="585" height="568" alt="Jenkins" class="alignnone" />

### Desplegar Jenkins en Azure

Al ser este blog ferviente admirador de PowerShell y tomando en cuenta que estamos trabajando con Azure, el despliegue de la VM con Jenkins se realizará desde Azure Cloud Shell con PowerShell.

Para ello, es necesario acceder a [https://shell.azure.com](https://shell.azure.com) y seleccionar la experiencia anteriormente comentada (PowerShell):

<img src="https://jfpgiw.ch.files.1drv.com/y4mFxU-7kRjvk7PMU1jJc--DMZUcXA4d3KiGx-WeOjsUU-QxVDZeglMg9VVXjHRaY0rQxS1Ef4PwCfEhyGYy7bUBRfXRpq60oMPk03DhfgMDz55lZAU8PABCJBZL47h7lA200XiVgqo_12MNTKIAN6Jq1uvqpdP1jg5VblF-dFqE-u1pqrM6KyTS_ffpapjli--zvMYl5rKl6z-mEoyoCLitQ?width=933&height=455&cropmode=none" width="933" height="455" alt="Azure Cloud Shell" class="alignnone" />

El primer paso, luego de ingresar a la consola, es movernos a nuestro **$home**, con el siguiente comando:

{% highlight posh%}
  cd ~
{% endhighlight %}

Ubicados correctamente vamos a obtener el template ARM para desplegar la máquina virtual con Jenkins, ejecutando el comando a continuación:

{% highlight posh%}
  wget https://raw.githubusercontent.com/vmsilvamolina/ARMtemplates/master/jenkins.json
{% endhighlight %}

Como resultado de la ejecución anterior vamos a tener en nuestro directorio actual el archivo **jenkins.json**, obtenido de un repositorio en el que alojo *ARM templates* de ejemplo.

Ahora que ya tenemos el archivo, se deberá ejecutar lo siguiente para continuar con el procedimiento:

{% highlight posh%}
  cat ./.ssh/id_rsa.pub
{% endhighlight %}

Copiamos el resultado del comando, que no es más que nuestra clave pública para poder conectarnos a la VM con Jenkins de forma segura y simple (por medio de SSH). En caso de no contar con una clave pública, es requerido ejecutar `ssh-keygen -t rsa -b 2048`.

El siguiente paso es modificar el archivo descargado (jenkins.json), en donde vamos a agregar el valor de nuestra clave pública dentro del template ARM, como se muestra en el siguiente extracto:

{% highlight json%}
  "adminSSHPublicKey": {
    "metadata": {
        "description": "Public SSH key for the Virtual Machine. Will be used only if authenticationType is 'sshPublicKey'"
    },
    "defaultValue": "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABA...1N",
    "type": "string"
  }
{% endhighlight %}

Ya con el archivo modificado, el siguiente paso es generar el grupo de recurso que alojará todos los componentes del despliegue y luego generar el deploy del template modificado:

{% highlight posh%}
  az group create -n Jenkins -l eastus
  az group deployment create -n deploy -g Jenkins --template-file ./jenkins.json
{% endhighlight %}

<img src="https://hdfisw.ch.files.1drv.com/y4mRHV_fUDQjmMWhvoFLn5nMJu6XSkOGV0_-LGq16Fg5xuytYWs4DrhnzjFHBB5UzfZFRulTwruFQmVrF2Fgaj_0-Od6lMAL9FBMvvnwdOGeA87JdKn0LALve_LtW1xneO3JajsSzMezfoCW7Wu4j7L--cV32tAQZUkJgdawPV_FRZ9UBzo_S1fZWf6wtghi4zWYeSbl7F5yD3WxYZer8HX1A?width=877&height=688&cropmode=none" width="877" height="688" alt="Deploy Jenkins with ARM, az CLI and Azure Cloud Shell " class="alignnone" />

### Configuración inicial de Jenkins

Ya desplegada la VM con Jenkins en ejecución, se recomienda realizar algunos pasos para dejar operativa nuestra solución sin obviar la parte de seguridad.

Para ello tenemos los siguientes pasos a realizar, detallados en la siguiente entrada:

[https://jenkins.io/blog/2017/04/20/secure-jenkins-on-azure/](https://jenkins.io/blog/2017/04/20/secure-jenkins-on-azure/)

Esta entrada no tiene como objetivo cubrir estos pasos inicialmente, por lo que se deja el enlace como referencia para implementaciones en producción.

Lo siguiente que debemos hacer intentar conectarnos utilizando la URL (que obtenemos desde la configuración de la VM):

<img src="https://wwd2vg.ch.files.1drv.com/y4mwHYZOB6yrX0n0b6wz3WmoLeUH09DImQrsRza_DmSKBncIrdG5KQvxtaLcVjoyE_EWF7l_IGFEbAoCTq_FyeR_31y4UsrowJvR1k3geEG1IDNZmUlSRI0XmUCNnXI6lcg-kTPvYmVOAFVnL2xh297jvPc3zIjVYCFh9MX2yrjUBalOv8xeJuMdv9AyVY6iHCWWQ9vLFaA515J33Ut5AX_gg?width=802&height=633&cropmode=none" width="" height="" alt="" class="alignnone" />

Entonces, para poder acceder a la instancia desde el navegador, tenemos que habilitar el puerto 8080 en el NSG (Network Security Group) en Azure. Para ello ejecutamos lo siguiente en nuestra Azure Cloud Shell:

{% highlight posh%}
  az vm open-port -n vm-jenkins -g Jenkins --port 8080
{% endhighlight %}

Y ahora sí, podemos navegar en la siguiente URL: `vm-jenkins.eastus.cloudapp.azure.com:8080`.

Seguido de lo anterior (y notificados por la web), debemos ingresar la contraseña temporal guardada en la ruta que se muestra en la web. Simplemente ingresamos por ssh a lo siguiente:

{% highlight bash%}
  ssh -L 127.0.0.1:8080:localhost:8080 jenkinsadmin@vm-jenkins.eastus.cloudapp.azure.com
{% endhighlight %}

Obtenemos la contraseña ejecutando:

{% highlight bash%}
  sudo cat /var/lib/jenkins/secrets/initialAdminPassword
{% endhighlight %}

Copiamos la contraseña y la ingresamos seleccionando Continue:

<img src="https://lppogw.ch.files.1drv.com/y4mdRmzExtZk0zh9ggHQsGUVwMOAqN4ANMqvLLmV08SpGmihhX6FXW-nxZ5_UsD6gkgOXG96CQwotSTnVl27dRA_3EWn5UDYp1nC1yk2RAWgWNeHvt0PUPF0YQLrutfmic04MVbBpeUvdnZesbDCAmyhbK-ByolLxCBkW_nkxEnqS1mjt9ZoH_rWYIxUXi68Ws3ylPV6q-ZMnjGn7ozduqTjQ?width=807&height=694&cropmode=none" width="807" height="694" alt="Unlock Jenkins" class="alignnone" />

Continuando con el proceso de configuración de Jenkins, seleccionamos la opción "Install suggested plugins":

<img src="https://x2d2vg.ch.files.1drv.com/y4mNGWsdaDLM5z0TGsBI531Njt1hPcLb8l9Se7hiwyz8DUdCUq3SARRw201iFa9OqCFbTIHRgvjxBfmPtOyssMnLM-0MjaxnNkQy854znZb358XYb17twvpR8AqeLg6W0jx9ff-vgvqAsRKXy6-RoZNUeSAifie66TywyqstySftFKjjhrtnQawamXe8QOlskFgputPsmzG49MU47Iua1hOEg?width=807&height=694&cropmode=none" width="807" height="694" alt="Install suggested plugins" class="alignnone" />

A partir de este momento, se comienza a desarrollar la instalación y puesta en marcha de Jenkins, junto con el deploy de los plugins por defecto:

<img src="https://9gma1g.ch.files.1drv.com/y4mRyU9JvK7mbSAQIDRio1LOmVXcDnQhvOYxthf83Jc-0WU5koz_zT3sfTk5eao3qGoIXxWyAIkBAVz36_i26sHh2IkXLHRAKBpR8cR2d05dfcPmWkxgMIAWXRYAUcvzeGDGT2Kxh29bGZDR4jFS4Yy8hw-HoYOHVkPh7X0Wu5Wj0e9eLkUYOm07c2sIxV4XT307qpPqW4lNwPtUTTcOqOlNA?width=807&height=694&cropmode=none" width="807" height="694" alt="Jenkins update progress" class="alignnone" />

Luego de finalizado este proceso, es requerido generar un usuario admin. Para ello se debe completar el formulario:

<img src="https://kx4neq.ch.files.1drv.com/y4mn8FJKxp6idr-NwNPV8eDZXJUuj3TpqnTr0v9VIK-hPNrEgVyVlDdqbleTFGQXH80BNS2mKgTqpe8h_leYUDDV4qxLWK4iMFDkeZzguaxaoQtkx0X8ykDTYNHQpyQnf0KlDZ-B7sRJBaSP0gPr8BVBNTV58wyOGn-cG40-uwmxjyGgPlg6OveYg2iQ1PPpKuNLqF4zm9gmtm8Q8beJJMhjw?width=815&height=694&cropmode=none" width="815" height="694" alt="Create first admin user" class="alignnone" />

Seleccionar **Save and Continue** para comenzar a utilizar Jenkins.

### Instalación de PowerShell Core

Ya con la solución desplegada en Azure, junto a la configuración básica de la misma, resta ejecutar la instalación PowerShell Core.

Para completar esta tarea, lo primero que debemos realizar es conectarnos por SSH a nuestra VM en Azure:

{% highlight posh%}
  ssh jenkinsadmin@vm-jenkins.eastus.cloudapp.azure.com
{% endhighlight %}

Y luego ejecutar los siguientes comandos:

{% highlight posh%}
  # Descargar las claves del repositorio
  wget -q https://packages.microsoft.com/config/ubuntu/16.04/packages-microsoft-prod.deb

  # Registrar Register the Microsoft repository GPG keys
  sudo dpkg -i packages-microsoft-prod.deb

  # Update de la
  sudo apt-get update

  # Instalar PowerShell
  sudo apt-get install -y powershell

  # Comprobar instalación de PowerShell
  pwsh

{% endhighlight %}

<img src="https://x5xwmw.ch.files.1drv.com/y4m0KatxszmPKkYviM6L-eakq8c4sS5vt0X-SF9UBwQ1iGlsVYRYh31bfq2FNdxZ3NEMysFxSEF9VHUwtPQiBCIbcYDb07IlJFcAIqUew5zaf3aQoKwyPIxZmXZfFY3zT6lKWvBZ9sx4BgIWio8xhbGY4QXeVFKGfWgrEKwJ4wV9WpKV1izP_yV-5f0NK0wnm7l3A8l8C6H2yebyN4NOykZ5g?width=802&height=665&cropmode=none" width="802" height="665" alt="Instalación de PowerShell Core" class="alignnone" />

### Creando un job en Jenkins

Se va a definir para el ejemplo un script muy simple donde vamos a tener como resultado la salida de los 10 procesos con mayor consumo de CPU. Ésto lo vamos a generar por medio de un job en Jenkins, que luego vamos a ejecutar.

Para generar un job en Jenkins, luego de tener toda la infraestructura a disposición, es necesario realizar lo siguiente:

* Desde la interfaz web, click en **Nueva tarea**.
* En el campo "*Enter an item name*" ingresar el nombre del job. Para el ejemplo se usó **Procesos con más consumo**.
* Seleccionar **Crear un proyecto de estilo libre** y click en **OK**.

<img src="https://mppmgw.ch.files.1drv.com/y4mDmByeuJApSoo0puTD7Zq_-dAqRAwI4Yy8g9TU6xRo5gvveMtsTqfb2PIFsB5YJyzbzOqkuGynyeUAdPIUqdsdX3Pgm7SCyAd5fsiIGsC-VMw8ooOXpFxP9OW23HtN0ddcORMw2tfV1AFXrKyDHuqvGWn-eb5ash9Url9vNiogApD3sY98ZbgQyYjNDLZaMlCl-SLY1YBdfVio8RsrXkZ1A?width=986&height=697&cropmode=none" width="986" height="697" alt="Crear job en Jenkins" class="alignnone" />

* Navegar hasta el final de las opciones y en *Ejecutar* seleccionar Añadir un nuevo paso, de la lista desplegable seleccionar **Ejecutar línea de comandos (shell)**.
* Dentro del campo de texto, vamos a ingresar el siguiente script:

{% highlight posh%}
  pwsh -c "&{Get-Process | Sort-Object CPU -Descending | select -First 10}"
{% endhighlight %}

<img src="https://y2d0vg.ch.files.1drv.com/y4maEAvArJz_XCNjqoHf1o_tOJsaV3Tz-UgdlC7NDFXtD2LOlPuFDJQAxJUpl-JWjiPAbHWQhOtMy5hXddsCDj3SRoQ04hWvW5mLWTjAqPKjySbIcd2aLveQoD35-91At5S8j3IGF9FCJMhJuRzO1Q4si8ens-gKrunUORWCX7Uj4qx9lnBmgVEXqBOGQWBfWhoJC774R5EDlal7LO2H2x3iQ?width=986&height=697&cropmode=none" width="986" height="697" alt="Agregar comando shell en Jenkins" class="alignnone" />

Y luego click en **Guardar**.

### Ejecutar un job

Luego de todo lo configurado estamos en condiciones de ejecutar el job que acabamos de crear. Para ello hay que regresar al *Panel de Control* de Jenkins y desde ahí seleccionar el job *Procesos con más consumo*.
 
Por último seleccionar el botón **Construir ahora**.

Listo! Ya iniciamos la ejecución de nuestro trabajo.

Para poder ver el resultado, seleccionamos **Console Output** y vamos a poder observar la lista de los 10 procesos con mayor consumo de CPU.

<img src="https://pglp1g.ch.files.1drv.com/y4m2aw7bS4mP8f6EMl2Df2RRHrpn9zgGykoKHfV7HFXV5r-UoyLS5tsuuXf5A5upppYl3WxvyKh7enA-DtDcVfvDWDmx4XtqySnFnDWOW9EIbcDj2la4hiK4kRrEoiOJBiNgpXXOC0DGu6btf_3GNjMbckggxYAmfYblV78pS0nVVxfr9vDb9-ZwadmaG2gluAURMzuukTxxCk9pQ1vdiX66w?width=986&height=697&cropmode=none" width="986" height="697" alt="Salida del job en Jenkins" class="alignnone" />

La imagen anterior es el punto final, donde pudimos ejecutar un trabajo en Jenkins con PowerShell Core. Las posibilidades son infinitas sobre tareas a realizar y gestionar por medio de estas 2 grandes herramientas, sin contar que también existe la posibilidad de trabajar con Azure directamente.

¿Más información sobre Jenkins? [https://jenkins.io/](https://jenkins.io/)

En próximas entradas veremos como seguir profundizando en esta gran solución.

Happy scripting!
