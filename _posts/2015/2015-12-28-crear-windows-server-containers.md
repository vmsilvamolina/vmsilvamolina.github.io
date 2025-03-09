---
title: 'Crear Windows Server Containers'
date: 2015-12-28T14:39:13+00:00
author: Victor Silva
layout: post
permalink: /crear-windows-server-containers/
dsq_thread_id:
  - "4473270286"
categories:
  - Hyper-V
  - PowerShell
  - Windows Server
tags:
  - Container
  - Container Host
  - Crear Windows Server Container
  - Hyper-V
  - PowerShell
  - Windows Server Container
---
Continuando con los post sobre los Windows Containers hoy vamos a ver como crear Windows Server Containers, considerando que cumplimos y configuramos nuestro sistema host, con el [tutorial anterior](http://blog.victorsilva.com.uy/windows-server-containers/).

# Creando el Container

Lo primero que debemos de considerar es de ubicarnos en la VM (en nuestro ejemplo) que actuará de host, y luego generar una instancia de powershell, para ello, desde la consola abierta (cmd), ejecutamos:

    powershell
    

Vamos a usar el cmdlet **_Get-ContainerImage_** para validar que nuestra versión de SO es la Windows Server 2016 Core:

    Get-ContainerImage
    

Para crear el Container, e iniciarlo, debemos ejecutar el siguiente comando:

    New-Container -Name TP4Con -ContainerImageName WindowsServerCore -SwitchName "Virtual Switch"
    

<img src="https://lh3.googleusercontent.com/yt94_MZoSMTnn-VxoWaBXzBXXl7rPN3MrGskapXDb9u_AJVt1tLkDDpqdt3B7Km1pQP-pNofhom2Td1WwO6PAzRyvECRk28-kIjdpOQmzV7jUxWP-1vX1kVsthR6LXUyke0212i5226VczZIIY_ctwYCsenR4cbM6ZiJv1O7apM30oP357kxuGJ3WBxkpCsocF8NY-_lMAYgVPoio0f-JVOY9vU7F841v7k0oL8tyOYksRxwr8SlHnqASlZXaGjIRaHNW3m7vw2DyrDoY4PK4G929h1N7ngSWuyty1eG5MRNPQOuiZhBsGZ5hJxr-m1Wr7foS2NoYmhysXHBEEO96PYp2xbzobqu0PXlhmWr1v5W_5d83qs1Uc5R_xZ879YUtFMwkkIcKUIntzzI1LPnsLXF4UxhVQzefhPSb3DPNBSdo61cbUScbnXCHt-t24F6IH5q2rs-Hkb4J5DM98tgfkgxhWRFTwk2H39MPGEQzqLSn0o1BagC9QZ6ZwqQk6JvFQ8YDQUpXlqXlakPkzqzJjhdxudxzrnVcBoIS9tKpyLnxjz3TxLvpIretqAIfGY2TtV3=w1002-h532-no" width="1002" height="532" alt="Crear Windows Server Container" class="alignnone" />

Donde el parámetro _Name_ indica el nombre del Container, _ContainerImageName_ la imagen que vamos a usar para generarlo y _SwitchName_ el nombre del switch que vamos a usar.

Debemos ejecutar el cmdlet Start-Container para iniciarlo, ya que el estado final luego de crearlo es _off_.

    Start-Container -Name TP4Con
    

<img src="https://lh3.googleusercontent.com/jEbcWXdxhN8A1dx6UCwT4h4VeoFu4htk7DmSeLMh3JfVQdRS8uHvBgY6_L_GB5Lr2pcAtF85ixl0IWx-rZcoqYHQ0SvkcXrdV7aNB7yqd8buwzv0IJ5ei0TFKJ4SfdgFZRDInby5DFZDmS4_pRjSpq7Xy18nZLSBZ96Y63uAAOpbO7K_4wtoiXv0_F-ZS3e2jEUhIB6WMCJOT27m6k1IhGlnwrH_0wM2xH8xQLAV3GXY2oQEOexzuJM6jgJRoz_wpUfAyHxBf_ZzQL9oCZ3oV4wAtB7tgpCn7TG6ayspeOs-IjIY4dbJIZ5oWdKE5cnKRyyIs1p57Ia-LihxW3u2dS7RWgAFc1ZJMlWZotBuPKQDJdksQwU74BUFgvgbSMXpU48IwJ9ygW2O0UkvTAbJG4BbJz0_t9Lxj8hPxjavsKfsQdzlGOMIvbGY6n7yIE3Bqa1gg5k7vBMYEqBdEYDqFIzuRh2qUMOvt55QWDbusxbKq6OFlNu2c6jvFcWuwgncH2oT8CS0iDXA3PknwLae3T_gerE185A97nkBvbBtlRmKcxfbT9BjpayoJV6Y1ryVp5Xi=w1003-h533-no" width="1003" height="533" alt="Crear Windows Server Container" class="alignnone" />

Como sabrán, al no tener entorno gráfico, debemos gestionar la administración por medio de la consola, por lo que para conectarnos a nuestro Container nuevo, vamos a ejecutar:

    Enter-PSSession -ContainerName TP4Con -RunAsAdministrator
    

## Creando una imagen con IIS

Ahora que ya tenemos la sesión iniciada con nuestro container, vamos a modificarlo para luego generar una imagen de container. Para este ejemplo vamos a crear una imagen que contenga el rol de IIS.

Para instalar el rol de IIS en el containter, debemos usar el cmdlet _Install-WindowsFeature_.

    Install-WindowsFeature web-server
    

<img src="https://lh3.googleusercontent.com/0lCxpjSo988xFmHBWMm0QbNKQu_XBhM3Rs7iNety_2_dy-SUbI7osywrsOGPu71XbC7ps2y0Hp7dnfYNYQ1wSlDM62JWkf97YmLKEChfHde5g4kIAhTDelx3g4lL73Y-VGb7P_U-U2K3dZo0vXRPacP6YlKHV7yWldAaDcerE5oSVT42ZQdk7r35hUuBhVJ2Yk_IW3fZ_KWvZz56XWV2KRjlEfaHLyp3e2InvyzD_dcru_P9Zrs1I8KWpkITYhRGp6Pl-ftECRXz0QddfKMHJjcIScNxH3CvtC5dyl-WWkAYBtoLI7RjYkABpgqt-Ja50i-SR0UzmOjxx6yes4EtRVipoC-55xaqt8kLFBBKNcMQULOKhAN7MaWiY8x6xGKL4klwhGXRfpuPtEJuHJelYkp3axRtTSV2g48I3OUUOdNhJHKaYT06eMzwl16PmtQhGSAYFYBHx-QYFx6GYqiIo2GY-vdOFvHZCoeAl4Vsxz75uEFIFL053Yzu3uVJhLtx8JcpXpLiUs1n0mNeniFhUVBtsk9zn991WpUGLzzE5PNNvjH5i-jqVI0gn5nFgtsDnMpq=w1003-h534-no" width="1003" height="534" alt="Crear Windows Server Container" class="alignnone" />

Al finalizar la instalación debemos salir de la sesión con el container, ejecutando **_exit_**. Con esta acción vamos a volver a situarnos en el _container host_.

Después, debemos detener el container, ejecutando lo siguiente:

    Stop-Container -Name TP4Con
    

Ahora que se encuentra apagado, es posible utilizando el cmdlet _New-ContainerImage_, generar una nueva container image:

    New-ContainerImage -ContainerName TP4Con -Name WindowsServerCoreIIS -Publisher vmsilvamolina -Version 1.0
    

En el ejemplo anterior, generamos la imagen llamada WindowsServerCoreIIS, con el publisher de nombre vmsilvamolina y definiendo como 1.0, la versión de la imagen.

Si no se desea mantener la imagen original (TP4Con), esposible eliminarla ejecutando:

    Remove-Container -Name TP4Con -Force
    

Ahora tenemos en nuestro servidor, otra imagen disponible para utilizar con los containers.

### Creando el Container IIS

Vamos a crear el container con la imagen que tiene el rol de IIS instalado y luego iniciarlo:

    New-Container -Name IIS -ContainerImageName WindowsServerCoreIIS -SwitchName "Virtual Switch"
    Start-Container -Name IIS
    

<img src="https://lh3.googleusercontent.com/nL3rfu9h80UhktP4KgHydPJ-x9_1Eajre5nzwg19WhmWtohL_i8-kkq1PXfPWbe7JJ5FLrHlfCZupBkSil2tmHVEPpaaetH4w3GGm4F_HIDyOtc_cySDU8pdWfyrIy3Ql5x-ZYOAGwgZ54twgRZnNzfTir1e1fcCmyxa22srGPZh4qAAnuzXGnGb9P0zYlCrUExEO_VIErfT4XJ7taNs2L-KzNsA2IbgEsVMtmBTo_2M1zMb2ggQFyWIFOaT9w-GFsyE4Ax0WgDgWcqji78EAzz9AYC_VoHLrsHqny6L3vA8mjEWnwsIW916GUf0qiIxfmUwV163Y8tzfrJQBQYCujOa9F_XA7clYvAv7QWHQMVYGs7pMySXYI-4JvW8i-xhjFiGepxI7f6r4L7Tzmg1NqVIFPZlDsojBEj4HPR42FlZ3ZidaymmQLbuVLKs-JODjh40m-OtM3494nGmtGU8ka82oI3btj_RZcM0XSNSHIU-o96_NZZcK31mTUxVLHNUa9TnSd4KVDJVIH7KnEkPhW6z0mggmivdQ6fLXKoeYuR07--AdUd0mrj8Q0TiVlBnCcgO=w1003-h536-no" width="1003" height="536" alt="Crear Windows Server Container" class="alignnone" />

### Networking

Ahora que tenemos el container generado con el rol de IIS instalado, vamos a configurar la parte de redes, para poder acceder al container.

En este ejemplo vamos a crear una web simple, por lo que vamos a usar el puerto 80. Para poder acceder de manera externa al host, debemos mapear el puerto 80 del container host, con el puerto 80 del container que acabamos de crear. Para ello, debemos ejecutar:

    Invoke-Command -ContainerName IIS {ipconfig}
    

Con el comando anterior realizamos la ejecución del comando **_ipconfig_** dentro del container que acabamos de crear.

Ahora necesitamos ejecutar el mapeo, para realizarlo, vamos autilizar el comando:

    if (!(Get-NetNatStaticMapping | where {$_.ExternalPort -eq 80})) {
        Add-NetNatStaticMapping -NatName "ContainerNat" -Protocol TCP -ExternalIPAddress 0.0.0.0 -InternalIPAddress 172.16.0.2 -InternalPort 80 -ExternalPort 80
    }
    

<img src="https://lh3.googleusercontent.com/ezqiTvtxyatOl8bRJiAdnxMxsjcX_UdkYQa_E5aaa-fPtynByPE0NuEcf4mQtuykl06SNOAKXfqY6uNaROfFy63mt-K79mXAdkw3TW3aic23IUaJuCYVfq8IHi46-Txr_RdVu-5cV1zWjhmy3uKck8WyOvm0kHGZo2FhjLruVY_MQY-XVE_6Cv_8PVHBC-CfDoaN4kG4st_rFxaIahIRPDDjeKDnFgXyajWGKc-QqYAnLU4AAvUh0kbXcpA1AxzpUIR73rq1CM-0aeMT36cOkNKFHf8nu0zuvlV_eOZuDFE2ovFF5E6aa_AmxsL482jvoTf-swh7z7age3v37GpZf0VChdUCbHC0L2TtFeq9tKGpISuWIAssHYXO-IvjnkF8mt6vwyL5miTOs3q1vqyGKCbpOuNldfBuNUvpaLvDUFLWtIhUgMLlfq1NgAvVk1Qvo_LvUAAXpEHyRbVwBSgV-apgshTeo-t1ACijnu7RU9xaTBTcG32sicxVVpRwuAilGvvJqSjSexpl3p2VyJWEAH4ToNPo8Yk3-72GfU93ubYZGpZKejDh0UJigeXaVoumchWW=w1003-h536-no" width="1003" height="536" alt="Crear Windows Server Container" class="alignnone" />

El cmdlet **_Add-NetNatStaticMapping_** permite realizar el mapeo del puerto necesario.

Con el mapeo creado, vamos a configurar lo necesario en el Firewall, para ello:

    if (!(Get-NetFirewallRule | where {$_.Name -eq "TCP80"})) {
        New-NetFirewallRule -Name "TCP80" -DisplayName "HTTP on TCP/80" -Protocol tcp -LocalPort 80 -Action Allow -Enabled True
    }
    

<img src="https://lh3.googleusercontent.com/_BjQXZfhItRF8m_HkOkcK7TTU7ugUVM47Xo7QhhREe6pqmyzULM4QVWpob7CiazoiwVo9CAmfhUSCBXQjB6pSpyBRs9gnpP6Y9ypcd9KUEafnMtcRNuiFCzpsjCXbGq8Do6CgPIjPBQqt_J1TWetnJrP3_kugyL5pbfstcPGjeMmuyuoR9kCgPtrDcPPAF-RVzXi-xhHz4iuniui-9xJX2U5jfnX5bC4Oax0eqlfR9PIA1Qt1lF6rqGb1qKIDoiql1DYBWCUvQ6bwbB9aanpvHrX78xAl2k8ycFFxPRr30W41GxxVOm8rlc9hAOrNwlIaVTHKsD_MQfWrOPoBz79hip09s1UM3oz_MA06DYLTYsr94P_Q4wMTaQJJzRBAaCeBBel_ysegNFhrPhPsUPv9Df-xxTfAJ0RxJYmQ9L1pNiwoqzdqaqVaXhHON02ykCxAQxY-a_aSMNU8Cgbwl9u-EJee7aOI5roBPvkzpMEMbPYNoxE5dXPoPVvW8Lx28-Lcv8Pdd-_NsdM3zi0HBo4BHf5GiwZoptMujKScQrsw-zxabdzrV27w9vEjzuGqQ_mC5TL=w1003-h536-no" width="1003" height="536" alt="Crear Windows Server Container" class="alignnone" />

### Creando la aplicación "
Hola Mundo!"


En este momento, podemos ejecutar un navegador y accediendo a la IP de nuestro _container host_ vamos a poder ver lo siguiente:

<img src="https://lh3.googleusercontent.com/v9BRVvBIxOFGOMRswzXyO1Hd99yeT1Qrf2TgXeJi1sqPAznXympnlEVdluc-vOevGqIB5BbN4u4uDBU9QqZ06fq0kxDyACjbdSlg9W0e0MLfVfp5iZ6nvu38SlR57UiMvYh-eM7QBkzfmfH6eo2ku_Qnq140DW9Kmg-jY3KPMwW7H8dyjFNRHL9DxLWYMId2QIoFce7kwXu3VStMvLtQOYO4820yw8TBABVfIbX_2mk5Nbq2OOl9E08cSUzz_20CHGx4VdXIOde6ZjRuOi-ydJXU_Z_M09SGPIKp00wlqHOVWElSFCWIJESzffMbt7xMDtEg-S1AhpIQ1iRrn3GYmaBsSfSnXVnUeTp5QwfF4rOaMv2NG9L9QUJlyrrVU_Jkk6Ask2FjlQTU1su9GFV9wux4ExTnF8eKjlV3ibTPlYMdHHahj0354rPo8qWEhQjfrisB8iLoucYl7q66Wga2JEQSkU-t7tAphqH3wJ-syrbDNU9qUXTLnS4ms5V7ftMNU12RZkVM_1n57-Hbi4CCmHygz55SWmvv90eClUAoeUPPS6LSm2lKmJ7d6PvQYl5YUeH1=w730-h509-no" width="730" height="509" alt="IIS Container - Página de inicio" class="alignnone" />

La pantalla de bienvenida del IIS! Ahora que sabemos que tenemos correctamente instalado el IIS en nuestro container, vamos a realizarle un pequeño cambio, a modo de **_Hola Mundo!_**.

Lo primero que hay que hacer es iniciar una sesión con el container:

    Enter-PSSession -ContainerName IIS -RunAsAdministrator
    

Ahora podemos ejecutar lo siguiente para borrar la imagen por defecto (splash screen) que trae el IIS:

    del C:\inetpub\wwwroot\iisstart.htm
    

Y vamos a generar un archivo .html personalizado que sea nuestra "
aplicación"
:

    @" 
    <!doctype html>
    <html lang="es">
    <head>
    <meta charset="UTF-8">
    <title>Hola Mundo!</title>
    <style type="text/css">
    
    body {
        font-family: Segoe UI Light,SegoeUILightWF,Arial,Sans-Serif;
    }
    
    .encabezado {
        color: #FFFFFF;
        line-height: 40px;
        padding: 25px;
        background: #00A2F4;
    }
    
    </style>
    </head>
    <body>
    <div>
    <h1 class="encabezado"> Esto no es el clásico Hola Mundo!</h1>
    "@ > C:\inetpub\wwwroot\index.html
    

Ahora vamos a ir al navegador y vamos a presionar F5&#8230; Listo!

<img src="https://lh3.googleusercontent.com/3jb_o1I7IjWtzGFZFSWVRUwz4fUC_17SbMkxChnD83KgGWnKYqD5UZil8N2Lr3W8HzGJ5a2PrdXZsLhTaeLhxUrtBUWESaJuMwJj2L-J_XLMpRa8X1mA0mZMwoypfLvnMu9kuwWkrRTm9Kk6O2H147YbW65q0yp9Pt_CKNkx0Lhjl4V5aRZ0zWJY8sCloeAI9fEDmlUkJZSd8H1wfiDpF31kBzqa4PW_KT_Ly7mH0dWfxzMCyJ5MuA1BFYZW_OtJt2Xdt64E_1210evPj8i_yypm7rY_pkWG34TfkUT126cA69fmLL-CxD5aQu90dke6Q9hGAboLl4ZG4f5Dwo497pY3rmfUXvzv4WkQDgmFE50DVL__k8HDJ6nDB0GGrvwSlIZjrwFkvXpn1l52H1ZF8oW_U-h3yaHdTAPsot-phdEJTjbrYbQJXcVx77S9JmrpmhOXTN5kqU2L7ufJrVB02HYXGzLgHEPCZC7213o69LRlPat8FRUL8uIlDHtYAMCCk922LgQV18Wrtxa-trIRV_WFu1bNYMT0ZZO0zjXdTisT2cxbWnuZztk9qhk81OX1YlFD=w730-h509-no" width="730" height="509" alt="IIS Container - Página de inicio modificada" class="alignnone" />

Ya tenemos disponible nuestra _aplicación_.

Saludos,