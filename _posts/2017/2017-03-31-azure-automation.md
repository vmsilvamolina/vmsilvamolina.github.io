---
title: Usando PowerShell con Azure Automation
date: 2017-03-31T17:44:18+00:00
author: Victor Silva
layout: post
permalink: /azure-automation/
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";N;s:10:"author_url";N;s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";N;s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:4:"none";s:3:"url";N;}'
dsq_thread_id:
  - "5684919649"
categories:
  - Azure
  - PowerShell
tags:
  - Azure Automation
  - PowerShell
  - Runbooks
---
## ¿Qué es Azure Automation?

Azure Automation permite automatizar tareas de administración en la nube que son realizadas con frecuencia (y que requieren demasiado tiempo), ya sean locales o en la nube. Esto genera un valor adicional ya que se enfoca el esfuerzo en agregar valor al servicio y no a realizar tareas monótonas.

Éstas tareas son ejecutadas por medio de flujos de trabajo con Windows PowerShell denominados **Runbooks**. Los Runbooks permiten controlar la creación, implementación, supervisión y el mantenimiento de los recursos en Azure y aplicaciones externas. También permiten controlar la ejecución de los mismos, dejando a disposición la posibilidad de ejecutar los Runbooks de forma programada.

A su vez, los Runbooks funcionan con Web Apps en el servicio Azure App Service, con maquinas virtuales, Azure Storage y Azure SQL Database, por nombrar algunos de los servicios de Azure. También se pueden utilizar con servicios externos de APIs públicos. Y por si todo lo anterior fuese poco, los Runbooks pueden integrarse con deploys de **_PowerShell DSC_**, por lo que las posibilidades se extienden de manera exponencial!

## ¿Qué pueden automatizar los runbooks?

Los Runbooks de Azure Automation se basan en Windows PowerShell o en el flujo de trabajo de PowerShell, o sea que hacen todo lo que puede hacer PowerShell básicamente. Si una aplicación o servicio tiene una API, un Runbook puede trabajar con ella. Si tiene un módulo de PowerShell para la aplicación, puede cargarlo en Azure Automation e incluir estos cmdlets en un Runbook. Los runbooks se ejecutan en Azure y pueden acceder a los recursos en la nube o los recursos externos a los que se puede acceder desde la nube. Con **Hybrid Runbook Worker**, los Runbooks pueden ejecutarse de forma local para poder administrar los recursos locales.

## Galería de Runbooks

