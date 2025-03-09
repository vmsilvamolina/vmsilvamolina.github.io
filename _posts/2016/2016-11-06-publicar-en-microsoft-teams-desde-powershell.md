---
title: Publicar en Microsoft Teams desde PowerShell
date: 2016-11-06T00:28:39+00:00
author: Victor Silva
layout: post
permalink: /publicar-en-microsoft-teams-desde-powershell/
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";s:68:"https://cdn-images-1.medium.com/fit/c/200/200/0*Sz3Js055VwE6KyPu.jpg";s:10:"author_url";s:33:"https://medium.com/@vmsilvamolina";s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";s:12:"ec65b99f1e1f";s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:6:"public";s:3:"url";s:91:"https://medium.com/@vmsilvamolina/publicar-en-microsoft-teams-desde-powershell-ec65b99f1e1f";}'
dsq_thread_id:
  - "5308970048"
categories:
  - Office 365
  - PowerShell
tags:
  - JSON
  - Microsoft Teams
  - PowerShell
---
Por qué quisiéramos nosotros publicar en Microsoft Teams desde PowerShell? Existen muchas respuestas a esa pregunta, pero la que primero se me viene a la mente es que la idea que impulsa el desarrollo de Microsoft Teams es la colaboración dinámica entre integrantes de un equipo (o varios) por lo que es necesario contar con información de sucesos o situaciones en tiempo real, en tiempos en donde el mail se encuentra un poco desfasado al dinamismo actual.

