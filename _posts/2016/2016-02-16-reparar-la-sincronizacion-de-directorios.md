---
title: Reparar la sincronización de directorios
date: 2016-02-16T15:54:08+00:00
author: Victor Silva
layout: post
permalink: /reparar-la-sincronizacion-de-directorios/
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";N;s:10:"author_url";N;s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";N;s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:4:"none";s:3:"url";N;}'
dsq_thread_id:
  - "4629424298"
categories:
  - Office 365
tags:
  - DirSync
  - DirSync error
  - Office 365
  - Sincronización de AD
---
## Cómo reparar la sincronización de directorios que usamos en Office 365?

Es una pregunta un poco amplia, pero quiero compartir mi experiencia y cómo prevenir esta situación. El escenario es simplemente un dominio de Active Directory sincronizado contra Office 365, el cuál se utiliza para validar las credenciales de los usuarios. En primer lugar, recibí un mail del equipo de Microsoft que me indicaba lo siguiente:

<img src="https://lh3.googleusercontent.com/SgMLfjJhU2UXKYkBCmzM8n2d00wv99Go056GoI6lYQYHiNKgX2enzWxStN6QQ1cSuO5Mvkjlc4xOrQZCvWzoP-RVj64Ifzfd1o9rTfE0EgJBZUXs_wpOrNAneqvGOmBWztEJGUmj8obUsYIvw1cjno5XbpnDY_7vRyE_93vP1OR7d9ARoMeP8QltaFJPVXBduw5E-TaWTX5vdKSdv0hkcxmue7vdQGDzQtaBxIMfj7-OH8108bLTXftMAA1Bp6GxzHRmS0IoziMpelRu8ti5LhaW_33KxDBZBFQi8FjRY8fSKADsrPHjNLU1WWT_6b2ahtnOccuHpNdn9pvksd5cyCwFWjFwH1XKaHThhAobTenNICzYKBhhgCIzMqC2Lncdj9K1Thfx5Nrfx1i30_gHpSo4YOlwYMPMcSlpiVMB3LLFU10IJ1vTp71O05bJP7bV90XUrLoJOVg_ZwrWNd2BG9DAIN3FecW86vzdCxeW61Sj_5tzIVIGrPePX3nFxRI3S12EGZ4MxRZdI57_Ias3SoxCe6vq6PfuAqpiswB8LNDKoT6Bb575d8i0gS1NPNQdLrmm=w816-h318-no" width="816" height="318" alt="Mail de Microsoft" class="alignnone" />

