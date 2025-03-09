--- 
title: "Azure DevOps: Environment variables" 
author: Victor Silva
date: 2019-01-15T19:57:00+00:00 
layout: post 
permalink: /azure-devops-env-variables/ 
excerpt: "Azure DevOps es la solución que ofrece Microsoft, siendo la sucesora a VSTS (Visual Studio Team Services), que permite abarcar la totalidad del ciclo de vida del desarrollo para ayudar a ofrecer software más rápido y de mejor calidad. Según palabras del propio Microsoft, Azure DevOps Services representan la oferta más completa que existe en la nube pública." 
categories: 
  - Azure
  - DevOps
  - PowerShell
tags: 
  - Azure DevOps
  - Pipelines
  - Variables
  - DevOps
  - PowerShell
--- 

Azure DevOps es la solución que ofrece Microsoft, siendo la sucesora a VSTS (Visual Studio Team Services), que permite abarcar la totalidad del ciclo de vida del desarrollo para ayudar a ofrecer software más rápido y de mejor calidad. Según palabras del propio Microsoft, Azure DevOps Services representan la oferta más completa que existe en la nube pública.

Adicional a los servicios de nube, Microsoft también ofrece Azure DevOps Server (sucesor de Team Fundation Server), como apuesta a la unificación de las herramientas y experiencias para el desarrollo e implementación de soluciones.

La plataforma Azure DevOps cuenta con los siguientes servicios:

 - **Azure Pipelines**: Servicios de CI/CD para crear, compilar, probar y desplegar proyectos con cualquier plataforma o nube, así como conectar repositorios de GitHub, Bitbucket (o cualquier otro repositorio de Git).
 - **Azure Agents**: Agentes disponibles para Windows, Linux y macOS (de forma incorporada), con workflows habilitados con soporte de contenedores y opciones de implementación para entornos Azure, AWS, Service Fabric, Kubernetes, VMs entre otros.
 - **Azure Boards**: Realizar el seguimiento del trabajo del equipo del proyecto con paneles Kanban, backlog del equipo, informes, seguimiento, etc.
 - **Azure Artifacts**: Soporte de paquetes NuGet, Maven y NPM (fuentes públicas y privadas).
 - **Azure Repos**: Repositorios públicos y privados de Git alojados en Azure.
 - **Azure TestPlans**: Gestionar planes para pruebas manuales, planificadas y exploratorias.

Comparto una entrada en el blog de Microsoft donde hablan de Azure DevOps:
[https://azure.microsoft.com/es-es/blog/introducing-azure-devops/](https://azure.microsoft.com/es-es/blog/introducing-azure-devops/)

## ¿Azure Pipelines?
Antes de revisar en profundidad lo que el título de la publicación indica, podemos expresar primeramente que un pipeline es conceptualmente una forma automatizada de disponibilizar nuevas features de una aplicación a los usuarios finales (o usuarios de pruebas también). Los pipelines, también conocidos como CI/CD (Continuous Integration y Continuous delivery) definen el proceso en que el programador actualiza el código en el repositorio y de forma automática se inician una serie de pasos configurados donde transcurren ciertas tareas como tests unitarios hasta la distribución de los cambios en los diferentes ambientes.

### Environment variables

Las variables de entorno o **environment variables** son valores que afectan (o condicionan) los procesos y el comportamiento de la ejecución de sistemas y entornos operativos. Así tenemos que en Azure DevOps todas las varibles declaradas en Azure Pipelines son ejecutadas como variables de entorno en los agentes y, por si fuera poco, todas las variables en los agentes pueden ser accesibles como simples variables en el pipeline.

## Variables dentro de Azure Pipelines

Ahora que tenemos la base teórica vamos a ver un ejemplo práctico, para ello vamos a crear un pipeline simple utilizando el siguiente archivo **.yml** ya cargado en el repositorio y configurado en el pipeline:

<img src="https://kppp8w.ch.files.1drv.com/y4mLjYDYWVW-uA1FS6tQQvLPSjClQkARYgIju89-FEv9ZJoMN56AjEGz_Ddrb-4FBjIdNZoUPY0FGzkVH-0T-ZnN7iWZuSV3SW8pHZI_N6_Xy3amevCSt37EW2LkqqVup1Iqdc9rM8fZmOSXKsAsWawNQOpjNODCFLLLpPwvIoe2PWcr2BPG2EqD7s9Akm3YMtesX3byAcHEkcqCCWsvd40eA?width=827&height=241&cropmode=none" alt="Azure Pipeline demo" class="alignnone" />

Es el build más simple que he escrito hasta ahora: Simplemente una tarea con PowerShell, donde se imprime la variable ***demo***, definida en el pipeline (aún no, pero lo haremos):

Para definir esta variable, es necesario editar el pipeline y acceder a la sección **Variables**:

<img src="https://w2erlg.ch.files.1drv.com/y4mTI0xKkrR88IN-kZJSrhroSBJaS5ZnwDdYJs1TtLndty90uexrza3tg45uYPY_xaVu8yvVkVWl0sLbgI9VThlywfDDV7x3syXjd_oWu4MWLVfl7AprL9IQ0ux2hye-92VaHKQEGqLVNQPTYI1dhN_oMkba5zEuYaD-i1zgQldSlKvQR-r3SyCTVG240s4N3dp9acKgZ5lyVA7bMIJ7xq4qA?width=1493&height=341&cropmode=none" alt="" class="alignnone" />

O de lo contrario, definir en el archivo .yml que utilizamos para construir el pipeline la variable de la siguiente manera:

{% highlight yaml%}
variables:
  MyVariable: 'This is a variable value'
{% endhighlight %}

Luego, al ejecutar el build, vamos a obtener como resultado una tarea específica donde se imprime el resultado de la variable de entorno:

<img src="https://8gmbrg.ch.files.1drv.com/y4mOaR7TnKM7_7Kpx7xhgazNgJhCWYOaPQFh4VWPCYUsMpIhvjPkpGUJmU7Cq2e46IwsSdNYHkpM5qufI-G_tE2zAvZ9oiGN_9TUksc0FBFCAZ7VkZH5HY_Y7zSa-GR57KUanBSqNKxUBMLtP4C2-dzXQXYQY6o9lGmqJUTCvVguk9aqAWgRd7JDbVLjKASnqkzxVUn4hCmzMGt2AJe6z1Rnw?width=1511&height=441&cropmode=none" alt="" class="alignnone" />

Más información:
 - [Variables (Azure Pipelines)](https://docs.microsoft.com/en-us/azure/devops/pipelines/process/variables)
 - [Tasks con PowerShell (Azure Pipelines) ](https://docs.microsoft.com/en-us/azure/devops/pipelines/tasks/utility/powershell?view=azure-devops#examples)

Happy scripting!