Los que no conocen Microsoft Teams, les recomiendo que revisen [éste enlace](https://blogs.office.com/2016/11/02/introducing-microsoft-teams-the-chat-based-workspace-in-office-365/).

Ahora bien, por qué PowerShell? Porque es lo que a mí más me gusta! Aunque en realidad no se limita solo a PowerShell lo que vamos a ver, si no que en realidad tenemos la opción de elegir nuestro lenguaje de scripting favorito ya que las notificaciones que vamos a generar son creadas por medio de JSON, utilizando el conector **Incoming Webhook**. En adición a lo anterior, existe una extensa lista de conectores disponibles para poder utilizar dentro de Microsoft Teams, entre ellos Trello, Twitter, Github y Wunderlist.

## Crear el conector

Primero debemos crear el conector en nuestro canal, por lo que debemos ingresar a [teams.microsoft.com](http://teams.microsoft.com) y posteriormente acceder al canal de nuestro Team y seleccionar Connectors como indica la imagen:

<img src="https://qv4tsa-ch3302.files.1drv.com/y4mKqxzjj1qhWFGVKCtTKIrfWj5B_nHhLvwq2IaEJ2RbnW_jAfhJRqghgmYP0UgFO3CnkBFpIlEdVotZKsxaTPFppXjcrFaX88IezxJcesj7N0Cj9DuuD7Y-rSdUZHZOHhyD-BgsFT4qA8Y88cSfEiQbjbSPvwCHg5ZFrw32kJNvq_DgRFwfR31QmVDt70zWAhuAHN1MRm-Jemb19elu9j0wA?width=988&#038;height=589&#038;cropmode=none" width="988" height="589" alt="Microsoft Teams" class="alignnone size-medium" />

Ahora debemos agregar el conector Incoming Webhook, por lo que vamos a buscarlo dentro de la lista que nos aparece y vamos a agregarlo con el botón **Add** a nuestro team llamado _Equipo Rocket_ dentro del canal _PowerShell Notifications_:

<img src="https://qv4ssa-ch3302.files.1drv.com/y4mehj7nu7tIZ1d0WouaZvqb-TyAPutW9NQk-AsaKMUSCyJ-vSnfxdA39GBRkJeZriKEKZPJMOF3p-qxHOcHiG8ZlLi9U2W0iWbRM4JqUPdtpJNGxkR8d5NKGyztVdvjukb1rAVNNc68YfMoaXjZNPGsCXh_qK6YdX7IFMjRbpI8Wm5f-CgB5Ev4xLZpoV1u4RaumkPUincIQJE7oWeZeVMaA?width=988&#038;height=589&#038;cropmode=none" width="988" height="589" alt="Incoming Webhook" class="alignnone size-medium" />

Al agregar el conector tenemos dos opciones disponibles. La primera es asignarle un nombre que identifique el conector.

<img src="https://qv4rsa-ch3302.files.1drv.com/y4mARRa19Y1xfUAEgcRCwtOzFj1WefyRytvOvOJElEG-ea2ZwxQbedgBTX0jeOx0K4Op8B8hel2eNr8snuS_JGkJL4e-sKFMZuI8hE81nu16iGAEgUcMjVWDrGdwmzhiFhcnKFFUYmFlvi1XSqTdj0CZq-4dozwlhHSCEW1HQFpet2R7PuZT_sjGKfhAfGMhm7c4ZURZxD2fPAn4t0RLGA6oQ?width=825&#038;height=421&#038;cropmode=none" width="825" height="421" alt="Incoming Webhook" class="alignnone size-medium" />

La segunda opción (no es requerida) es la posibilidad de cambiarle el ícono que se va a utilizar al momento de publicar sobre el canal. Simplemente hacemos un upload de la imagen que nos gustaría utilizar, para el ejemplo utilicé el logo de PowerShell.

<img src="https://qv4qsa-ch3302.files.1drv.com/y4mbWh0wB0-dBJGZvKQdompVlTCEN06cqYhLQ-fQhhTR03johOePGwPpBxz5-sWoq1Al3XY11pz4DFsXkRfYriLurz3LCcskLFimzQ4HkD176uF9Y96JFIXL9JGnh2D01TmYGCwrQcwYNVeY1Ir5qTDKUv-Hu_MPVC09z826HZKOTpA9IMiNi7egZfFF8ab3EAuo1acPkU5-PTvryBeX4YgBg?width=828&#038;height=419&#038;cropmode=none" width="828" height="419" alt="Incoming Webhook" class="alignnone size-medium" />

Al crearlo nos aparecerá una URL necesaria para poder utilizar el servicio. Ahora que tenemos todo listo en Microsoft Teams, vamos a ir a una consola de PowerShell para finalmente comenzar a utilizar este servicio.

<img src="https://qv4psa-ch3302.files.1drv.com/y4m9uUKz2eIy5ESgqM_NVY-zbDO94oh8BwdO_rUj4xNad7DL_zPD2_hnXPnEhpWqV06q9_zgO7lxCz6dbFruOfC7nCslHST3o8oqFQ-1pbMflTRwHoi_74UaSvxRPQ4vXsPmCodhNSBxEOfjTW2kJLc733tw59p9zhlaRQPTqhi463mHZHp9e4cyckeEh_KzBSaNFAG3EeCRh8Rx7uTOZmYyQ?width=827&#038;height=529&#038;cropmode=none" width="827" height="529" alt="URL del para utilizar el conector" class="alignnone size-medium" />

## Publicar en Microsoft Teams desde PowerShell

Para crear nuestra primera publicación, el procedimiento se reduce a la siguientes líneas:

    # Información necesaria
    $uri = "https://outlook.office365.com/webhook/..." #URL completa
    # Mensaje a publicar
    $body = ConvertTo-JSON @{
        text = 'Hello Channel'
    }
    #Publicamos el mensaje
    Invoke-RestMethod -uri $uri -Method Post -body $body -ContentType 'application/json'
    

Lo que vamos a obtener como resultado es un mensaje del tipo **_Hola Mundo!_** pero adaptado a Microsoft Teams 😉

<img src="https://qv4osa-ch3302.files.1drv.com/y4mEW1Gh40X2mDUzNRpUCkxdGn05nxZ73V3fuyL4tAhDWXq4Ydtvb5jlzxB5Bd57spH-Dwxy4Y46aKnDK9YOqMgYH53EupQ_A37m09Bfx3HtwkjgQzTmfd-tWT-mL0bOOVxkMw6f5UVji-K5GchLbQVAqNPO22YgXsMsgpeJWBn9b1rOGtHCTKYNMZBh92W6bAR2WRgC_G3IOldc4Gcmq9w0Q?width=863&#038;height=108&#038;cropmode=none" width="863" height="108" alt="Publicar en Microsoft Teams desde PowerShell" class="alignnone size-medium" />

En conclusión, vemos que no es para nada difícil poder integrarnos desde PowerShell a Microsoft Teams y especialmente, publicar en Microsoft Teams ya sea para alertar de ciertas situaciones como para generar avisos o eventos programados hacia nuestro canal.

Happy scripting!