--- 
title: "Azure DevOps: Environment variables" 
author: Victor Silva
date: 2019-01-15T19:57:00+00:00 
layout: single 
permalink: /azure-devops-env-variables/ 
excerpt: "" 
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

Azure DevOps es la solución que ofrece Microsoft, como la sucesora a VSTS (Visual Studio Team Services), donde se abarca la totalidad del ciclo de vida del desarrollo para ayudar a ofrecer software más rápido y de mejor calidad. Según palabras del propio Microsoft, Azure DevOps Services representan la oferta más completa que existe en la nube pública.

Adicional a los servicios de nube, Microsoft también ofrece Azure DevOps Server (sucesor de Team Fundation Server), como apuesta a la unificación de las herramientas y experiencias para el desarrollo e implementación de soluciones.

La plataforma Azure DevOps cuenta con los siguientes servicios:

 - **Azure Pipelines**: Servicios de CI/CD para crear, compilar, probar y desplegar proyectos con cualquier plataforma o nube, así como conectar repositorios de GitHub, Bitbucket (o cualquier otro repositorio de Git).
 - **Azure Agents**: Agentes disponibles para Windows, Linux y macOS (de forma incorporada), con workflows habilitados con soporte de contenedores y opciones de implementación para entornos Azure, AWS, Service Fabric, Kubernetes, VMs entre otros.
 - **Azure Boards**: Realizar el seguimiento del trabajo del equipo del proyecto con paneles Kanban, backlog del equipo, informes, seguimiento, etc.
 - **Azure Artifacts**: Soporte de paquetes NuGet, Maven y NPM (fuentes públicas y privadas).
 - **Azure Repos**: Repositorios públicos y privados de Git alojados en Azure.
 - **Azure TestPlans**: Gestionar planes para pruebas manuales, planificadas y exploratorias.

<img src="" alt="Azure DevOps Services" class="alignnone" />

Comparto una entrada en el blog de Microsoft donde hablan de Azure DevOps:
https://azure.microsoft.com/es-es/blog/introducing-azure-devops/

## Azure Pipelines
Antes de revisar en profundidad lo que el título indica, podemos expresar primeramente que un pipeline es conceptualmente como una forma automatizada de disponibilizar nuevas features de una aplicación a los usuarios finales (o usuarios de pruebas también). Los pipelines, también conocidos como CI/CD (Continuous Integration y Continuous delivery) definen el proceso en que el programador actualiza el código en el repositorio y de forma automática se inician una serie de pasos configurados donde transcurren ciertas tareas como tests unitarios hasta la distribución de los cambios en los diferentes ambientes.



Happy scripting!