---
title: Primeros pasos en Azure Storage con PowerShell
date: 2016-07-29T00:05:41+00:00
author: Victor Silva
layout: post
permalink: /azure-storage/
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";s:68:"https://cdn-images-1.medium.com/fit/c/200/200/0*Sz3Js055VwE6KyPu.jpg";s:10:"author_url";s:33:"https://medium.com/@vmsilvamolina";s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";s:12:"e912921dae75";s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:6:"public";s:3:"url";s:78:"https://medium.com/@vmsilvamolina/primeros-pasos-en-azure-storage-e912921dae75";}'
dsq_thread_id:
  - "5650647669"
categories:
  - Azure
  - PowerShell
tags:
  - Azure
  - Azure Storage
  - Blob
  - PowerShell
  - Queue
  - Storage
  - Table
---
Azure ofrece una variedad de servicios bastante amplia, por lo que abarcar todos los productos realmente se dificulta. Y más se dificulta con la velocidad en que evolucionan los mismos y las exigencias del negocio. Si bien es cierto que hay servicios en _preview_ que al tiempo desaparecen o mutan, muchos otros se vuelven el core de la plataforma, como lo es Azure Storage.

## ¿Qué es Azure Storage?

Azure Storage ofrece una solución de almacenamiento en la nube, otorgando disponibilidad, escalabilidad y durabilidad.

El paradigma de **cloud computing** nos dio acceso a nuevos escenarios de desarrollo e implementación de soluciones. En estos escenarios son tratados por igual empresas que procesan cientos de terabytes de datos o pequeñas empresas que necesitan almacenar cantidades de datos necesarios para alimentar una web o alojar planillas de uso diario. En ambos casos el cliente va a pagar por uso, o sea, por lo los datos que esté almacenando.

## Los servicios de Azure Storage

Azure Storage ofrece 4 tipos de servicios de almacenamiento:

  * **Blob Storage:** Utilizado para almacenar información datos de objetos no estructurado. Un blob puede ser un documento, archivo multimedia o un instalador de algún software. También es conocido como _Object storage_.
  * **Table Storage:** Es un almacén de datos del tipo _NoSQL key-attribute_, permitiendo un rápido desarrollo y acceso a grandes cantidades de información.
  * **Queue Storage:** Ofrece un canal de messaging (puede manipular hasta 2000 message transaction por segundo) para el procesamiento de workflow y para comunicar componentes cloud.
  * **File Storage:** Proporciona almacenamiento compartido para aplicaciones "
legacy"
, que utilizan el protocolo SMB estándar. Las VMs de Azure y los servicios pueden compartir archivos entre sí. Adicionalmente, las aplicaciones locales pueden acceder a datos en un recurso compartido a través de la API REST.

Para poder consumir los servicios de Azure Storage de forma segura y controlada, existen 2 tipos de cuentas disponibles para utilizar según nuestros requerimientos de funcionalidad:

  * **General-purpose Storage Accounts:** Es un tipo de cuenta genérica el cual permite brindar acceso a los servicios como Tables, Queues, Blobs y discos virtuales de VMs de Azure con una única cuenta.

  * **Blob Storage Accounts:** Este tipo es específico para almacenar datos no estructurados como blobs (objetos). Blob Storage accounts son similares a las cuentas de almacenamiento de propósito general existentes y comparten todas las características de durabilidad, disponibilidad, escalabilidad y rendimiento. Que incluye la consistencia del 100% de API para bloquear blobs y agregar blobs. Para las aplicaciones que requieren solo Almacenamiento de blobs en bloque o en anexos, se recomienda utilizar cuentas de Almacenamiento de blobs.

## Replicación y Alta disponibilidad

Los datos de las cuentas de Azure Storage se replican siempre para garantizar la durabilidad y alta disponibilidad. Existien cuatro opciones diferentes de replicación para poder seleccionar la que mejor se adapte a las necesidades del negocio:

**Locally redundant storage (LRS):** El almacenamiento con redundancia local mantiene tres copias de los datos. LRS se replica tres veces dentro de un único centro de datos de una sola región. LRS protege los datos frente a errores comunes del hardware, pero no frente a errores de un único centro de datos.

