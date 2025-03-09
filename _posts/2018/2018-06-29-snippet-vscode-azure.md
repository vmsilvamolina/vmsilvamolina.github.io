---
title: Crear un Snippet en VSCode para Azure
date: 2018-06-29T18:57:00+00:00
author: Victor Silva
layout: post
permalink: /snippets-vscode-azure/
excerpt: "Hace un tiempo que vengo utilizando Visual Studio Code y la verdad es, que cada día que pasa, le voy tomando más cariño. Es ágil, tiene una interfaz muy cuidada, está repleto de extensiones (a nivel de lenguajes o tecnologías) y es super customizable. En referencia a esto último es que he decidido armar esta entrada en el blog."
categories:
  - Azure
  - PowerShell
tags:
  - Azure
  - PowerShell
  - Infrastructure as Code
  - Azure Cloud Shell
  - Scripting
  - Visual Studio Code
  - Snippets
---

Hace un tiempo que vengo utilizando **Visual Studio Code** y la verdad es, que cada día que pasa, le voy tomando más cariño. Es ágil, tiene una interfaz muy cuidada, está repleto de extensiones (a nivel de lenguajes o tecnologías) y es super customizable. En referencia a esto último es que he decidido armar esta entrada en el blog.

A diario utilizo PowerShell para realizar mis tareas, sin importar que es lo que tenga que hacer. Últimamente estoy trabajando bastante con Azure y hay veces que, al utilizar PowerShell en vez de Azure CLI, completar algunas tareas se torna más extenso en el tiempo a la hora ejecutar comandos para tal fin. Por ello se me ocurrió indagar sobre el tema Snippets en VSCode para intentar ser más eficiente al momento de escribir scripts en PowerShell.

### ¿Qué es un Snippet?

Los Code snippets son templates que facilitan la tarea de escribir patrones de código repetitivos, como sentencias condicionales o loops.

Snippets aparecen en **IntelliSense (Ctrl+Space)** mezclados con otras sugerencias, así como también es posible acceder a ellos mediante un selector dedicado dentro de la Command Palette (*Insert Snippet*). Adicional a lo anterior es posible utilizar el soporte de la funcionalidad *tab-completion*; que básicamente permite al escribir el prefijo del Snippet y, al pulsar la tecla Tab, inserta el Snippet en el código.

### Procedimiento

Lo primero que tenemos que tener en cuenta es que para escribir nuestro primer script basta realizar un procedimiento muy simple, que paso a detallar:

Dentro de Visual Studio Code, acceder al menú **File** y luego seleccionar **Preferences**, para seleccionar del nuevo menú la opción **User Snippets**.

Seleccionar la opción **New Global Snippets file...**

<img src="https://pqqn7q.ch.files.1drv.com/y4mjtCLXQcUlT5t62XXr1xIUcKNVZaNvKnNBS2nGw8AO8FeG0XIPH34FIGirZRPQw5bd7c_c8CkDUGTTVPv6OCrMEtzayU36QK7bwQJoV1_tQeq9rNP5luBas6lU2YgGy6srD8s-H6iSrAMenTRSAV8ZRb-rWGic7-0Hv7qEz6VVOf5D0TIOAV-1J8s_6HrgYXmsoey_FWmrTm0AttpvPY-MA?width=603&height=285&cropmode=none" width="603" height="285" alt="" class="alignnone" />

Luego de seleccionar la opción se despliega una ventana en la que se debe definir el archivo donde vamos a registrar nuestro código. La ruta donde se alojan los Snippets del usuario es:

> ~\AppData\Roaming\Code\User\snippets

<img src="https://czbmsg.ch.files.1drv.com/y4mKvDjhUcdPScN61twS_ELcnxUjORN1hOBYCNG2IiAR_ukjyo6nor9a8FD8vQ4VpJ0TVKltnIT9ucwI5CRdal9Albbm-GT1wbL7MbIjZhIdBv7vMD4793OPuz4vS1yhg4MQvnWfjXWluLZRvHOsKF5wW_eGYYl66g8ds4zr1dCmUgv6dfGOCRKiDWhXa0GOhrInrfAKR2_yprYsIvgo9bjxQ?width=669&height=473&cropmode=none" width="669" height="473" alt="" class="alignnone" />

Ya con el archivo creado, vamos a encontrarnos con el siguiente panorama en Visual Studio Code:

<img src="https://fkqkag.ch.files.1drv.com/y4mh3OcR-j7WmNidHo-ggb5gK6H01ns2dQM3KF3vfGZBRoShqLtZo-rSNxcGMGIBVkmPvZjeFBnWJjF_eB4NyB2EaYWZtn5DrzKTRlUqiz0vHSphGqTHx_NoAf99UmjJUYb7spBsoRSS7-gha_WkLlcneymmu3mmiKTiD9vdr27Av9mHYGSRaZ95CvNdOz95NUPPWnAqHoSKjdlXpwfpuT30w?width=888&height=721&cropmode=none" width="888" height="721" alt="" class="alignnone" />

### Primer Snippet

Ahora que tenemos lo requerido, vamos a comenzar a definir nuestro primer Snippet. Antes, quiero definir la estructura del mismo con lo siguiente:

{% highlight json%}
  {
    "Write host": {
      "prefix": "print",
      "body": "Write-Host \"${1:Hola mundo!}\"",
      "description": "Write-Host Snippet"
    },
  }
{% endhighlight %}

Tomando ejemplo anterior tenemos los siguientes puntos:

* `Write host` es el nombre del snippet.
* `prefix` define como el snippet es seleccionado desde IntelliSense, así como para insertarlo usando la tecla Tab. Para este ejemplo es *print*.
* `body` es el contenido donde según sea un simple string o varios, se considerarán como diferentes líneas de código.
* `description` es la descripción que aparece como información en IntelliSense.

Ahora que tenemos clara la estructura, vamos a tomar una tarea de Azure donde podamos simplificar la generación de código y ser más eficientes a la hora de escribir código.

La tarea en cuestión es crear una VM, donde usamos al menos 2 comandos para aprovisionar la misma: generar el grupo de recursos y desplegar la VM. Si bien es cierto que se puede simplificar la idea es tomar un ejemplo para poder tener una referencia en cómo resolver cierta situación.

El siguiente Snippet resuelve mi tarea de una forma muy simple:

{% highlight json%}
  {
    "New VM": {
      "prefix": "newvm",
      "body": [
        "#New Azure Resource Group",
        "New-AzureRmResourceGroup -ResourceGroupName \"${1:ResourceGroup}\" -Location \"${2:EastUS}\"",
        
        "#New VM",
        "New-AzureRmVm `",
        "\t-ResourceGroupName \"${1:ResourceGroup}\" `",
        "\t-Name \"${3:VM}\" `",
        "\t-Location \"${2:EastUS}\" `",
        "\t-VirtualNetworkName \"${4:vNET}\" `",
        "\t-SubnetName \"${5:Subnet}\" `",
        "\t-SecurityGroupName \"${6:NetworkSecurityGroup}\" `",
        "\t-PublicIpAddressName \"${7:PublicIpAddress}\" `",
        "\t-Credential ${8:$cred}",
      ],
      "description": "Crear una VM en Azure"
    }
  }
{% endhighlight %}

Como se puede observar, otra cosa que nos permiten los Snippets es utilizar **placeholders** como por ejemplo `${1:ResourceGroup}`, en donde se definen ciertos valores inicialmente que pueden ser modificados luego de ser insertado el Snippet. Adicional a lo anterior es posible navegar entre ellos, tomando el orden definido en el código, utilizando la tecla Tab.

Happy scripting!
