---
title: ADFS Multidominio
date: 2016-06-25T15:34:32+00:00
author: Victor Silva
layout: post
permalink: /adfs-multidominio/
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";s:68:"https://cdn-images-1.medium.com/fit/c/200/200/0*Sz3Js055VwE6KyPu.jpg";s:10:"author_url";s:33:"https://medium.com/@vmsilvamolina";s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";s:12:"ef251e02c17e";s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:6:"public";s:3:"url";s:64:"https://medium.com/@vmsilvamolina/adfs-multidominio-ef251e02c17e";}'
dsq_thread_id:
  - "4983959959"
categories:
  - Active Directory Federation Services
  - Office 365
  - PowerShell
tags:
  - ADFS
  - ADFS MultiDomain
  - Convert-MsolDomainToFederated
  - PowerShell
  - Update-MsolFederatedDomain
---
Configurar ADFS Multidominio es más sencillo de lo que parece realmente! Bastan unos simples pasos para poder tener todo configurado y funcionando.

## Sufijo y Dominio en Office 365

A nuestro Active Directory vamos a agregarle el sufijo del dominio que queremos agregar. Para ello vamos a ir a la consola **Active Directory Domains and Trusts**:

<img src="https://lh3.googleusercontent.com/Wd_c8OdZxDvOLlhSWCALO-2iEQEXgYaX4a11N1s8v6SzG5Wn_PkDzNWGY-OUobz44lgQEnjXe9obrsbvPmfs47CtExTxOhozYn1zpuxuUKyJ43lnF-8GiZsfUOYjtMQUTRkc_jrw3qgmQiqmQZpVMyvouJfCMyC_ZfOalhSzAHUBou85rtnT5Fak7FfckmuEmIRr2t3vvLxRT3Dbyb0U9L5OqMlKitYHNvygUkSw9K1z-0ic1PsqRlmxQZKDCXAJqlGmsie45cO1tZ0racxgJ0WiZqEU7GjY-xuACM31wZyb5LiAgHm_La06k1NyJRbzLLyiDBOrKZJ4zNvmsyhxoJ5SquiiEyO0h0IDivCOi8vwnyBMDEbmfERlEht1RH3PxhJ99Y5aJJd_N6p-V7RgHHfuJrLR2-Mn5mp06ptcJvUpseXCaxmezVQVTSIEe-6U7Rn5vpp5ycfUfENDb9eaS8nwWqK8QnH_-ZXbjztScd2vV5AP4yrU7rYBxr_gm6v9y0PICrLECkBOQf_JjF7trRS-4C2bfeZ_g0_wE2FEak_c6Lj9Jig9IWAgkwvkzkuCfbCMKHzKlZTUDCZMFa0VyxynmpXtV8k=w413-h462-no" width="413" height="462" alt="Sufijo de Active Directory" class="alignnone" />

Posteriormente tendremos que agregar el dominio a nuestra organización de Office 365. Para agregar un dominio a Office 365 simplemente debemos ingresar a la sección de **Configuración \ Dominios** y luego seguir el procedimiento.

Para poder agregar un segundo dominio soportado en nuestro portal STS (Security Token Service) de ADFS, tenemos que hacer un simples pasos de configuración.

## Módulos de PowerShell

Como primer requisito debemos tener instalados los siguientes módulos:

  * [Microsoft Online Services Sign-In Assistant for IT Professionals RTW](http://go.microsoft.com/fwlink/?LinkID=286152) 
  * [Azure Active Directory Module for Windows PowerShell (64-bit version)](http://go.microsoft.com/fwlink/p/?linkid=236297)

Luego de completar la instalación de ambos módulos, vamos a comenzar con la configuración en el servidor de ADFS

## Configuración en ADFS

Comenzamos accediendo a la consola de **Active Directory Federation Services**, y eliminamos la confianza **_Microsoft Office 365 Identity Platform_**:

<img src="https://lh3.googleusercontent.com/H-VUym-s0LkPq6niFMiKoQopwiNBWUuqc8OJeEB3KB0duQhnJnWBl1uxEssMmO734XrwoGdiSkF26h8F5u1917VM4KTmDnKeGGdmXx9XhBSNv8m8bFDEYUzGMp3TqsFspdRMtlyoAbOJKpW8K_4TmtTf9wzAe3D-HQIf-2c6UFl88jsp7_nt0zj87yBuhglkpNMA9HqH2gBJLr97kl4AB3EIFfaQ00GxDIu6Ch1F0568WewIilykyLN1SRfdtmVf1IB6T1yWQw7ACE3xHKl8HFa_sfOT945sFtiFNy9miVi8pMR7qwgtrSU-xEnA0nF0_9djmCM0UoFeBJ3_rYtA_5xgaXMDtWfW5TdwTkmZlsscMx4zhQ_CH28-lWjfXTZyqt6GaUqFwfAV8gskhJQKRnu9r5euktwn0cCqBTHgezF5nO8GpycoiUbA8oMMRezFJCda8kDuhiwVSS5bfP0Z5zcqME8WKXWncZKcUNsyVMdgwvZvHAj2mOsL9tp9RCQ_UnJjnax6Bm7OzU9eu3VzmNK7IRlEs1blEJxgn0qJCUulZeP1-9AwO6lQ8S9boBqXYRtynl9pPlIa9aXKJFVkCo2OFV_HjmA=w895-h329-no" width="895" height="329" alt="Eliminar Microsoft Office 365 Identity Platform" class="alignnone" />

Posteriormente vamos a ejecutar la consola de Azure PowerShell y vamos a ejecutar:

{% highlight posh%}
  Connect-MsolService
{% endhighlight %}
    
Y después de lo anterior, resta ejecutar:

{% highlight posh%}
  Convert-MsolDomainToFederated -DomainName "dominio1.com" -SupportMultipleDomain
  Update-MsolFederatedDomain -DomainName "dominio1.com" -SupportMultipleDomain
  Convert-MsolDomainToFederated -DomainName "dominio2.com" -SupportMultipleDomain
  Update-MsolFederatedDomain -DomainName "dominio2.com" -SupportMultipleDomain
{% endhighlight %}
    
Donde **_dominio1.com_** es el dominio que ya se encontraba configurado dentro de ADFS y Office365. El **_dominio2.com_** es el segundo dominio que queremos agregar para que esté soportado dentro de nuestro portal de ADFS.

Happy scripting!