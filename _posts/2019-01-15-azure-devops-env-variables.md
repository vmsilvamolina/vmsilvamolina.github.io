--- 
title: "Azure Pipelines ¿por donde empiezo?" 
author: Victor Silva
date: 2019-01-15T19:57:00+00:00 
layout: single 
permalink: /azure-devops-env-variables/ 
excerpt: "" 
categories: 
  - Azure
  - DevOps 
tags: 
  - Azure DevOps
  - Pipelines
  - Variables
--- 

Antes de revisar en profundidad podemos expresar que es conceptualmente como una forma automatizada de disponibilizar nuevas features de una aplicación a los usuarios finales (o usuarios de pruebas también). Los pipelines, también conocidos como CI/CD (Continuous Integration y Continupus delivery) definen el proceso en que el programador actualiza el código en el repositorio y de forma automática se inician una serie de pasos configurados donde transcurren ciertas tareas como tests unitarios hasta la distribución de los cambios en los diferentes ambientes.




También conocido como es CI/CD (Continuous Integration and Continuous Delivery), se trata de una forma automatizada para disponibilizar nuevas funcionalidades de un software a los distintos interesados, que pueden ser usuarios finales o usuarios de prueba.

El proceso consiste en que un programador sube el nuevo código al repositorio y automáticamente se inicia a la ejecución de una serie de pasos pasos pre configurados, que van desde correr tests unitarios, hasta distribuir los cambios al sistema en ambientes productivos para que los usuarios finales puedan utilizarlo.
Una típica dificultad dentro de todos estos pasos es la diversidad de tecnologías utilizadas para programar los sistemas, los que evolucionan particularmente rápido en el “tiempo TI”. Cada uno de estos frameworks requiere configuraciones diferentes, especialmente las páginas web, las cuales varían mucho y requieren procesos adicionales como instalación de dependencias, aplicar prefijos, minificación, pre-compilación, etc. (de aquí el nombre pipeline).

Si te parece interesante, toda la documentación necesaria está en este sitio: https://docs.microsoft.com/en-us/azure/devops/pipelines/?view=azdevops. Ahí hay ejemplos, videos, tutoriales, casi para todas las tecnologías desktop/web/movil.

Ahh!, y si quieres configurar un pipeline para publicar aplicaciones móviles, lo mejor es utilizar AppCenter (https://appcenter.ms), que está especialmente diseñado para esas tecnologías, ahí incluso se pueden testear las aplicaciones en dispositivos reales y mantener estadísticas de performance de la ejecución de tus aplicaciones!

Y por favor! No dudes en preguntarme si puedo ayudarte en algo :)

Happy scripting!

https://odetocode.com/blogs/scott/archive/2019/02/08/using-environment-variables-in-azure-devops-pipelines.aspx