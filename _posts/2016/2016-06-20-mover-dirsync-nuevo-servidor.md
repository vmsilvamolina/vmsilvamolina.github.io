---
title: Mover DirSync a un nuevo servidor
date: 2016-06-20T14:08:41+00:00
author: Victor Silva
layout: post
permalink: /mover-dirsync-nuevo-servidor/
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";s:68:"https://cdn-images-1.medium.com/fit/c/200/200/0*Sz3Js055VwE6KyPu.jpg";s:10:"author_url";s:33:"https://medium.com/@vmsilvamolina";s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";s:12:"59fde9f846ca";s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:6:"public";s:3:"url";s:80:"https://medium.com/@vmsilvamolina/mover-dirsync-a-un-nuevo-servidor-59fde9f846ca";}'
dsq_thread_id:
  - "5048436579"
categories:
  - Active Directory Federation Services
  - Office 365
tags:
  - Active Directory Sync Tool
  - DirSync
  - MIISClient
---
## Exportar la configuración

En el servidor que actualmente se encuentra implementado DirSync, vamos a iniciar el MIISClient (C:\Program Files\Windows Azure Active Directory Sync\SYNCBUS\Synchronization Service\UIShell\miisclient.exe) Seleccionamos **File\Export Server Configuration…**

<img src="https://lh3.googleusercontent.com/CmT0IqbQ8CFnoQ7Sd-7zzoM6D8OVg9w2Q4Kmtcfxt6RBv167xtt0138vXaICcF73KdJh39_LJ4AQgdKdE8tXGf1v2paIyh-Ia5VfZAEzbOH5n-MkeSbC7v0-TMejbtxJijLF77xj31iMWRguGStoX_AvXkoBzG-qMn8lrvpzvdyDbbWjUwcOfk9DiNjmA-eUpkdLyELjhrlJmqWRzqvPmF9WKI8-AASVbLW0LRHcj4tlX7mUhn08V79xAUHx8Hs29BU7f3zXSUbDk9bgKR1-okZBZ4DuxVnsLZfJRdhlMEeUIwBY2Dx3HVNE6MnMfqGdkuVLAQUg85T_hmy5nDvkIx1LPdAXyg80g_HE3QSGW81F-5sRo7ZBWhgbIvpq5yLwVCzwEdQKzOYYMh6mioWYDKugN1hmyM5hN8wvx1P6itrvVueHa7X4fvqWFPtgSs6fWu5TPiIDXk4v_Uw6vQCoRevxHeXM3SAMZQb6lhAMAKR7qpRO5PZThRzDwytRZezSjcyLXDRxeALDmTLlujssKC0havRH8FIzhidk-H0FG_8Od9_6XGkxzSD6gW-ZhSYv8cTfuOLNiZpcQZAkvFxFP_W9JXVqveI=w800-h374-no" width="800" height="374" alt="Mover DirSync" class="alignnone" />

Aceptamos la advertencia que nos aparece:

<img src="https://lh3.googleusercontent.com/fyW-DoRi9Xqhr4X2Q6TVasEMJqIpowM5N5znX4kmNyQZEqx5qUzy_MWT0uIeiKqMfc1zeNI1tNPcl8RT4RVd8UTSpKHakuULuwZDvE0CCA3mRt-lvgc42znE9ErmohOFXv-UVOr6WHEiNYeC8fQEnmRFLtMqTeKzq0Bhi6U6MhO9__jMk2fv8ZUYjikP6VrPjAKoKrbqjk-f1HN2UZErocTqftxDbh2KsOh3fkEVsKh1s7QuFPhczQg1704LtDIeWB6uVcWO_onBpygcAdqyC56BuSsgEv24PNk0IRVgw8AcGAoP1g0YBd6w0niNwuWl-7YhpDfLWgFNTh7SaqgJy76cBrf-VGWac-Lp_CSLzyuZRYE45MUvxw2msjR3SKMPbs0vysnXlFU2HhYhQxcFJQEC-yiOPUq9ad_ranhV1tZ-ulb2CmVzgLWOiQ2lnXbGfgdRLVqIw0Tr-JhjT6EXUZnphwrEUfOgvzG_jJV7ARPaKWJBmjceaTZPOpVR_4YYo6bGtGyba877M2fVZJPMCDlpCEyIjn6WdDQaS96u5hkYs42N-C0HqWxrJmCx4_5XMoh7GWKwVSilUtaR0seI7ynVpZMHnLk=w398-h144-no" width="398" height="144" alt="Advertencia al ejecutar la exportación" class="alignnone" />

