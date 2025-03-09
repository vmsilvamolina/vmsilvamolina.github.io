---
title: 'Plan de pruebas post migración de AD'
date: 2014-06-13T10:23:37+00:00
author: Victor Silva
layout: post
permalink: /plan-de-pruebas-post-migracion-de-ad/
dsq_thread_id:
  - "4490825219"
categories:
  - Active Directory
  - Windows Server
tags:
  - Active Directory
  - Migración
  - AD
  - Plan de pruebas
---
Se pretende establecer y describir el procedimiento a realizar luego de completada la migración de dominio de Active Directory en la infraestructura, para así verificar la integridad de la implementación así como el correcto funcionamiento de los componentes de la misma.

## Alcance

El alcance de este documento se limita a comprobar el funcionamiento de la implementación de Active Directory, luego de realizada la migración de dominio.

## Etapas del procedimiento

Este procedimiento está dividido en 3 etapas que comprenden la totalidad de las pruebas a realizar para corroborar el correcto funcionamiento. Las etapas son las siguientes:

**Etapa 1 _** Apagado/Inicio de servicios

**Etapa 2 _** Replica de controladores

**Etapa 3 _** Sincronización de cambios

## Etapa 1: Apagado / Inicio de servicios

Esta etapa pretende realizar el testing de todos los servicios de Active Directory, realizando varios reinicios de la implementación.

### Acciones de prueba

**_Para apagar un controlador_**

  1. Logueado en un controlador de dominio, acercar el cursor del mouse sobre la esquina superior derecha.
  2. Seleccionar **Configuración** y luego **Iniciar/Apagar**
  3. Luego seleccionar apagar.
  4. Prender el servidor recién apagado.
  5. Luego de iniciar sesión con un usuario administrador, pulsar **WinKey + r** y escribir **services.msc**


### Resultados esperados

Se pretende obtener todos los servicios con inicio automático estén correctamente iniciados.

## Etapa 2: Replica de controladores

Luego de realizada la etapa anterior obteniendo resultados correctos, procederemos a realizar pruebas de diagnóstico sobre la replicación entre los controladores definidos en el dominio.

Para ello vamos a trabajar con los siguientes comandos:

  * Dcdiag
  * Repadmin
  * Nslookup


### Acciones de prueba

**_Para corroborar el estado de los Domain Controllers_**

  1. Desde un controlador de dominio (logueado como administrador del dominio), ir a **Inicio**.
  2. Luego ejecutar y escribir **cmd**, pulsar enter para ejecutar una consola.
  3. Desde la consola, escribir:

{% highlight posh%}
dcdiag /s:<nombredelservidor> /u:<nombredeusuario> /p:<password>
{% endhighlight %}

Y pulsar enter.

**_Para corroborar el estado de la replicación_**

  1. Desde un controlador de dominio (logueado como administrador del dominio), ir a **Inicio**.
  2. Luego ejecutar y escribir **cmd**, pulsar enter para ejecutar una consola.
  3. Desde la consola, escribir **repadmin /showrepl** y pulsar enter.


**_Para corroborar el estado de la resolución de nombres_**

  1. Desde un controlador de dominio (logueado como administrador del dominio), ir a **Inicio**.
  2. Luego ejecutar y escribir **cmd**, pulsar enter para ejecutar una consola.
  3. Desde la consola, escribir **nslookup** y pulsar enter.
  4. Escribir **set q=SRV** y pulsar enter.
  5. Escribir _**\_ldap.\_tcp.dc._msdcs.ActiveDirectoryDomainName**_ _y pulsar enter._

### Resultados esperados

**_Para corroborar el estado de los Domain Controllers_**

Debemos obtener como resultados de los test ejecutados por la herramienta **dcdiag** valores equivalentes al siguiente ejemplo:

{% highlight plaintext %}
Domain Controller Diagnosis

Performing initial setup:

Done gathering initial info.


Doing initial required tests


Testing server: Default-First-Site-NameRESKIT-DC1

Starting test: Connectivity

......................... RESKIT-DC1 passed test Connectivity


Doing primary tests


Testing server: Default-First-Site-NameRESKIT-DC1

Starting test: Replications

......................... RESKIT-DC1 passed test Replications

Starting test: NCSecDesc

......................... RESKIT-DC1 passed test NCSecDesc

Starting test: NetLogons

......................... RESKIT-DC1 passed test NetLogons

Starting test: Advertising

......................... RESKIT-DC1 passed test Advertising

Starting test: KnowsOfRoleHolders

......................... RESKIT-DC1 passed test KnowsOfRoleHolders

Starting test: RidManager

......................... RESKIT-DC1 passed test RidManager

Starting test: MachineAccount

......................... RESKIT-DC1 passed test MachineAccount

Starting test: Services

......................... RESKIT-DC1 passed test Services

Starting test: ObjectsReplicated

......................... RESKIT-DC1 passed test ObjectsReplicated

Starting test: frssysvol

......................... RESKIT-DC1 passed test frssysvol

Starting test: kccevent

......................... RESKIT-DC1 passed test kccevent

