---
title: 'PowerShell DSC'
date: 2016-01-05T00:52:27+00:00
author: Victor Silva
layout: post
permalink: /desired-state-configuration/
dsq_thread_id:
  - "4471581774"
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";s:68:"https://cdn-images-1.medium.com/fit/c/200/200/0*Sz3Js055VwE6KyPu.jpg";s:10:"author_url";s:33:"https://medium.com/@vmsilvamolina";s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";s:12:"9d3961360f66";s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:6:"public";s:3:"url";s:61:"https://medium.com/@vmsilvamolina/powershell-dsc-9d3961360f66";}'
categories:
  - PowerShell
tags:
  - Desired State Configuration
  - DSC
  - PowerShell
  - PowerShell DSC
---
PowerShell DSC (Desired State Configuration) es una plataforma de gestión en Windows PowerShell que permite desplegar y administrar datos de configuración de servicios de software y gestión del entorno en el que se ejecutan estos servicios.

A su vez proporciona al lenguaje de PowerShell un conjunto de extensiones, nuevos cmdlets y recursos para poder especificar, de forma clara y específica, que se desea realizar y configurar. Obviamente proporciona un medio por el cual se administra la configuración, mantención e implementación de configuraciones existentes.

Algunas de las tareas que podemos hacer con DSC:

  * Habilitar/Deshabilitar roles y features 
  * Administrar configuración del registro
  * Administrar directorios y archivos
  * Iniciar, detener y administrar los servicios
  * Gestión de grupos y usuarios
  * Instalar software
  * Ejecutar scripts de Windows PowerShell

En resumen, PowerShell DSC permite a los profesionales de TI realizar de manera consistente; configuraciones estandarizadas y despliegue continuo, siendo éstos puntos los ejes centrales del concepto **_DevOps._**

## Como funciona DSC?

Vamos a definir el modo en que _DSC_ trabaja y que componentes se definen dentro del proceso de implementación.

Primero se debe de escribir un script de configuración en PowerShell. Éste script no hace nada (no instala, ni configura, ni provisiona), se limita a enumerar los elementos que se desea configurar y de qué manera se pretende. La configuración también declara que máquinas son las que se les va a aplicar.

Al ejecutar la configuración, PowerShell genera un archivo del tipo Management Object Format (MOF) para cada máquina, o mejor dicho _nodo_. En este punto, es que cada nodo empieza a configurar su sitema hasta que sea igual a la definida en el archivo MOF.

## Creando una configuración de DSC

Para una configuración de DSC para ser consumido , debe declararlo primero. DSC consume archivos MOF (Management Object Format), un estándar DMTF, que en realidad se puede crear con cualquier editor de texto (por ejemplo _notepad_).

La versión 4 de PowerShell añadió extensiones de sintaxis declarativas e IntelliSense que permiten que sea mucho mas fácil la creación de archivos MOF y también, de las validaciones de esquema. La extensión también agrega una palabra clave para utilizar, llamada "
_Configuration_"
. Con esta palabra clave, que en realidad es una _función_, se define la configuración de DSC de la siguiente manera:

    Configuration DemoDSC {
    
    }
    

Con lo anterior definimos la estructura para poder agregar, por ejemplo, roles o features en un servidor. Veamos un ejemplo de como agregar el rol de **IIS** y la feature **ASP.NET 4.5**:

    Configuration DemoWebSite {
        param ($MachineName)
    
        Node $MachineName {
            #Instalar el rol de IIS
            WindowsFeature IIS {
                Ensure = “Present”
                Name = “Web-Server”
            }
    
            #Instalar ASP.NET 4.5
            WindowsFeature ASP {
                Ensure = “Present”
                Name = “Web-Asp-Net45”
            }
        }
    }
    

Si revisamos el fragmento anterior, utilizamos la palabra _nodo_ para especificar los sistemas de destino de la configuración.

Ya declarada la configuración de DSC, se puede crear un archivo MOF consumible llamando a la función del mismo modo que llamar a cualquier función de PowerShell:

    DemoWebsite –MachineName “Server01”
    

Esto creará una carpeta con el mismo nombre que el nombre de la configuración y contendrá nuestro archivo de salida MOF.

## Aplicando la configuración de DSC

Luego de generar el archivo, es hora de aplicar la configuración utilizando el cmdlet **_Start-Configuration_**, de la siguiente manera:

    Start-DscConfiguration –Path .\DemoWebsite –Wait –Verbose
    

El parámetro “Path” (la ruta donde se aloja el archivo MOF) puede ser del tipo UNC o ruta local.

Para los que quieran seguir investigando sobre esta plataforma, existe en MVA un curso sobre PowerShell Desired State Configuration (en inglés): [Getting Started with PowerShell Desired State Configuration (DSC)](https://mva.microsoft.com/en-US/training-courses/getting-started-with-powershell-desired-state-configuration-dsc-8672)