Seleccionamos la carpeta destino donde vamos a guardar la configuración. En mi caso generé una carpeta nueva específica para guardar los archivos:

<img src="https://lh3.googleusercontent.com/lRJv6NeFUkrYtIR13da8Z0mzn2QDnKyYQI55mfYt7uyhFQnE-W8cw1FIvslEbZmLxiiXpKFmWzEFH_vNKLCbah-FJEvXOk6NUP2KWbb7EbsiDKSCIJAspZikyHQ14gtGAn8BxVAj76tWTcOWdgSAU8VoMRoOTIg4J4jfXG2YnYC8JKJFJBFHCv2LXtt8rDEFC93CVVbZrEpBG66SHwztWwJtEA8Czt4xjFCw1GzHeBeQ2Raqg16FVdTuRu5fLK1hdYyE9U_XqXYZPpK3Sw6byOErysapxQTDwQsJxLaUJsRxOUr6CiWkW-EySBlUMViQjZreaRoWGotcs5usMpdMXDJUe2EN90g_ZfI5WNbxICIZTTziBX4KFON3KfsdTWrR9rVUgTsRZZps0nlK5IL0HvW3__wvfOKWAV2xf2doEj9kG5fBK9eplmMg5DCNM9P_q_gxfd14ATpjG46d5QzdGTnM6l-VU0SrkabPu66-jw7_khh8Kk5aUN927sPCGawynkLz9uA3CLK5iVxYBgUv1Q2lQ0v5TX8EezWEy3mdyejjSgrm0MI1A4TLnI36KREUSgDLTVt_9XM5FiHy0_FoEPpFCSS2Dp8=w325-h315-no" width="325" height="315" alt="Carpeta destino" class="alignnone" />

Y el asistente va a comenzar a exporta la configuración. Si todo va bien, vamos a recibir un mensaje como este:

<img src="https://lh3.googleusercontent.com/YTiwcNYxFqkg8mxNYE6G69kSdL5RrFDyMgKWA6OolAikGD2EYju-F2jN-ALgqBqavkSfQTODjOdfZDBjIoffKSqMFnR5IPz3_XWxkFHyrkSbpf2cNErWRetDMFcf73nSYHDn4vBu6PVFNI6EdJCgicrm5UGud4i9G6K2AEukT21qd5YjhQmM2frLs0a5YLxPTWhYA8rPjB_dtaC3_zlm3m5XNoETaRPPo5881CK2jH5tGVev1WaGx7McLzXSnAhSh3g8-Pzhud7MUALs5_HiXgmXpPhgFq_5Jf_7GZTxFuToWCWltgo3WFJhm14pkrtF3mabAO7RZm6ET0Y1-LEBYjwkpenAhyoaQmpaXFaf-FzyX-KIIpjfHOJ2yDArjRYQM9kP9gdbcJtEfu7AoJeaubTHLqUjTxSwDkUZXQIlokFttovM4l0PIXIbFORWBtvKotJZ7NT0eVQT6b8amFVj24H5ES0x5D9o6Md60ZJz-ZN77Zcxawr5TDH8TMom8stOEJTQ05pF088JASk7kW3Bx-rDsKsu-wjQAs1y6Hh1dbaFefz5GzbLZXS4qfPPWdupFnuU_ZQyU73CVMKiM391Y1wc__54c-A=w610-h480-no" width="610" height="480" alt="Exportación realizada con éxito" class="alignnone" />

## Preparación del usuario de dominio