Starting test: systemlog

......................... RESKIT-DC1 passed test systemlog



Running partition tests on : Schema

Starting test: DeadCRTest

......................... Schema passed test DeadCRTest

Starting test: CheckSDRefDom

......................... Schema passed test CheckSDRefDom



Running partition tests on : Configuration

Starting test: DeadCRTest

......................... Configuration passed test DeadCRTest

Starting test: CheckSDRefDom

......................... Configuration passed test CheckSDRefDom



Running partition tests on : RESKIT-DOM

Starting test: DeadCRTest

......................... RESKIT-DOM passed test DeadCRTest

Starting test: CheckSDRefDom

......................... RESKIT-DOM passed test CheckSDRefDom



Running enterprise tests on : RESKIT-DOM.reskit.com

Starting test: Intersite

......................... RESKIT-DOM.reskit.com passed test Intersite

Starting test: FsmoCheck

......................... RESKIT-DOM.reskit.com passed test FsmoCheck
{% endhighlight %}


**_Para corroborar el estado de la replicación_**

Debemos obtener como resultados de los test ejecutados por la herramienta **repadmin** valores equivalentes al siguiente ejemplo:

{% highlight plaintext %}
C:\>repadmin /showrepl server1.microsoft.com
Building7aserver1
DC Options : IS_GC
Site OPtions: (none)
DC object GUID : 405db077-le28-4825-b225-c5bb9af6f50b
DC invocationID: 405db077-le28-4825-b225-c5bb9af6f50b

==== INBOUND NEIGHBORS ======================================

CN=Schema,CN=Configuration,DC=microsoft,Dc=com
Building7bserver2 via RPC
objectGuid: e55c6c75-75bb-485a-a0d3-020a44c3afe7
last attempt @ 2002-09-09 12:25.35 was successful.



CN=Configuration,DC=microsoft,Dc=com
Building7bserver2 via RPC
objectGuid: e55c6c75-75bb-485a-a0d3-020a44c3afe7
last attempt @ 2002-09-09 12:25.10 was successful.



DC=microsoft,Dc=com
Building7bserver2 via RPC
objectGuid: e55c6c75-75bb-485a-a0d3-020a44c3afe7
last attempt @ 2001-09-09 12:25.11 was successful
{% endhighlight %}

**_Para corroborar el estado de la resolución de nombres_**

Debemos obtener como resultados de los test ejecutados por la herramienta **nslookup** valores equivalentes al siguiente ejemplo:

{% highlight plaintext %}
Default Server:  dc1.example.microsoft.com
Address:  10.0.0.14
set type=srv
_ldap._tcp.dc._msdcs.example.microsoft.com
Server:  dc1.example.microsoft.com
Address:  10.0.0.14
_ldap._tcp.dc._msdcs.example.microsoft.com   SRV service location:
priority       = 0
weight         = 0
port           = 389
svr hostname   = dc1.example.microsoft.com
_ldap._tcp.dc._msdcs.example.microsoft.com   SRV service location:
priority       = 0
weight         = 0
port           = 389
svr hostname   = dc2.example.microsoft.com
dc1.example.microsoft.com     internet address = 10.0.0.14
dc2.example.microsoft.com     internet address = 10.0.0.15
{% endhighlight %}

## Etapa 3: Sincronización de cambios

Al ejecutar el procedimiento correspondiente se procura realizar cambios sobre los objetos de Active Directory y que los mismos sean sincronizados entre el resto de los controladores de dominios denotando el correcto funcionamiento de la sincronización de la base de datos de la aplicación.


### Acciones de prueba

Crear una OU (unidad organizativa) en Active Directory desde un controlador de dominio, forzar la replicación y consultar en los otros controladores de dominio que el cambió realizado se haya efectuado correctamente.

**_Para corroborar el estado de la sincronización de cambios_**

  1. Desde un controlador de dominio (logueado como administrador del dominio), ir a **Inicio**.
  2. Luego ejecutar y escribir **dsa.msc**, pulsar enter para ejecutar la consola de Usuarios y Computadoras en Active Directory.
  3. Seleccionar el dominio, y luego hacer click derecho, seleccionar nuevo.
  4. En el menú desplegable, seleccionar la opción **Unidad organizativa**
  5. Dentro del cuadro de dialogo, establecer el nombre de la unidad, por ejemplo “**OU de Pruebas de Sync**”
  6. Cerrar todos los cuadros de dialogo y la consola de Active Directory.
  7. Iniciar sesión en un controlador diferente como administrador.
  8. Hacer click en inicio y luego escribir **cmd**.
  9. Dentro de la consola de línea de comandos, ejecutar **repadmin /replicate**
 10. Hacer click en inicio y luego escribir dsa.msc.
 11. Dentro de la consola, desplegar el nodo del dominio


### Resultados esperados

Dentro del nodo del dominio, debería de encontrarse la OU creada en el anterior controlador de dominio siguiendo los pasos detallados.

Espero sirva de ejemplo para poder definir un plan de comprobación de Active Directory.

Happy scripting!