Existe un repositorio de Runbooks generado por la comunidad que se encuentra disponible en la _Centro de scripts de Technet_, en el siguiente enlace: [Galería de Runbooks](https://gallery.technet.microsoft.com/scriptcenter/site/search?f%5B0%5D.Type=RootCategory&f%5B0%5D.Value=WindowsAzure&f%5B1%5D.Type=SubCategory&f%5B1%5D.Value=WindowsAzure_automation&f%5B1%5D.Text=Automation).

## Primer Runbook

Desde el portal de Azure, vamos a **New**, buscamos **_automation_**, luego seleccionamos **_Automation_** y **Create**:

<img src="https://bdferw-ch3302.files.1drv.com/y4m3nO3ra5LhdU5lWbM0473rZPaAqp6Xp5CKKa2msaLuVCISOBjsfuPUSDTrSpR7vixd4dpAZju80oMD2pH4CSiy6aQvjab5cZ1-bHpMbaeTn7h-xh2C1B1DFwoq4VbM0rBgiSkPLtKBP-bCjSYqVAuHnsEOBofIOL4s_JYpGVjZQxPFSu4KFk9nfejfDzM4DiCOsflgG5h7AQNcQN0R5rLgQ?width=1365&#038;height=636&#038;cropmode=none" width="1365" height="636" alt="Azure Automation" class="alignnone size-medium" />

Completamos los campos, con los valores que nos indican y seleccionamos **Create**, para este ejemplo utilicé:

<img src="https://bdfdrw-ch3302.files.1drv.com/y4mMfcqeVAf_5OfV813hVB-auXVMxxQ5uM5QdYggaphB9xioeB2_QGHjQCUkvD2Oem8v952OeGVzBGtcuFcoPfS0PA-oS9qRdYbq47fkQeneN2BJ8BLgXh_JkijlAON5RMzm5Qi0sF1x5F1GH3D0W2OAFaTVBWHgq_JSBO5G2DHGW0PVJ0t371LtvKzSzl4TU6G0Q5ekecXMyGpmte0oPqYRA?width=308&#038;height=592&#038;cropmode=none" width="308" height="592" alt="Azure Automation parameters" class="alignnone size-medium" />

Luego de haber creado la cuenta, vamos a ir a nuestros recurso y vamos a seleccionar la cuenta creada hace instantes. Posterior a acceder a la configuración de la cuenta de automatización, seleccionamos Runbooks para crear uno nuevo:

<img src="https://ctflrw-ch3302.files.1drv.com/y4mD5ZpruNWOv3SWg3f9WbG-ADG7TEFIfgF-F-UGkJDqSfcckt09J0VYZCvhvYx8KqFRtK3aYCRe6t6TzZEKzq_t_avX-qsGvOysSNWYQ9q4EyziWRO2D0v9qCAkB-gq2yDG9OXJdzBQExFWdsI4dyOh-ZoiafCPSLDFVHalTRXBYJCiFL8Rn3SDA5l9CvRfM4eIzrhEU1UvQXfJ2wh0aE-YQ?width=824&#038;height=484&#038;cropmode=none" width="824" height="484" alt="New runbook" class="alignnone size-medium" />

Para este primer ejemplo vamos a crear un Runbook muy simple. Básicamente lo que va a hacer al ejecutarse es imprimir como salida un "
Hola Mundo"
. Para llevar a cabo lo anterior, seleccionamos un nombre y marcamos el **_Runbook type_** como _PowerShell workflow_:

<img src="https://ctfkrw-ch3302.files.1drv.com/y4m_RuB9S53TZXVYoQDmobS-nGqH_LSE9pdDK_-rpV2uBuVqVTRzMsJmZSc6uoz816lLf2shYthoIiBQmSyXPUYx7dgpHyXuWcR-Bd57ljUz2jioRdCuO-ehD38B7n45aVS9Ry3zSVJ4QF7fdAk5h-EWJ5uPHbwfnbNOyYqCWXZ9bQCwGR6RvL_rXsRzLgEJrJqmbV3aLsMhRZEaK-6aH5Gdw?width=815&#038;height=639&#038;cropmode=none" width="815" height="639" alt="PowerShell workflow" class="alignnone size-medium" />

Posteriormente ingresamos el siguiente código, para que retorne el string definido:

{% highlight posh %}
workflow HelloWorld {
      Write-Output "Hello world!"
  }
{% endhighlight %}
    

Y con lo anterior, vamos a guardar nuestro Runbook y como último seleccionamos **Start** para iniciar la ejecución del mismo. Seleccionando el tile Output podemos observar lo devuelto por el script, el famoso "
Hola mundo"
:

<img src="https://ctfjrw-ch3302.files.1drv.com/y4mNJkoG4dYb_r4PiT9qfEuBXI_kjz-ffcf644mtmirpshXiyAWb7Q2igV-g5l5_bDWgHNjeff5QfNnN-uGhQBbcWvlS8FgIFFn99EvvMwd0ofz-hJ6Mtgroh0Nb0hVsZTqP5IREtPFCKqZNslPXXjmpCDYkL78Wp5anvBkN42sOXwestFocg79Oq7kfTtbYJqO5nElqfOOyiKl2M0egCsqVg?width=879&#038;height=540&#038;cropmode=none" width="879" height="540" alt="Runbook output" class="alignnone size-medium" />

Para la siguiente entrega vamos a ver como programar la ejecución, así como tareas más complejas con nuestros recursos en Azure.

Happy scripting!