Vamos a ir a nuestra consola de Active Directory (dsa.msc) y vamos a buscar el usuario que comienza con **_MSOL__**, ya que más adelante vamos a necesitarlo. También tenemos que tener en cuenta un usuario local existente en el servidor que actualmente realiza la sincronización del directorio. En la siguiente imagen se muestran ambos usuarios:

<img src="https://lh3.googleusercontent.com/PNKj-sJ2piKT92uQ0vJQVcupItwP_YSxluE8jOKI0hvyFG_17JP0WebbgNtUDPRX4SgQKGo2hbEEY3H0Fg-oztY0D9hTa99WYIpjgsMdp702V7d91E4HFItS6D-_Ny4bfg4TzBTrOJiEjwvHZRgKOrGgEIM4I4UHWxTSOkp8Zwt9R2QpNhGeh9Tz9HQG6LVDM42AIAui4mCm0B1VAMBluP14YpmeziwBsosOoz9_9NqC3qpES1yW0Tw9yI8uEr3wrbzQKQ7ISNhEwQ2-aviKuNRII2VTtCJ9igTnkUS7uY85GE38HWG-4DIMUfkeaBBMf9KSXxiR0QL41p0hycr092bLnZj62ox2qw-SAGUvGvcoam7VbT4ztqVGoxhQNQec0LQ8fVSPog3l0yYlW7cTAmFoaro4CvJeRIOqrSPeMYtczfipVEhJzy69kczRN5fPEfpN5HgpeyjNDIuvKXf7kM7SYyVjfDHLwuVuqgl0Gf3boKgU3IO-VlCePI6l0ErGlBJyYqTKecHMfTRyehxaDU2Y4rpbCFfsOPe8IrTQAPR2DQI5bL4YzNEHmLfs6zQry3wOolkbtqnKFG62sV8rkUFHfvPV5SQ=w475-h169-no" width="475" height="169" alt="Usuarios" class="alignnone" />

Vamos a tomar nota de ambos usuarios y vamos a cambiarle la contraseña al usuario de dominio desde la consola de Active Directory. Ésto último solamente si no tenemos en conocimiento cual es la clave del usuario **MSOL_XXXX**

## Instalación de DirSync

Ahora estamos en condiciones de iniciar la instalación en el nuevo servidor destinado a tener el rol de DirSync. Vamos a realizar la instalación, pero **_no vamos a ejecutar el la sincronización_** ya que se deben hacer pasos posteriores al proceso.

<img src="https://lh3.googleusercontent.com/yosJ_1nyDuJPjJnutMJv0ma39RE1ZpGRX-jvOqt65KqtgKv-4jV9cU3MO3dQn71WEpYD1jJqFKI3GaK5szoHLMFi1wQmzLYxcrm_8fByffIAIxhHn-yccrOPRVfB0tS3KD6gQRTB7O_4BLLnAUjLXDhfYYBa_26yNgRw0ydQCVvhhZ4-n6KO4iWPb6Ktih9rXkjpCDJ14FRZftKYiIR83t7EVI-ndEngk-m7cPCvIzCIJX37muJYO0EbL2Iiw6SOqR9unXXoZI2ByWC5w0RYPfFqkUIEZZOMEM2qmg1LzF_BmPpXnSIzu_Hn6UEg0Ls5NBgZ5AKKgzyyjZbkTDXXM4mooaodIfWnQA65bfyh8NtB7cxdvKfRKnaf4V4puXmVyqdT2H-QnJ7Qb53d1TTRgmyK6U69B27cgaH1STzfNR-dh0HAHOo052edaC4UZXJPeHIPX0-5F3efzOytfofFqil4v5Nu3auVXCeIDRM9iHmwAO80ziKqgPw2F7Jjb8txsGCxksw9s_79FbRGKH0fsetZ7iAJZPO4A1p3uyhjwdnAHztB7HVTzLJHe72bWYZUXzLNGrvSoKFKtsdw547mPT37jheB2do=w621-h446-no" width="621" height="446" alt="Instalación de DirSync" class="alignnone" />

