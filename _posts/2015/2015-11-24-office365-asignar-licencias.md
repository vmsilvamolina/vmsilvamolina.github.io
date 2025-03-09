---
title: 'PowerShell - Office365 asignar licencias'
date: 2015-11-24T22:47:37+00:00
author: Victor Silva
layout: post
permalink: /office365-asignar-licencias/
dsq_thread_id:
  - "4488032056"
categories:
  - Office 365
tags:
  - Asignar licencias
  - Connect-MSOLService
  - Get-MsolAccountSku
  - Office365
  - PowerShell
  - Set-MSOLUser
---
A veces la disposición de la organización hace que tengamos que tener bastante flexibilidad a la hora de asignar herramientas de trabajo como Office365. Éste, gracias a los diferentes planes que ofrece ([Planes y Servicios](https://products.office.com/es-es/business/compare-office-365-for-business-plans)) para poder consumir los servicios, nos permite disponer dentro de la misma organización varios planes con diferentes sabores de servicios disponibles.

## ¿Podemos con PowerShell desde Office365 asignar licencias?

Con PowerShell podemos desde nuestra organización de Office365 asignar licencias a los usuarios correspondientes, de manera rápida, simple y organizada.

### Instalación de Windows Azure Active Directory

Primero instalar el [Microsoft Online Services Sign-in Assistant](http://go.microsoft.com/fwlink/p/?LinkId=286152)

Después el Azure [Azure AD Module for Windows PowerShell (x64)](http://go.microsoft.com/fwlink/p/?linkid=236297)

Luego de instalar estos dos módulos, estamos en condiciones de comenzar a ver como se puede desde Office365 asignar licencias.

### Asignar las licencias

Primero voy a mostrarles como está mi usuario hoy, con respecto a las licencias asignadas:

<img src="https://lh3.googleusercontent.com/69w4HDSLXSKR6gE8fYVjUkkO_HX3pnLS1_H4Q4-lp8Hjruho7fN5Nm-0LgVeFPEcqQKztANgqSET72QVDmv1AzBrh_m1Yi7GVjOHctk_8e6XPKOo5E5NMkHdHXtu0BFYf1sOHL-u6W5Am2oL3h-7WbqmT5_y_V6U-a_u02bajk9kGI_7CRrZ_LtanVtoGlFIbPpjYmXJDmn36hv37U6a1QihqpN5tIyrW1G_v1LdLsKLLE4nB4Hz5l9ZF6ijRT1X6HuhY9jv-zfcFDHvrELCpI-lRfq6r6uTJx3P3Tx1yP1-SWNcXTKQTthc9fVAvOGuhnLLO2ZSwLlPfvBErExjL8eATOhAOhOMECuZdQ1ZJzzXnhEi4G5yOK_clpcRkvxGWQBMAOrXcHwhfkJQSC5TNeu6YVXzrYygxIla11ZV00mMa2WRbwP4sLijZRGXp2pMnYMmLAO9Vl6_-cKUwRlH5avjBIqbT4WnOD8BBJJVrJ8-7WWGVHmzKtoG37ce837AvGLrusciRpky-Te6eQx2KuLFrf0lDXjtOTT5Qfw3_9o=w1124-h446-no" width="1124" height="446" alt="Licencias asignadas al usuario vmsilvamolina" class="alignnone" />

Ya con el módulo de Windows Azure Active Directory instalado, simplemente con las siguientes líneas nos conectamos:

    $Cred = Get-Credential
    Connect-MSOLService –Credential $Cred
    

Ya conectados, vamos a ejecutar el comando [Get-MsolAccountSku](https://msdn.microsoft.com/en-us/library/azure/dn194118.aspx):

    Get-MsolAccountSku
    

Este comando nos va a devolver las suscripciones y/o licencias que tenemos disponibles para utilizar, en mi caso quiero agregar al usuario vmsilvamolina, la licencia de PowerBI PRO.

Con el comando Get-MSOLUser encuentro el valor de UserPrincipalName para poder utilizarlo en el siguiente comando.

Ahora sí, para asignar la licencia ejecuto:

    Set-MsolUserLicence -AddLicense 'vmsilvamolina:POWER_BI_PRO'
    

<img src="https://lh3.googleusercontent.com/7cSUHX8u_QwuBDHpU7qjDaF7vOefBfDlAFb4cmJgfifJ_IGFXenEWWQm74qzyoiXTv-hG0W3_fa1Kmugso15DxbjMpFA8dZzy7P5-bH8SXOPnY3c3tEWII-endNYYMi5g-PYxwZAAnv5SP86K2MSnWkQoWX9fwsaO5YkcIGs1rNotmrbUP4DWEnM8HAwxg4J6FaCGKOEdpfzQT5txb3x5eMbDS2Q6VKD4awqAUsug3GlTf_webL-hrOJlS9PTT30GlPfRrzkvzG-S2_98wAaRsmYRyWUJLdzK-kmyf0P4nrwmw5fNh6lNEkiQXn9N2-h-pVWWLcyNoQHEW6dSeH32eQ2yADQKgFnrOU7Mq_pM_KLUTeF5UXvl43xQW0rMt7lTgs6OzUuzh5F8SX49zuWf-8mbNGp1R85i1TOaEukp9GoA7mN5qz1WT3dFAequTgMvQSqR5iWUaSJJLcLRGHZZOnB2WQHWvYkpvwvf9f665PlAmpHG6l3SAni434mm3voWYA49ycPwpIhSFDJTavejrc9SowArff7Fnj2V4gZSbo=w579-h334-no" width="579" height="334" alt="Office365 asignar licencias" class="alignnone" />

Y listo! Si bien este es un ejemplo con un usuario sólo, se pueden utilizar para varios tipos de suscripciones y para muchos usuarios utilizando las técnicas que ya han visto en otros post.

Así quedó la asignación de mi usuario después de ejecutar el comando anterior (tienen que creerme que es una imagen real y refleja la realidad luego de efectuar el procedimiento):

<img src="https://lh3.googleusercontent.com/WX-s_-17EIMfGc6F98-TEVP4UiPiz6XP4-n5LpSX-nvn36zRELCj78mIcZ3GqTVJ1xeOL4tQ00E4ECGSzNRxyxS4Nf_XEhqRlAh6KH_VNc-LyxmUe-u6i3ihg3ZWSN9bLnkHU5Uprcjae2ctHoPT8UU4dDmII8DkUGA6QX7rlrcVltaRs5HgkHEPRTYqN7vjpLaJX9U2Kq3_5ASBFy0PhhxmnLgC5sS9jzLtzdz0bMryzR7WrPCFGCXtAIxk_e1T34yfZ6r0KVE4sWN5-exYx7gswQmkBWqs7djHUB24MohJP1ZUgEnYlMCN9ROh-nqC2xQ4kCq78lzL-PB-QtHT-gz13X4M2QG4Nxz7gjef_Ly4MmODVcuAxnVZ66PaoIRvMEQDFs9pGf8Ng8LhOue1eyNNoCZH33t0pIqvQwuVpQ9p1TymKbXAb2ASDG8Lec0nrNYmIsPQCstEuBGB_4XjNbQTmdmlkCJritBMBsgySMOcaSxFtMHPY1jt1rUodaRyZPvBhL8mduIhmA7-h7VJO5pbYED5kIB8NfET3bdCdG4=w1124-h446-no" width="1124" height="446" alt="Licencias asignadas (post comando)" class="alignnone" />

Saludos,