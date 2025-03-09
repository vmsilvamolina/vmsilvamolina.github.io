---
title: Habilitar Bash en Windows
date: 2016-04-11T17:37:50+00:00
author: Victor Silva
layout: post
permalink: /habilitar-bash-windows/
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";s:68:"https://cdn-images-1.medium.com/fit/c/200/200/0*Sz3Js055VwE6KyPu.jpg";s:10:"author_url";s:33:"https://medium.com/@vmsilvamolina";s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";s:12:"e1d0ebf8bac8";s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:6:"public";s:3:"url";s:72:"https://medium.com/@vmsilvamolina/habilitar-bash-en-windows-e1d0ebf8bac8";}'
dsq_thread_id:
  - "4739223052"
categories:
  - Windows
tags:
  - Bash
  - Bash on Ubuntu on Windows
  - cmd
  - Habilitar bash
---
Dentro de las cosas que se presentaron en el [Build 2016](https://build.microsoft.com/), Microsoft anunció la capacidad de ejecutar la consola Bash dentro de Ubuntu en Windows. Así como suena. Bash en Ubuntu en Windows.

Esta update ha sido liberado para el Fast Ring del programa Windows Insider dentro del build 14316, encargados de recibir las últimas características de Windows 10. Esto no es una VM de Linux, son **ELF Linux Binaries** reales.

Para acceder a este build que contiene esta gran feature, lo primero que debemos hacer es "
convertirnos"
 en **Insiders** (los que todavía no lo son, obviamente). Para ellos basta con acceder a **Settings** / **Updates**.

Dentro de Updates, vamos a la sección _For Developers_ y dentro de _Use developers features_, seleccionames **_Developer Mode_**:

<img src="https://lh3.googleusercontent.com/uujgN2VlsL1Mj5lpprvAs4eM6-tftsb535HMJi66x3E4P9PoxCQuY8998ZgJ9CLzK2i0Ei_eDh0IUrad6kCiomnEDJ7qQTzUyoiNxaMaM2WKet3pUZSTvHY_UgrXtGGelA_DwtT8k33koDRQ5jIDN0n-tC-fF6KoMEUWt0zOvhqzCUG79Z6FyIem9VlXA-CY4bb3kzoz3UBqnVpGX9SDBRw6khFdggO-0zSjGypIfXYyxRYoSYcPEmLd9dcVTDadSga5DQogQ2L3gUFt4nXBzT8UHY-euRiJDM6wFGxMxYQWswrwBl33junRvF7z9oD3PuPPSVmrUmWmB2gKFCPs77WmjMTXAQdjGx5y2COpDuQ2etQJpJpQ3CnNjL21BDQxSqVKk1Rw5TCWKVLq5RspV3it9ajWQ2M20BtF2uG2Eaj_FMYxA_6ri5-MaNUo2ZAVtZONfvaC30ed5aEXbsT8rlYNeiedQnTqnyFC3VbeUNIdmDztzyftXlVgPFK2T-ocD8JClwIRRKwrKnrTpUl231zAFejyupDRCh2hURTvbYPcujBxNPasZIrExdY708B4kDDi=w825-h427-no" width="825" height="427" alt="Developer mode" class="alignnone" />

Ahora que tenemos el modo Developer activo, vamos a _Windows Update_ y dentro de la sección _Update settings_ seleccionamos _Advanced Options_ y pulsamos el botón **_Start Insider_**. Completamos los pequeños pasos hasta llegar a la siguiente imagen y seleccionar **_Fast Ring_** para obtener los últimos builds del programa Windows Insider:

<img src="https://lh3.googleusercontent.com/9xmLHRB8ozEHMxLt_XmZVQt3FTWVn1CIlWiUYjSK329AsRS87jO5ZUgcv6xFTLqp5gkbY1mCkYL-k8JN2ZubgTK8L4oozxIsvb5xmkB48Ng5MMukK4hKtEOdmB0GISkGY84aUYHFbLiXWxaLsSyQiRKs3KdgBIVLTwDcJBEBL-YflxCH0zzQ-HRbbX8CXv73ucPuqEjVOohK0cNTlvxlgKDl7G7BY33HZu3GdiJxN7J2uXX8XGMahNNsJjW16SHjYpNUUo60krmN3ZTqk9tvjEy48wLKksQcjy12DhLBjSQK0sOt5phNqZdFq-7XEMDcOSVuVWWsdKK_Xz1J3kx2UFraV9FltZFioiS3xnHK8NdH0LQuqeDUZpxCDK15h-YzjtHYF6Hz5lO7podZuY0TEvJqIrT9OyHKzV4XUfv7vDmKE_wWFClTBaMU_aJQiQgpxrGk7i0LRl7vQnMqfhULECNDhEw2-_vh6uNwpg05aIYr6f-E1M39gQyL9YmFLLas4AEeHungat5oSUuhJK4kDFAs_DtOVU33OJDDs5xnxPYdn93Tm3r0VH-kIhgWe0zteGcx=w891-h344-no" width="891" height="344" alt="Fast Ring" class="alignnone" />

Habiendo cumplido con el requerimiento, ahora tenemos que esperar que Windows Update encuentre el build y nos consulte si queremos instalarlo. Puede llegar a demorar unas horas (yo insití un par de veces y en la noche estaba pronto para instalarse).

Luego de instalarse el **build 14316**, vamos a iniciar sesión como lo hacemos normalmente. Luego del inicio de sesión vamos a _Control Panel_ / _Programs and Features_ / _Turn Windows features on or off_ y vamos a buscar Windows Subsystem for Linux (Beta) y la vamos a tildar como muestra la siguiente imagen:

<img src="https://lh3.googleusercontent.com/YoqeTF-0rpka-NDnbsPmeDPq4rR2djI-DlQOc83fJeCvPb3tESm2ofJKLs2cp6ICW_fTY4X0AHGQfdvOAy2YPbwIDVj7j1U40Hprk2B0vpZgvGTvfq4LOlHo3ofwv_Q7KAmKpjwkQc4DqdIRaxNOZzpRkQBww3JANVo0MYL2d3d-iIa6DVNX-EO6eLjCnvY5cn6MJHj_Ahpfrq5r0bPPGrF4oFjsaJByMK4m5G_662Tw0xgUO1IGQhp62HSI_zcfOyVPxr4uVMxHKHsAUzP17WBai9skaam1vSdYBLn5WpXkQzSisutI-xf1-v8n5jx-SmcPc-zC3mLA4CCWddr44yh3CRiVeZ10Kfsm16Hi-S-FDSUVjvhPBL5e_l6Q2HN6YYA0BK0ACwQJbE4zy6xptg-rL5tnz2Jev73nxk_2JrAnR5F4l3pWdt_oENUrzGbefd1XRzyNFDVITxI2Gni4QOED1_o2d8HdxY9UZhWB-Ya13ipQrLrCuNLZZBIonHGO0vF-aNqq_EN-QBNrh5ImtAYBqTGOZ823CnnQHwPT6Mf2ASUg30Hhhoi1kGci-SDizTDY=w411-h367-no" width="411" height="367" alt="Enable Windows Subsystem for Linux (Beta)" class="alignnone" />

Al finalizar la instalación vamos a iniciar una consola **cmd.exe** para pasar a ejecutar lo siguiente:

    bash
    

Al ejecutar bash, nos va a aparecer el siguiente mensaje:

<img src="https://lh3.googleusercontent.com/RKqVp7v1n52Kvom7FNJcxQVoelYX5SRIkpsxfEs2rFGqCqTTNo2UIM3lLSJot5HRROeGW6UrGNhXpZTJIB_Do91t4XFdkiDloSECVCUmVmt3_HKk7d0xsAxkASXX2XbeXyTZmgCN5yB0Etsfc590KZAjV8cXhYO1GF-WwEWbEjAN2H9btgK6NE_tUnzrFJVXwtfGOZglfORIYSZ9OtgRREiQ722N8-eKr7ObKBJ0gKTQ1cM1ox1zzWgqGrk2itK01RFLab0BcLvTQmzZZ5BCf7mFVrtpXribdgAtTknf7F5CvIaI__k5hg8xuIavDkaUV2ZRSs9_lcuxTaTw27Fl75Iy2YuG-otSXuDUyQFKJamkxdGsvL9mEdy_QMpWbVSQ-Lc56SpJDbZ4cGPglkQscpFDW-8uuSfs8Lwbp4KxAXZzV8juOhrhpsyYZGCR3BH6PtTHMTBNuJ9V8Zd3llfZKKqM0wEXWWWTw_nd8nBYN_jZwnkP_jNSYG0DNKh0wTuITzGyo9sTaaXc9_TsHIqZv0_gFMrnTSJq0viHrwmgaUKOHPlI0eS8hn1ZjKujF8201hO_=w706-h280-no" width="706" height="280" alt="bash - Instalación" class="alignnone" />

Vamos a pulsar la "
y"
 para comenzar la instalación. Si prestan atención indica que es una feature en estado _beta_.

Finalizada la instalación:

<img src="https://lh3.googleusercontent.com/FmMysfFs2_9DGX2l-OWcNoRfFsqJagrvZWv7zkVuYnm_D3dB6tLnbm0XQEh1B-kta-v1VU5JIOF3FvZof3WgjghnpUzyJ9GXiqUd4o8Slpu9wssy7vybF0AdiUhguyUiSsSm2wDkDtPHNj2Q280iyQAk5o5sgjnTpahZOYAElUv5W-jnRpFPbm0_rYMe0-1fbcqrPddQiNrnM-Z2-7Xqt9gT0XYq8zlo_Y1b7Oj-iOPuqyYWOZ5WNTKRykY7AxGrPxESyzrZWzk0Cc4DCPhZAFqefkqIA5dIugRKGdaenxqcbd2PlwPYJiRPteMtN_2o4dUR8PlSrW9VM0xGau4qCHgTkbRczsebhnCIP-YU2nkXrv_uq1215m4dkRbGsLCNKYd89qpqz-gIJ9z3oVODTINEBK7GBBp1Szz8GwFnuslZrCn8QgLTrZy8pJCEzGq_cWsYclbXxlDrqso4aetP_oKNY68587Mq003TtJ1qjhn5MuYlJWgUcuDxFdSM4VTDq8X0bDarqCBfbGw_qmGlKkJ3Ly5Lfzj_V44TapEe5_iFxMxhAIF16jz_vKqdrg2GIwza=w732-h355-no" width="732" height="355" alt="bash - Instalación completada" class="alignnone" />

Y Ahora vamos al menú de inicio y&#8230; Tarán!!!

<img src="https://lh3.googleusercontent.com/JzVVVGcRok_7naftm_S6xvFfCtIl2VUy7CeoippFkVThoUkRGeKCaAxpFtZgFZHA0_woHBoXgyl5APQNub5r3LhT9sSULavAXGm3qwjitVj1TbdVBGh9qrM2qMo9GgjfpSaNsqRiOhnh2IcmcEiubCAcSQPQS49LWPZ6ZaTPEaso2MES4WTxbqZjOu5RE2PcLa2_8DEW0KiFb8R48KcXJLJWVgrGvLHUS-bkmL1pJdOlZ0_cipU63_3h2wGyQM3yHo1FSnmQ_-1S09f7g_6So60pJRSgvtTeSGas6lJrqAZQd8vK_RfL-pWsYd9k6sEcx5goKtly1bwZUKsJAvc0FhtdWoRemL03X41CBhZbMZp66smBkSS_juby155TG_vRj0mzNSU4Yzczm4chCSKRqmqUsLhNA6K4z8UiWYn-yQDkMNq0I5XjAA0ye7Bi03Y4QseYhG1SPOi-1sg96R_TweMZJD6FaokAB9UlTO_SVZJ4WB05jyOxQq9gSLB-O_PbHjlI2Q6b6V6WH7GpV08FZH5bmf7TgQP8g2l73FFQZDo4Vho2FNL9HWIDZnfMBYK9NUAO=w239-h165-no" width="239" height="165" alt="Bash on Ubuntu on Windows" class="alignnone" />

Tenemos **bash** en Windows 10!!!!!!

Ejecutamos la consola y hacemos alguna prueba:

<img src="https://lh3.googleusercontent.com/qFs-Z8YNvhpqlDqNp9GqhES6eHeMcolruseFuy_LHQn06S1qJajeicf_f085wma8wv2-fg8OIpKNziNaRSZVJj3-zmwg4qWLcBu6KfjIFDHBSDXtzuTHYlY93uLVI2M_4oGcZXRM4U4miJxesmbTsURCfcB4ZCNdu4LUvQ0U0wbcjf1kS31DoubYh4W7y8BHITfQ-GSVYF2PeLYAY7_5yHs7gtsPiXdjuhBCoRJnQJMctnbrdY5lG4wh5_tYCrSJ712W5DPpFoiShsHLiA4Il7Y1spw4DnI6rgLJgcfUql2o0-p6OnluKTPv2GmtcwBLDfIlFTncOq9vQ56I9OgdUOmbo5ANGmApVuU5fv9Px_y3rrKOj6y0ioClYAIHOh6wwyANZNHgzzg2izr4pgFYSgJ4OeCU7I9uaDnUVUryyjrh9n2O4d9P7B41bVXhQlR4BdF9RAhZHrfOl2hYIeJwFOB43nWGsn53xuxjuc3ZnwqGjla9Ak5OjH0AZImaNjsNNVfCwomIU3YgrHhfrCpLmsO6GYpWcGoCg4nD-PP97CGfWLYEq1ZxyKE4b-WqMc-9_nhM=w977-h225-no" width="977" height="225" alt="bash commands" class="alignnone" />

Saludos,