<img src="https://lh3.googleusercontent.com/tbL1Wfw4gIvLpGokWGygZkz4JcR6ULa6rMKTtVj8kaDs3WzAwwlmUJumcC4bMk8g1IsgOkrVJerbSInorsW6HPq73AQ-TNnivJUAKzykL5H4eN4VaZNy8ucZGxRvIAhrdNVHXaPpWAb_XTPCbHeDyY1agGTfotZnteJUlOwH2HGmgiwhAs2kkCQfo28OjJuFheBaFqNNlfS4C-vCVt6adCSxZdR7aINz2O-sx4QFb2EXtyzQ_uAZ4bHffuR0A9_lRp5hds4zMK77SdnJHDI9K87pm4TOMZN8vXaIOTCOGxJXoJJ18ewcpG2nta-Hh-PjK4kbpaiuRFMRijbErHwCOHCP_ossG75rSkgrU6Xvl1lw9w0xBJUyJY6ArCG6DAdfpFVUpJ781hb0J5hCflbJ-op145ZJyiNVqY96ogB2EgGui0EfgPoAPYZ4iurBd1f00BGO22dTbAzW-ALnh9WjtRMdEQjtOeNR7lvswVcxU7mm_V0oHx0JpW_ijg60lDohB4iDZj_ShoBbAxTs1jxt2b5NBU9HG3QBqqCXk4Bvcuab9De-rJM2DrpBfXs5togsNe9ef6U5IfUHaEX2aiZ6fX9_NhyNLzY=w621-h446-no" width="621" height="446" alt="Instalación de DirSync" class="alignnone" />

<img src="https://lh3.googleusercontent.com/hnHspKBlY379THvyJeNd7M0vZpQZSVqnsVb6VfSm869GP_2I_QSSLPM0p2YG0Q3kadvUFxEjqHvSdj4B490KDJLZJCT86KUK4W3HuEMTiubo5o94rOAkSm4qQT5I0vhCuQEzkpjpBOp3Hm9-ndxhLh07g3R_MnyNR2TZ_dBjjgmrzSkbUCAen1A6VoeGtK7aQr0yACSBFniOkiWidUegeIGt6t5IZO-8JEHTq0F4AOP4neFwsNTAU61NL7jB93XYYKqgOOisIL4bYrIMfK9hnO1g1oAZFt4LlTaYD74XKmqvrgxWjy6LtP2X2_bPCnRieWN0dhli24htRipOTuiZG31oe_ltT3RFQTK_L2PQ_oecRFOP2QwoPJ6IkFGJaYPFk4tRC8uCpQALYAje1Db-uEmtuH8DJWlPhnkAQEuaCZxjwWYR0FcP5hO5z98Pi3MJyGsuBjYapGnEZL6H91YD_SJfwEyJF0erYozGEC6rFH-kn6kT5oWNfsLX1nClrVQMNF15A3PRyppDPaIRfkXwEORY8w17To3Qcu9V440BbLR_upBJQfIxwtvl4LtftUsFKavw8eFr5HFoJWm2mgudRJyX8I6XCEg=w621-h446-no" width="621" height="446" alt="Instalación de DirSync" class="alignnone" />

Luego de completar el ingreso de las credenciales de Office 365 y Active Directory, respectivamente, vamos a esperar la finalización de la configuración del asistente:

<img src="https://lh3.googleusercontent.com/hQqkw34ETVsRxKVLS4LoHLR6DH2ifSiiOoJPjBb9UXZo3zVlBPM2HyZxagi2-d6QFw7vQW0KnBZnCrh1aClRWKsVJQGfjveD_t-tNOBfKQhTX_lFK4s607McY8GVKj2LW1wJAHi2OrQbDaH-qJRiPMKGFuFgdTRCUkJDMcV7YXpo52piJoK1C_4n3Kks45judtWl-xwrkmRHCHvX2nIifqjiFRciM-8itAMoblt1n3ML7a6Q1rLjgHgnKbREE_bFUxuQIJtyZWfc5Rae8lvg6qYyfhiqVW0LmwYpYmQ3W2ANLwh9MtX9xRHrTcS_5NGqpO56hI5faNTolhZ_jRIIX6zJrtlebJNnf5CE3koVn86YHKDpe6WZV7veKD4lZnTXYH-tVzfakSnmCAniQWXusG8hHwerouEW7CIs_2NCpdeDSuhdUkSPDWCnkWp2Fovib-znBeao9su3SJZbSqG2YqkLyt8T0Bm2vnt2PTSpngFmYwtdLd08cpthIzPSLsshJ_k7orpn9XWDIqCLArZT7b_ut6D5J0N9G7sAlVRNmO41GcjVIxHAgrbFLEjHsdD3KZ3WMXmxJxeGceyKdLH-dEfEephKf9E=w621-h446-no" width="621" height="446" alt="Instalación de DirSync" class="alignnone" />

> Desmarcar la opción **Sincronizar directorios ahora**

<img src="https://lh3.googleusercontent.com/1IuoYCURJOLWNjYqDDDEFhRct5-JsdtXarbqgC6YXxGCGwVAGh31ba-tDZdTnlOkueCBdwtUtC31oiEXpFSUcWAAqEI9fjrhOy3fPE1u2U2sXchsWLFTlcLoy3RauevuohcD0cVq3S2TZLHrdDoahd9JcZOn4IjeFsPKzCea8CirHM6GNESW_N8YxiHfrTBps2LR4Jq6nlNYpaM2DjBGZoymzx6jvZ8Baril35ppwBCDOjYYCGC6NhPUyGt19pMkRFy8uhKqkQ512WcsjdSo_hKrUrFHSxL2RLvv5Br6UhQIMU2CuVxCzLfJqKIQEm6wBiTWgfSYT3WXfgr6mnV6HP40d03x-bgGF9S2dBT1rSzMmccXo69sP-Ly4SUPcSA_Nt0YvYkIiJYzHwz002cEAPS6JlyqYuazG_mM1H48ioo8U2iDWzVnKoDO1d7U7V9ZPGIWYlUEhm7TtHYvKagPkQK8UcT0Obs6881JLW7NIp4NTIQjWuXM1Un_01yAEcWY44FnTmevQvQvVUqTVrxBc416F8cTisvDBZvzVElWzb5MqOrb3PZsnR3Uj2BRO3Uf_aYDnDeaXkab3TJkCVg1m0ejPJlnqXg=w621-h446-no" width="621" height="446" alt="Instalación de DirSync" class="alignnone" />

## Detener el DirSync a reemplazar

Ubicados en el servidor original, vamos a detener el servicio de Windows: **Windows Azure Active Directory Sync Service**

<img src="https://lh3.googleusercontent.com/dqeppQY0tQZDJY2vrZY0b_pvL5BI6q2ejdZCX1rbyvcTdwtWEWGlQ8rLevNk3irynTDBPS3nE5uat1T19taP8rpWpA1EL8Y2lbSmA7AhktkndCiIq2GuhUN_3b07f3HfRpWQm7w58dC1jgq3q58TyqSNuDC_wE8oHPAD7KwCq_j-VApeHmG7eQcvbhaEBPqx7TUZ5RfYpYNldShWPHKkihtHapp-Sbz5dd2TIDgGougBiuae5XyPUI4B3nm7amBHSLqt0-CChcjhOp3pyO79yqnTO4sCyE16PaN5tFL4P3AUjS4QuwXDgtq5qg9GmOgmN31uH90lTPXCG1zUERLH2Dh_diucnZ4n6vWemEeJ-BJP25oOZKdvKFx4FXmsiY7ZDzDYQDX6W-0Z1Vqz0D83cRK11judEmN99uo1b4ZJRfC2QFw4tFcJ75gD2mKPVco6r5_CXF2GtJ9_L8x4EAaQ6f8L6Pb5mxH3qMgtfg0B9l-R2U27f0QDvCBhsrSJHQ2f0cXwzd-uIEmwLFcRLuSP5k8LqGgUbcrk5MPq4bv2iH8u-UQ2YIpQrUNjZPAAAQxBeCz3oFFI6YmFLzlSKQMuMYMs3K9IOgg=w850-h110-no" width="850" height="110" alt="Detener el servicio de DirSync" class="alignnone" />