O sea que hace más de 24hs que no sincronizaba mi AD contra el Azure AD. Cuál sería el motivo si todo estaba funcionando correctamente hasta hace un par de días? No se hicieron cambios ni modificaciones. Entonces, lo primero que voy a hacer es acceder a la consola de Office 365, ingresando a través de [portal.office.com](https://portal.office.com).

Dentro del portal, podemos encontrar en la sección Usuarios/Usuarios activos la siguiente advertencia:

<img src="https://lh3.googleusercontent.com/ofBc6gQbwkgritjlJiWsGf3pOZ0jOQJ6A5rEWGkXDibhnSNHJIh9gdAD7KvZ1rlVuwPOukFVhVY-u5u1fXzTeEQesiDV6AkAVwa8A_jcAGKszYL9Eu72p0k6Rka6CLjzq4dUiVxESehEwuGyfSEGRo9llT9yYEqjdQTc4vE1HPOpwuHgI9L1NAhIlq-G9UVwcQKxQL9nTVcfo7O4Kpm7NPDLxgPaUxiYBqifIJNXEVddWhM0AUV6JMW-F2gJgyNv-KeXaQgoGFuj6VAxwliOPluK-yuOf_TuY1MGFFYhFYW1yc3suxYjmIR4vvlZk3mjXR4u079KqrVtBqxYUeCiLEgZ-oBsa1wMVNd7ols3HiOja7zzs1lB4rnjcNIztgd5HEuC7aQ2e1VRQS_ZfxaGkmS1V7BK9VzSRmdd21827JYsMjmT_Zop_PmWfmPj16IbJRik8VHz2CIyg8vzIUEoG78ZSXm8Yv5Z_eYa-3N9i5iz7xvCtxooO6Kwj5AP_UD9cOtUffQApebS9Ic39rdyzWUZVm_CYFQUtA-rPxm09pDgoQomlinPMIL_dSMDHUuq-wAj=w809-h259-no" width="809" height="259" alt="Advertencia desde el portal de Office 365" class="alignnone" />

Sinceramente, el asistente que indica la web no me brindó mucha ayuda (por no decir casi nada), por lo que decidí revisar el equipo que tiene el asistente de sincronización instalado.

Al abrir la **Directory Synchronization Tool (MIISClient.exe)** que se encuentra en la siguiente ruta **_C:\Program Files\Microsoft Azure AD Sync\UIShell\miisclient_**, encontramos que sepresenta un error de sincronización. O sea, que no se está sincronizando correctamente.

<img src="https://lh3.googleusercontent.com/dzEd6gaMheWo_s1c5gDlS5twF4Ju1n4oxT2Vz-AYKFOVGI_dlu_Y23rBo8rlkimcllH3pLGfoZ1YMPRWNFr2525fG77xIWGPgyxH_2_RJf1EmFAAJTOZ-GGTzGW44Rqm46cHNZmOIYXUISgsSm1s5gu2erG_2yY3WBWr2kQHbWjn_KdUUNS4v81JoCMiA4c-zkULD-9A5Uf8R5p-xq7tRJEzdWKufbgz1CzY4rOZ1lF6mBZ76Kad6YzT2CtPwCBpyYino0binyauetr0ZWtIzuPQWmI4mMSgVfx_gGWsX5C0wPNVlbC6gpLStGnmmfUJaRqRO29RLhZSKTZj71OuPZZC3ZUCpfS1VMN0bxbPxEQrZX1yWADJSVkngR8hjgxGE_C4QX330ZoJDAhjxyymYJO26EmHcq5t1qsf_P7D4_YUJq2GygjJtcOI-Nja_tXgUPHtjRarmPewycD5AaOLbDRLAnQTXXJTlWR5QsS3s-CIglurzqaP7t-Nk06bAPcsMZEeXnP_xbIraWz1SjObn31VXgrGq_sfVbTGTXYB1VdICJqeXlbkJIRF4b2eL2CMfMsC=w798-h170-no" width="798" height="170" alt="Reparar la sincronización de directorios" class="alignnone" />

Revisando la configuración del asistente, identifico la cuenta que se encarga de brindar el acceso a Office 365. Por curiosidad intento ingresar al portal&#8230; y me encuentro que la contraseña había expirado.

Realizo el cambio de contraseña, vuelvo a ejecutar el asistente&#8230; Listo! Se solucionó el problema.

<img src="https://lh3.googleusercontent.com/jvTCDLAKm3rFFjmJ5Tt3wzTxAhvCqKv7w63JP9rkVLZ_6M-HPWLabv0LFR2oZjInAlzfeCKqwzgogO29a4CQkthU9wo_zqLR70oJOZ_3bjDXbF_yoPiFGTBFjy2SNdpa4FkSY_vpJCPEwJgXBrr_saSppd31aEdaFogfu_RnESO58BZfPxYXjkzhYZhXMV0bArqUfALynOeyjeB0HTvXiUrs0jdMxPZXget9dyUTgTYfTy2ns3-x6SxJSi3YaWCHUG0Qcuz30WkgYIQnRTPQXu81jhGR4AFK5tZMI3UMBW6eMwH8D7GfIv6mJYt5O_Ego3YhX5gAwgPQULAmgk0UOYW9qqoLwNwj1IC7sJP52Cj7Ghh-HAEQ9GFBSi36sFDWQQtcewLh7iTmrJmlGaD-hXhq2_o20qlBsktl7ZaOh7YoqECRlGq_29KI-GUdjyilnb-IacUJNUv7lvUpKBf3M-KPxZLIenaSP-HxDp4wgkYls7GWOL475tknkfUuQf8w7Zc4b9O6QrVGthTr35_DC5CIciz9d4hzuEVjbMHlvcNOeol8ZygZLt6GEPjiqB-gJahS=w798-h272-no" width="798" height="272" alt="Detalle de la sincronización" class="alignnone" />

Para no pasar por este error otra vez, les recomiendo que configuren la opción de _contraseña nunca expira_ en Office 365, si lo quieren hacer por PowerShell, ya hay una entrada en el blog sobre este tema:

<http://blog.victorsilva.com.uy/office-365-y-powershell-son-amigos/>

Saludos,