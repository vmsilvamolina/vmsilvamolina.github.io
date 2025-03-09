---
title: 'PowerShell - Crear un módulo binario'
date: 2015-08-14T15:43:22+00:00
author: Victor Silva
layout: post
permalink: /powershell-crear-un-modulo-binario/
dsq_thread_id:
  - "4484896218"
categories:
  - PowerShell
tags:
  - .Net Framework
  - 'C#'
  - Cmdlets
  - Modulo
  - Office365
  - System.Management.Automation
  - System.Net
  - Visual Studio
  - WebRequest
  - WebResponse
---
Unas de las cosas maravillosas de PowerShell es poder generar nuestros propios módulos personalizados. Esto nos permite poder agrupar nuestras funciones, con nuestros nombres y características particulares de la misma manera que los módulos tradicionales (por ejemplo: _ActiveDirectory_, _ServerManager_, etc.)

Hay varios tipos de módulos (dejo [enlace a la TechNet](https://technet.microsoft.com/en-us/library/dd901839%28v=vs.85%29.aspx) para tener más información sobre este concepto) que podemos construir en PowerShell, pero en este post en particular, pretendo enfocarme solamente en los módulos binarios utilizando **_C#_**.

Éstos módulos van a ser generados por medio de Visual Studio (para los que no sabían, existe una versión gratuita para descargar: [Visual Studio Community 2015](https://www.visualstudio.com/?Wt.mc_id=DX_MVP5001484))

Nuestro módulo va a estar compuesto por una única función, la cual nos va a permitir revisar la disponibilidad de un dominio para utilizar en Office365 (este tema lo tratamos en un post anterior: [Comprobar disponibilidad de dominio](http://blog.victorsilva.com.uy/powershell-y-office-365-script-para-comprobar-disponibilidad-de-dominio/)).

Ya teniendo instalado Visual Studio, lo primero que tenemos que hacer es crear un proyecto nuevo

<img src="https://lh3.googleusercontent.com/4j4hJhxyr5RgXb86BMNb5o_4MxWlq_yWkhPf_dEapNg=w659-h415-no" width="659" height="415" class="alignnone" />

Dentro de **C#** seleccionamos **Class Library** y escribimos el nombre de nuestro módulo: **PowerShellRules** en mi caso.

<img src="https://lh3.googleusercontent.com/a7yyih0A3-yf0kgz9OMyTrqtuMaeg60Fsw64pHipC58=w941-h575-no" width="941" height="575" class="alignnone" />

Con el proyecto creado, vamos a agregar una referencia para poder crear nuestros **cmdlets**. La referencia en cuestión es

> System.Management.Automation

Para poder agregar esta referencia, utilizaremos NuGet.

Accedemos al menú Tools > NuGet Package Manager > Package Manager Console.

<img src="https://lh3.googleusercontent.com/dQd_USLVzMQPy9Wrk6PmhTUwZ0Bj9bzXxoaxAzVMu90=w737-h478-no" width="737" height="478" class="alignnone" />

En la consola escribimos:

> Install-Package System.Management.Automation

<img src="https://lh3.googleusercontent.com/Icj6np58PQ9b6xoAVsvUWE_TBodtrLncp3JTbhirGYU=w982-h201-no" width="982" height="201" class="alignnone" />

Al finalizar el proceso, podemos examinar que se encuentra ya declarada y agregada:

<img src="https://lh3.googleusercontent.com/vNxKSFfs4xlm-hiPuF19yILL57C5b0dA4xhqFq-xM80=w741-h325-no" width="741" height="325" class="alignnone" />

Esto sería lo básico para poder empezar a trabajar, pero como nosotros ya sabemos que vamos a hacer debemos agregar otra referencia, ahora es la **System.Net** que nos permite hacer lo siguiente: Utilizar las clases [WebRequest](https://msdn.microsoft.com/en-us/library/system.net.webrequest%28v=vs.110%29.aspx) y [WebResponse](https://msdn.microsoft.com/en-us/library/system.net.webresponse%28v=vs.110%29.aspx).

Para poder agregar esta referencia, clic derecho sobre **References** y seleccionamos **Add Reference&#8230;**

<img src="https://lh3.googleusercontent.com/j66agBGCabtH-w8rKNCxZb08qPdP5ozigOtdrnhJw4w=w326-h361-no" width="326" height="361" class="alignnone" />

Buscamos y seleccionamos _System.Net_ como muestra la imagen

<img src="https://lh3.googleusercontent.com/1oHQimfhE3MvI1iYe2EFL4ruzm0YmBGm9zq229UwtMU=w786-h543-no" width="786" height="543" class="alignnone" />

Y ahora empezamos a escribir nuestro primer comando de PowerShell!!

Empezamos escribiendo:

    [Cmdlet(VerbsCommon.Find, "O365Domain")]
    public class FindO365Domain : PSCmdlet
    {
    
    }
    

Donde declaramos el verbo que vamos a utilizar en el nombre de nuestro Cmdlet (para los que no se acuerdan, la mayoría de los Cmdlets tienen la estructura de "
_Verbo**_-_**Sustantivo_"
). En este ejemplo el sustantivo es "
O365Domain"
. Luego definimos la clase que hace referencia a este Cmdlet, para ello simplemente escribimos el verbo y sustantivo todo junto.

Esta función va a tener un único parámetro, llamado "
Domain"
, para declararlo, generamos una variable auxiliar

    private string[] domainName;
    

Y luego el parámetro de la siguiente forma:

        [Parameter(
            Mandatory = true,
            ValueFromPipelineByPropertyName = true,
            ValueFromPipeline = true,
            Position = 0,
            HelpMessage = "Nombre de dominio a chequear."
        )]
        [Alias("Tenant")]
        public string[] Domain
        {
            get { return domainName; }
            set { domainName = value; }
        }
    

Ok, hasta ahora declaramos el parámetro "
Domain"
 (con el alias _Tenant_) y obligatorio.

Simplemente antes de escribir el cuerpo del comando, vamos a recordar que para nosotros saber si un nombre de dominio para Office365 se encuentra utilizado, tendríamos que acceder a la siguiente dirección y obtener de respuesta un archivo xml:

> https://login.windows.net/<nombredominio>.onmicrosoft.com/FederationMetadata/2007-06/FederationMetadata.xml

Recordando estopodemos imaginar como resolverlo: Si obtenemos una respuesta correcta a un dominio, ya está utilizado, en C# sería algo así:

        protected override void ProcessRecord()
        {
            foreach (string domain in domainName)
            {
                WriteVerbose("Revisando la disponibilidad del dominio: " + domain);
                string addressCheck = "https://login.windows.net/" + domain + ".onmicrosoft.com/FederationMetadata/2007-06/FederationMetadata.xml";
                try
                {
                    WebRequest request = WebRequest.Create(addressCheck);
                    WebResponse response = request.GetResponse();
                    WriteObject("");
                    WriteObject(domain + ": Dominio en uso.");
                    WriteObject("");
                    response.Close();
                }
                catch (WebException ex)
                {
                    if (ex.Status == WebExceptionStatus.NameResolutionFailure)
                    {
                        WriteObject("");
                        WriteObject(domain + ": Dominio disponible.");
                        WriteObject("");
                    }
                    WriteObject("");
                    WriteObject(domain + ": Dominio disponible.");
                    WriteObject("");
                }
            }
        }
    

Ok. Tenemos la función, ahora tenemos que construir la .dll para poder probarla.

Utilizando la combinación de teclas **Ctrl + Shift + B** armamos el módulo. Este proceso nos va a devolver una ruta como la siguiente:

> C:\Users\Victor\documents\visual studio 2015\Projects\PowerShellBinaryRules\PowerShellBinaryRules\bin\Debug\PowerShellRules.dll

Ahora abrimos una consola de PowerShell y ejecutamos:

    Import-Module "C:\Users\Victor\documents\visual studio 2015\Projects\PowerShellBinaryRules\PowerShellBinaryRules\bin\Debug\PowerShellRules.dll"
    

Ya tenemos nuestro módulo cargado! Podemos comprobarlo ejecutando:

    Get-Module
    

Ahora que sabemos que el módulo está en el sistema, podemos ejecutar un ejemplo con 2 nombres (el primero un invento y el segundo es el que yo tengo registrado):

<img src="https://lh3.googleusercontent.com/9gnwiumILS9oj-AcIDluxvgY9gyBBBHic2FyorgHC5Q=w859-h161-no" width="859" height="161" class="alignnone" />

Saludos, y feliz scripting!