## Importar configuración en el nuevo servidor

Volvemos a nuestro nuevo servidor, para importar la configuración. Vamos a copiar la carpeta desde el servidor original y vamos a iniciar el **_MIISClient_** recién instalado 🙂

Si al intentar ejecutar el _miisclient.exe_ les aparece el siguiente error:

<img src="https://lh3.googleusercontent.com/76i1UA22PXUgtLSatbe9w4Qj1SilD5-R4GtivUnLoiqp--SLdUcx9wdjYGXm0rYoSLrUHih7vT8j328zMwof027ZvHJQ9pY4Q9esGLQSUdOw88dxt-jxhaIe_XWK23cGmQfwOQ4xSZBSZdVfIfARnII0BaStUrycBJ7XDVq6X6dsNb7tyLu6FPpTcw0Htpj-nPnHFp191TjCPJyCha3yiYnpudHcJemifnNL9HlMizlbyqt1p_oYZWQ-3dx-omZR3WR9_T-daLcSuzpUeKF941bIVMqd8IyfovEX5NG2hnU4qICtxe5gBEvMmiwK6s9K3fXHltMTCb3FupTbV4hkjErOyH2FgjLBowv5k2rsSIfeyqI1ZM0G4UknPEi2jLO1pd6QePYB-CyxEiWk4Qe0ff_8Tl_8_ynUwU-IGTztmDVYWqJyrsKyIcnBbxf_mj0zX2aWqzHIwNUhek_7kVXg9_hM8iLcjkrMpxBeiIXwUKhFDKft3-fbHyuST_F-uDeks58elU5ClyA7jWIqLmEyZ7Urmw1HSMjY6D0X7sB4le-ixoBWmPfGMSqaspAkkUBjoaHmDPn2p_t8KEXXJfnx1DlOssxZ6u8=w520-h352-no" width="520" height="352" alt="Error al iniciar DirSync" class="alignnone" />

Debemos ir a la **Administración de equipos \ Usuario y grupos locales** y crear un grupo llamado **_MIISAdmins_**, donde vamos a agregar nuestro usuario (el que usamos durante todo el procedimiento):

<img src="https://lh3.googleusercontent.com/mRqmHRvT4XILP4vNqDqZiM2SHTyP_hEa9DRk--wNjrHqJN-wlcjn3vSDyWzQQjj5Npp19DFyflkEy6m7iDysIrk9rIij6g2miBteWmj8SsvTUQ1cnRWxxUg124LnqkEkb79XLiRXKT3vDWaZzL4I4jlxXlCGXHx7nyD6B63x4Pjt4UklA5y4WftF1KLrGyf7iaRDCr7MhACWS98h1GCyTrU5LeeV-fuohMeK2HYEyR1k5IVqrfA2kqaMX1exqfLts-1MiIpxRAE0ImaaBRh7pUjS0SVGnMtFzjWLKW6D2PXZpZmC73UZ43Ahx5MEnDKAYAUEvOlsrlTzsccLWogSv_E652_h6_HfdxwTNBYJ2rRg4_flgdRbdUVQBSGlODJH_KJdnte4iieAKtLUk3aAYk3mKsa1fAt3y_WUucWxhHs7hO8GSmX7g1GZSwG2wZYhIfvNcFTOwTlLjgt1I3fhXycwSXPn3D5mr52vb3N8NuHuVIbY8NZraAp_F1CTA1SbEFkxx2Zy8n6cfK0qkWsRPgY9JnMdDteSOpH_JbJlGgEs6FRopo-sYi7lzjpLJ27ZBg8yIsP41UUjd3GlrZgPsPLPvhNiNjM=w430-h393-no" width="430" height="393" alt="Grupo MIISAdmins" class="alignnone" />

Cerramos sesión en el servidor e iniciamos de nuevo, para que el token de seguridad surta efecto dentro del grupo creado.