**Zone-redundant storage (ZRS):** El almacenamiento con redundancia de zona mantiene tres copias de los datos. ZRS se replica tres veces entre dos o tres instalaciones, ya sea dentro de una sola región o entre dos regiones. Proporciona una mayor durabilidad que LRS. ZRS garantiza la durabilidad de los datos dentro de una sola región.

**Geo-redundant storage (GRS):** GRS mantiene seis copias de sus datos. Con GRS, los datos se replican tres veces dentro de la región primaria. Y posteriormente se replican tres veces más en una región secundaria, proporcionando el nivel más alto de durabilidad. En caso de que se produzca un error en la región primaria, Azure Storage conmutará por error a la región secundaria. GRS garantiza la durabilidad de sus datos en dos regiones independientes.

**Read-access geo-redundant storage (RA-GRS):** El almacenamiento con redundancia geográfica con acceso de lectura replica los datos en una ubicación geográfica secundaria y, además, proporciona acceso de lectura a ellos en la ubicación secundaria. El read-access geo-redundant permite acceder a los datos desde la ubicación principal o la secundaria, ante la eventualidad de que alguna de las ubicaciones no se encuentre disponible. Este tipo de replicación es la opción predeterminada al momento de crearla.

> Para obtener más información sobre lo presentado recomiendo leer la [documentación oficial](https://docs.microsoft.com/es-es/azure/storage/storage-introduction).

## Blob Storage: cómo utilizarlo

Vamos a ver como empezar a meter mano en esto del storage en Azure y para ello, seleccionamos el Blob Storage para comenzar.

De más está decir que vamos a necesitar una suscripción activa de Azure. Les recomiendo generar una desde [éste](https://azure.microsoft.com/en-us/free/) enlace en caso de no contar con una.

Ingresamos al portal y vamos a crear una cuenta de storage, realizando lo que indica la siguiente imagen:

<img src="https://q15hmq-ch3302.files.1drv.com/y4mfmrF7xtW1nPs4QAAxUrwsEmjBeNlUa1s86M7m_ExOYxN2-jn_k0RT_2Xc4BVRTYEWaTVIcD3t4jSuqikEokb7ECyj4xOfze64BaGkDEbhVhMoXX3LMlgM4g6KPg7vYRJQe4dMT1kqjjsyw8MMIXS-Atk4-OTZWwzVZexs58clBThxpC-ovnJg_hJRjhpR3Y1Cs5-SA29P4pCnj4CNq8R6g?width=1021&#038;height=640&#038;cropmode=none" width="1021" height="640" alt="Nueva cuenta de Storage" class="alignnone size-medium" />

Luego completamos los campos requeridos por el asistente:

<img src="https://q15gmq-ch3302.files.1drv.com/y4mcPE96Xu7bW5nAxA4bzVwAm5E-PxEpujMY1H3K-V0tL_Mwg2AVPY272AFcP2srWemaEa9InZ51D6cr2OPmXKIbkXcTkuYpdJ-PN-gUX4e_rS_Uw4sNIz9NrLvS0Ba_D_c9TDygyUrjZnV0Pv-2mvhSUnuG7rhUzXZLYKiI-yYwlVhIsNM44mqXoa3jrlSYGbaRo8U9bbrcFWzkYrQAPsReQ?width=287&#038;height=426&#038;cropmode=none" width="287" height="426" alt="Azure Storage Account" class="alignnone size-medium" />

En donde debemos seleccionar para este ejemplo los siguientes valores:

  * _Nombre:_ storagedeprueba
  * _Tipo de cuenta:_ General
  * _Replicación:_ RA-GRS

Al finalizar el asistente, vamos a descargar el [Storage Explorer](http://storageexplorer.com/). Software que básicamente permite utilizar una interfaz visual como el explorador de Windows para acceder a nuestros containers y blobs de información de nuestras cuentas de Azure Storage.

También puede descargarse desde el portal de Azure, utilizando el botón "
Open in Explorer"
 (al no encontrarlo instalado, preguntará para descargarlo).

<img src="https://q15fmq-ch3302.files.1drv.com/y4mF3h9Cod5KE-fzh3r8TeucnmmkB4gof62Na8KJ_ITpdNfKiG8ADDOvejsmF8ExarATM7-lNO9NWO4qX_A3yRNgwvJPVLDRVbCxNvuAZRFsD0fkzJ9v_l2GIa40s2CHkKf44cplZ1E-h1V4mECmy5AlhKeZ5JQRxao0QgR5zBQxuM2aDrXuAtAoRTaA4IyAdFlDiG1nboWpCgj4nXg1_5a2Q?width=854&#038;height=436&#038;cropmode=none" width="854" height="436" alt="Azure Storage Explorer" class="alignnone size-medium" />

Ya con el Storage Explorer descargado e instalado en nuestro equipo, vamos a ver como subir un archivo para luego acceder a él.

## Crear un blob y subir archivos

Desde las propiedades de nuestra cuenta de storage, vamos a seleccionar la opción **_Open in Explorer_**, que nos consultará si permitimos la ejecución del Storage Explorer en nuestro equipo local.

Ahora que tenemos en ejecución el storage explorer, vamos a seleccionar el ícono que refiere a una cuenta (o persona) y luego en **_Add account&#8230;_**.

<img src="https://azfkrw-ch3302.files.1drv.com/y4maFfm7wPpL7VcLdsz210WCHE1a5GaDLKxwO286e4kqTwcMkXkwdnIXJet8jp7u6rAyoKu5PDtTlWtWJYDc9-9Y4AzHwiE8A1fVYNT9zWASZZTMmNcGcXSIPqrCNo8RLQjz_iZHI1RwI8t1nTHiGRbZRttVJGcjryMPhueP4k8qqW3JAuVv8BnCPtDtZZHKXzVN5mBYQJq8V0ooMcj1hYrnQ?width=409&#038;height=277&#038;cropmode=none" width="409" height="277" alt="Storage Explorer agregar cuenta" class="alignnone size-medium" />

Dentro de la ventana que se despliega, seleccionamos **_Azure_** y clic al botón **_Sign in&#8230;_** para posteriormente ingresar las credenciales de nuestra suscripción.

Luego de ingresar las credenciales, seleccionamos la suscripción en la que deseamos trabajar y hacemos un clic sobre el botón **_Apply_**.

Ahora que tenemos cargada nuestra suscripción, vamos a navegar dentro de la cuenta de storage que pretendemos utilizar, seleccionamos _Blob Container_ y hacemos un clic derecho para seleccionar la opción **_Create Blob Container_**. Ingresamos un nombre en minúscula para nuestro contenedor (para el ejemplo usé blog):

<img src="https://azfjrw-ch3302.files.1drv.com/y4mB3Pbd9GnOsOKVTy7KvxggzcHPDtIhdTjlpSJ0BFtfd_2hZdRVjePdtMxME65bbSjCMkeKbu6w_uzGC0AU7467jri5ImruCHH4RRjGMmKLoasi5ArcGqRakNId7sViYV63ZKc1hRSDpQE7SuwUMcfhfvDNafIRC8LqMsRQ-peEmKiveg2n-1bKDf_XFTCMKzDIbUr-0Xl8xiQLJi9_NAUUA?width=426&#038;height=487&#038;cropmode=none" width="426" height="487" alt="Storage Explorer crear Blob Container" class="alignnone size-medium" />

Ahora que tenemos nuestro contenedor, vamos a subirlo a nuestro contenedor. Primero, seleccionamos el botón **_Upload_** desde el _Storage Explorer_. Navegamos hacia la ruta donde se encuentra el archivo a utilizar, y pulsamos _Upload_ en el asistente:

<img src="https://azfirw-ch3302.files.1drv.com/y4mdOiT75zgzlBdcc0QSbepSUizkOLlnO7L6trndO2hrO7s29aeMv9avRu_dWSXSkYqV6ufQbzA20Oi8UHjR8X03dfSF6v8A2GmIzRonUwmnIrHLrML48186zh6OsVg1e-ngp96fELy3JGce5RnaMezJLaskr1p7kX3EqMDRsCiISbWzOUycB7BuKqTk7daHLQzDN-LIvlajIpwgiAYwwPAUA?width=986&#038;height=512&#038;cropmode=none" width="986" height="512" alt="Storage Explorer upload files" class="alignnone size-medium" />

## PowerShell y Azure Storage

Luego de ver los conceptos principales de Azure Storage y de cómo comenzar a trabajar por medio del portal de Azure, vamos a ver como hacerlo por medio de la consola de PowerShell.

Por obvias razones hacemos énfasis en la necesidad de tener en el equipo el módulo de Azure PowerShell instalado. En caso de no contar con el mismo simplemente debemos ejecutar:

{% highlight posh %}
Install-Module -Name AzureRM -Scope CurrentUser
{% endhighlight %}

Y ahora sí, lo primero que vamos a compartir es cómo se crea la cuenta de storage:

{% highlight posh %}
### Autenticarse en Azure
Add-AzureRmAccount

### Crear el Azure Resource Manager (ARM) Resource Group
$ResourceGroup = @{
Name = 'AzureStoragePoSh'
Location = 'Central US'
Force = $true
}
New-AzureRmResourceGroup @ResourceGroup

### Crear la Storage Account
$StorageAccount = @{
    ResourceGroupName = 'AzureStoragePoSh'
    Name = 'StoragePoShAccount'
    SkuName = 'Standard_LRS'
    Location = 'Central US'
    }
New-AzureRmStorageAccount @StorageAccount
{% endhighlight %}

Ahora que hemos creado la cuenta de almacenamiento, necesitamos comenzar a comunicarnos con la API REST de almacenamiento de Azure, por supuesto, con PowerShell. Esto requiere que creemos un contexto de autenticación que apunte específicamente al servicio de almacenamiento de Azure. En este punto, estamos cambiando de comunicación con la API de Azure Resource Manager (ARM) y hablando con Azure Storage en su lugar.

En primer lugar, obtendremos las claves de la cuenta de almacenamiento utilizando ARM y, a continuación, crearemos un Storage Context Object utilizando una de las claves. El Storage Context Object en sí es lo que nos permite autenticar a la API REST de almacenamiento de Azure de PowerShell.

> Los comandos ya no tienen "
AzureRm"
 en el nombre, simplemente tienen el prefijo "
Azure"
. Esto se debe a que los >comandos Azure Storage no forman parte de la interfaz de Azure Resource Manager.

{% highlight posh %}
### Obtenemos la Storage Account authentication keys con ARM
$Keys = Get-AzureRmStorageAccountKey -ResourceGroupName AzureStoragePoSh -Name StoragePoShAccount

### Usando el módulo Azure.Storage, se crea el Storage Authentication Context
$StorageContext = New-AzureStorageContext -StorageAccountName AzureStoragePoSh -StorageAccountKey $Keys[0].Value
{% endhighlight %}

Teniendo lo mencionado anteriormente, vamos a crear un Blob Container para alojar nuestros "
blobs"
 de almacenamiento. Para ello:

{% highlight posh %}
### Crear un Blob Container en la Storage Account
New-AzureStorageContainer -Context $StorageContext -Name blobStoragePoSh
{% endhighlight %}

Finalizando el proceso resta realizar la carga de un archivo para validar todo lo ejecutado y configurado anteriormente, de la siguiente manera:

{% highlight posh %}
### Subimos un archivo con a el Microsoft Azure Storage Blob Container
$UploadFile = @{
    Context = $StorageContext
    Container = 'blobStoragePoSh'
    File = "C:\Users\Victor\Desktop\test.txt"
}
Set-AzureStorageBlobContent @UploadFile
{% endhighlight %}

En la que vamos a utilizar el blob creado, específicando también la ruta de nuestro archivo a subir&#8230; y todo ello con PowerShell!

Happy scripting!