Ahora vamos a importar la configuración correspondiente:

<img src="https://lh3.googleusercontent.com/IGFVEoiTM8ymFGMJ51qhHlbyFLxZkVknF_umDoC0sSRuI7ZbeE_8UqBBlsP4EueNxGzDD_GVVwPucWU6AUMzGQ9EcREpwjIZ7JK8fm-usDcMrREGWNyt5aHUEo2x8VQWS58-QC48XU7sh_vvvB8BAbxngRQd0Vk0JWhpHBTIlWuS_ezXKDFoLGuisx0K90VUyoojE9c734fsnoRnHfl-DwEK_sToZA43ErVKeZRUm9yuv6WJ6Velv4bVJe19a01zT23k60lwytqOMcttUMSlSQSmtSWiG1M45T8yu3oLEQSXgsWgEY813HWwNI-e5XQ3ENIYdkravnHJ0cpiCqwWK7wRxiqkKr4Ku-BfyZbIYlTyTcd2eumq-2F0-aAr3TDDDagzxfhp6gH9eAo2E8Ek5Y7OPRH2BpDsa6TV_QRq8CZD6pICLRQhBWznUCsRH728lp-XemXAjcYzl-VP3AMqoPQdsmlh-zlY0hjrTNQXLZc9NQem51mCSURZJSfUqkmWTvFMNNobtRXpold7nW-30LurY4X8fpaOy8XfdiYKloL_EOnw2tPZa8qzy8qyyLGt2TDfCfUig7XEClRaenlksW0Cat4hu00=w808-h186-no" width="808" height="186" alt="Importar configuración de DirSync" class="alignnone" />

Aceptamos la advertencia y elegimos la carpeta que ya copiamos anteriormente.

Va a comenzar la importación, pero nos va a pedir la contraseña del usuario **MSOL_XXXX** (que conocemos 🙂 porque la cambiamos antes de empezar):

<img src="https://lh3.googleusercontent.com/YY9Rakx-7IKMzvQhe8h50nRaW2qX5NBJlM_qAeQHaiLCB4T9BJAph42tLT6tsw-PImEJtKfN9hT9VpdE0SvnqgaZboZebYt9I52uCDCSdwei8AJ2hTE_MVpsGghZdRXH0fO2A1NAoOlUv1CK5Whd0QA2J1jJ_el61l_2059s-TJWiVBCM4WAiK2zjgg9OCloBVXK23NBwSus3ygEhA4HThUnFSgcfCuaVMi1ri041_YFCAAjRNhh_vqfqW3bYTknMuuajl8oZhlhygQlSE6PUNMycy-qlHh0tdBHUNmt8iWjJJtU-wbHxmJgNYnGLI2hcnQIblK_YM-zVoZfBq8BKMHHkK-yqZpWLb-bsD6XNgNUHlex2oHvHu8DMVwnaqPMLk8xt5pZXFalTmV05SEEzcSM8bRBSkpgrxXvHOzUVBuTA62goCL85c0K5ltrWpGip0bavCK8bKbVGp8U6oDw9pid1aTB4gBA-xpQNr3gAgZEUcoSbiJcMvRalavdMWo3ZFj1Q7cZybKLBz6_7UJpwzCcyD67Uok4nK7bHdQgA_1h-xumpMMHERbY8rZ4uGymVg-DL9egZLJpy6I1yaBXDPGkqR3LYiI=w818-h490-no" width="818" height="490" alt="Credenciales del usuario MSOL ya existente" class="alignnone" />

## Sincronización

Finalizada la importación de la configuración vamos a ejecutar la sincronización en nuestro servidor a estrenar. Vamos realizar los mismos pasos que ejecutamos al instalar el asistente, pero esta vez vamos a marcar la opción **Sincronizar directorios ahora**

Luego de realizado lo anterior vamos a poder comprobar desde la consol de **Office 365** o desde el **miisclient.exe** que se ha realizado correctamente la sincronización del directorio desde nuestro servidor nuevo.

Happy scripting!
