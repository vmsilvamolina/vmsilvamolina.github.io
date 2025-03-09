---
title: 'Chef y Azure'
date: 2016-01-15T19:30:39+00:00
author: Victor Silva
layout: post
permalink: /chef-y-azure/
dsq_thread_id:
  - "4527838006"
medium_post:
  - 'O:11:"Medium_Post":9:{s:16:"author_image_url";s:68:"https://cdn-images-1.medium.com/fit/c/200/200/0*Sz3Js055VwE6KyPu.jpg";s:10:"author_url";s:33:"https://medium.com/@vmsilvamolina";s:10:"cross_link";s:2:"no";s:2:"id";s:12:"24a6d83e1bfa";s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:6:"public";s:3:"url";s:59:"https://medium.com/@vmsilvamolina/chef-y-azure-24a6d83e1bfa";}'
categories:
  - Azure
  - DevOps
tags:
  - Azure
  - Chef
  - Chef Server
  - Chef y Azure
  - DevOps
---
# Chef, qué es?

Para los que pensaban que Chef y Azure no tenian conexión alguna en este nuevo mundo que está imponiendo el término _DevOps_, les comento que se pueden hacer muchas cosas utilizando ambas herramientas, obteniendo el mejor potencial de cada una.

_Chef_ es una plataforma de automatización, de gran alcance, que transforma infraestructura compleja en código. Ya sea que esté operativo en la nube, on-premises, o híbrido, Chef automatiza cómo se configuran, implementan y administran las aplicaciones a través de la red, sin importar el tamaño de las mismas.

## Forma de trabajo

En primer lugar el ciclo de funcionamiento de Chef lo desencadena el usuario escribiendo "
recetas"
 que especifican como Chef gestiona las aplicaciones de servidor y los servicios (como IIS, SQL, etc.), y de que manera se pretenden configurar.

Estas recetas, que pueden agruparse para facilitar la gestión en **_cookbooks_** (libros de cocina), describen una serie de instrucciones que deben ejecutarse: que paquetes se deben instalar, que servicios deben estar en ejecución, o que archivos tienen que ser modificados. Todas estas instrucciones diversas pueden configurarse para versiones específicas de software y pueden asegurar que el software va a estar instalado de forma correcta, basado en las dependencias establecidas.

# Requisitos

Vamos a comenzar a detallar que vamos a necesitar para estos ejemplos:

**Azure**: Obviamente vamos a tener que tener una suscripción de Azure para poder utilizar. En caso de que no tengan ninguna, accediendo al siguiente enlace pueden crear una _trial_.

**Text Editor**: Un editor de texto que ustedes prefieran (VS Code, Atom, Sublime, Notepad++, etc).

**PuTTTY**: Cliente SSH y Telnet para Windows.

# Environment setup

En esta parte del ejemplo vamos a detallar como obtener un Chef server desde Azure y cómo descargar algunas de las herramientas para poder comenzar a trabajar con chef y Azure.

Comenzaremos accediendo al portal de Azure (<http://portal.azure.com/>).

Para crear el servidor de Chef desde Azure, vamos a **+New** e ingresar en el cuadro de busqueda: **Chef Server 12, BYOL**, para después seleccionar el resultado:

<img src="https://lh3.googleusercontent.com/vMBPjD8TUFEBx7iLVQFmS7G25l-fVBXH47JTL_TJZeBFaAxTxsM1YzeJOflXpMYxK5V9yHFYZ1E6qoQa1HT_a5ByGtAqX-1uW1hfPhHul-fOv4ZoUXbRVGvaJAPy2z-1ySLfTha60ihyaMMmYEDMf8o1hYPW7_OzO3fVuik2wX8CYRdAItX7l41LCrMzLjUkcoGIHh0PnkrnLMh1NhtqOZqIjJSSgZZJadEUuw1CKeAQpCWecV_JnfEbeGZNaFvnzldG4e9DLLbOcUfkcFUOunZm65IKzhe-JshtZqDD1ya6ajSqihnzcgTt-sWLFmDVWLYDuA6mf9i91rX5XtSnRDTLXkrstEBd2a9DKLa0ekIKh5_F8r5hkUV97DjKRmNJKZ1NDI65Ycb5JSegS1XTlpObJgOL1DtDHGGal2cXXUzof9XphYvw8eWvw4QNP-cgPpbVVXhy4JTX8vKNxRb2BIh-_Kf0CwSmAT_qyV8mg50QbAbp9vCitOW49_-r-q3KV_c2lC4h3WUWLDDl-CKWdBLr5oMUPUgxFz3OOS5r7QXLbJY1PXIwyV9bChcDJyMLlmE5=w894-h404-no" width="894" height="404" alt="Portal Azure - Chef Server" class="alignnone" />

Luego seleccionar el modo **Classic**, y por último **Create**:

<img src="https://lh3.googleusercontent.com/cvgQAMSUb59_6LADCmHqczcPRZOtQ5M8Glu96jQnF6-HCveSpuUyBhLi-wsj0SzNGqwIngQrlt84pOuy22dZpnWCY9JDLBWQyWhim9RtEMZaGlasod_-3AJS0eTo0ftVePnqYQtc_6TvncDRQDD39OoVda_txJ6LFjcTFhtjQjnC7pU4GkXqIC83B5dqJNcYoY6FukuAfOo5vhZNM3Aij3l_Dio51A92_r9m4gqx2cFTMFohDFciHE4XL3IGyJw76vNcxbDv88h2esbU1ihwpejyfVM_hP6YB7LbumH0P5_SiuCzXybY-5JLrHCvyn-w03fovihI88qBGeeQT-Q5cEqT_67gwdga2fxzdTJiywoTBbg69mFwCfuz-jABlm7DBA2tZRWdmPF71MzQ6jns4ai8zWG9NM_BoC-XBftYhxQlP6CX8hXVC9ToG56v4V0iU6v_EX6wDTfMeA_5Tonc3ptxZiavWVfI0aazrTtv-e-llnrFcL4bJQyJf7Cg2hVME2c6mzMk9ITYzfGNgu4CtCm7ioIE315QMBStz5YDm2knvVhC_1fWOadcvzAStEuZxfJ1=w581-h564-no" width="581" height="564" alt="Chef Server - Deployment classic" class="alignnone" />

Después nos toca definir el **Hostname**, la **Password**, el _tipo de vm_ y el _resource group_:

<img src="https://lh3.googleusercontent.com/h3tvaxCWwubd7167reiPKmtzNCR1JDEJ7PteC99jqCOMXPRqGwj1Z8uJwutfBcRpS77Jm9BJRRN-2QrBziUs-hAgzktFKPM_wDsvjVlw2NSK9bVKI_GG1sAQaDCD8204iv6YTM1EBNl74mI0lOvOg6Bn3B4mt3vwwLraOF-bZr00vzuNKznJMhbUJZFKm8f0fj_G3-pbL4WncCsKErAol9Q3vNkmyFOGLSylvn_GKZ0WELIOmyheiEfd1yTqtDLUwEzE1dGCc5c38_2T5bZEry5xxUYzoa8Qo_g_nKmYkNHmvquxBZommcybAthtCpdGIMsz1t6LUVJBWyiSz8NEglH18sM52pHaN7U8j9_VGMH2X8-KC5A1zeqAN-BhW1AhULFe0ANEX9BDbV-vCpopXK4eCMp-fJnsA8xIvkTfxk7UexdDRepEOeqpBuqRBV9i0j2UNfpwGEzzOiSpd8fUQiOYtCwXjyJEgmAGGJG_xcK5ZtDV7T_t90ehIIPNQbywXj-vPu5lgemrDLJ_ZTbt6U6JLFU22qmpkCQJnxC4OO10Kra78Ozm_VFIO49IYZtYdZpw=w941-h577-no" width="941" height="577" alt="Chef - Crear el resource group" class="alignnone" />

También podemos como configuración opcional definir la parte de networking:

<img src="https://lh3.googleusercontent.com/CoHB9bAiaKOVb1Ng6kCOc-h7zVpDQvZiSd9brWKWrSZSd5kBzbP868fOwNgFsUyev9f0I5VQPPIkNAOnMAPWHj-fHkfv1EWFkwmRdJJSXAcWjUXXp4yPJs5XFUCQmdAacZGkCc1YllWyxQ9Acnc7TON9GUTwfmVu_YYkAKhYkuQwnP6VChRNUSpgysPwOmkiRJlsQwhixl8FAnaiA4kNeBT9awlmA20G9w418t5ka0TlPBxM3nkbAk9rAP8AsuP8WkUln-A_SU3FIQ_6WV-1j0UEOWrUri730UFHa87B6SCkXrG6jsPw5ctR46wUpLVbca49_dQ9xx6HrfjrMIuVvl6lNwl8a7l1IiWsR7I6ThKZL47EqhpA1KzOLnjv0mWG0BgMv9JZwk-3ECvfM_W69Pmeud-3ylOhWEnDQo4AWzx735NoYiPlxuGHpJL4krWMvk20q4lO7MmKhdqGXk2k6ERHkVNC4p6qj2v0-tYMcHtX_etQEcIOg1dVzgeKLjQH30laO3l1z4FDxUm3-rYqNZ4HCc6tZDB2OdRZFB33jwTtk49Oc0kmvNFymv9HRa_oDP-S=w941-h577-no" width="941" height="577" alt="Chef - Optional config" class="alignnone" />

Y al finalizar los requerimientos de configuración, vamos a poder acceder a crear nuestro recurso y realizar la implementación:

<img src="https://lh3.googleusercontent.com/5dgo5_DdEY8DdhmPDSanAIk-7Xe7MYMdc6b3nJpzcAHcMYOCFuMw5OpXKuHLKAL1T3boE6bfK587l_E96W-Vp9hwXQGJtErdERtIv-wdAUT57Tisg3ugE8T2fOfLvpMrY2c6PVZETZRZvOku56vROnd_CtG-e3EpNhSrL75yN5xCFM5j_gU4y9XCgDqwAYM6A4rZ0euXtjCMh8a-xYWdel3EOE4T1OLf5DXOQKOtpsYOj-wIbthC4HNsT2GezLTTEkviyDHQa00RC3hgawPd1nmTUjCFo6XDvx2VY7FmybjHhazKpHIE5VIwIL34DCBDhALSH0rg4ctoaN_ow7ZIL6cz1V4w_ndVJBsGl5QJDUy5vzpvxyWMQ3o2CnZclDIqlL9J1m4nnKabHSh6rv_EQHD1x8Z4_5rbLx7vN68eVVeTyHsJQ8RwxoQmJ1kWjAdAIilw4u_GzOw5aaTS18O1QQZcLTu1KWTZxEn-V3YhA7b8WCvf7hIcPGPqnc7EL-BckgmT9dK_17rsDdVxmPnOsK4lbi_N0RyIVdGhFVS21lK0Hg31UCpWIrnrsbBUwiooNjpc=w580-h579-no" width="580" height="579" alt="Chef - Terms of use" class="alignnone" />

Ahora vamos a ver desde el portal el proceso de creación y nos va a alertar al momento de finalizar:

<img src="https://lh3.googleusercontent.com/peG1Z_nLsGkBDinhASnkyho7BfeMW24-6xM-vCzqsyLEfXSHrPHUPZsgyHxAiNk1IU98bxTGKR3WmDKc76OLOGUCfJBbp3vcghyMoVbv6EDYpYmFewpeZ1vcgNUpL7ObNu809P3ssrG6zEooFuVUszQCT1OEM6emnzXrIsw2_ih-2xL7b4l2ymsdV1bPLBdKSmYBT7gl_SubBZmX6efdMO3YcslH_I4cg2Q9VrfPeVtZZcRQvj81ykSn2ZE02IMogj07_LCvFlAnO1tV6upuKrIB_uhBZpy3UgvJML2bCq3Gg0qnGKZ9SGIJegXmxm75iF91Wrl81gosDcaTsWDFrmsawyRbayleUDq_6tjScE59QsBlSSzed_tf-OQPKqqj5l17APfLwG1pG595M5QJ_5YspRrMfCRxg7qQ1wnB2vTUjXYxvKgEXPJu3QeSfuXElbx7B9FEB1YXMUAHg2tBPB0t_zs4MBN8BsnFWbIlC-DZrUu4sZ0D90eqf0pLBnGspt-yATI72mYM2kavK8clKj0rbOIHnoKgbke_ePUykPx3fgM37n5gtybflaHZLP2ysfoM=w628-h287-no" width="628" height="287" alt="Chef - Portal view" class="alignnone" />

# Completando la implementación de Chef

Teniendo el servidor implementado en Azure, continuando con esta pequeña introducción de Chef y Azure, vamos a conectarnos con nuestro servidor por medio del cliente **_PuTTY_**.

Para conectarnos debemos acceder usando el _DNS externo_ de nuestro servidor _Chef_. Éste dato lo encontramos accediendo al _Resource Group_ creado para este fin, luego seleccionamos el cloud service y ahí lo obtenemos de la siguiente columna:

<img src="https://lh3.googleusercontent.com/ILJl852lZrOOlCCkrNWvNu50glPaipnMaSYSYnkmp8W7Ew43iFf5ZLXRDfjMHlpGTi2vDE3u8KQIoprbFryvDF7dXQKM2tRrOD9p3qKknZrS0RLTAjvvzFpDLa-2eapl8XyxpXBptJA2XkNB6PsiCjmGuZ1NQSEvpHuPQOgsbxrjsngCsmrRAlkOqLQmR3ErdSagFJnoSUxqm-ajgW6H7CvzszvfLXjhq7JI2ye4VOAbLemyNZSZ3s27uIpWN31aJSOP1sKg7kgfux6tBIUave7AY8kKedu1gIxrreK0_pR_sHPsKBESx_AGCjKGpFT_ho6SYb0ARIRNPgxj0n6RaS1okaGyYYaK84HLf7miHvAea0gKwuLTMLdWF7S3gLE-bYVr9xxUcuL_iRTZXbwkDbqFHzga5OWMqUc_sdaHwjAjmArqky1eYUR3zBpqxPg-8aFQYYfr-_3pfaw_Jj8RHMCriPe9wB3Z_xv7nsq36GvnD9yBVO4Atmfn0M4hD_JVgiIVwN-Xu4YtFTosOa3XhQLlCHx7cG32WUHglsv9-FCPkxKDpWY9uhoM0RHNgBgjF15G=w573-h230-no" width="573" height="230" alt="DNS externo" class="alignnone" />

Sólo hay que utilizar el nombre sin el http:// adelante y la barra (/) al final:

<img src="https://lh3.googleusercontent.com/vsMfey-iADCrtC8AG6SunZwNxNAFJ5rTGffhmLm_hUf3bKvCznePrQHKrDlrm6gKpZ2qhWGt4maIyoSSTyVJRz95KNYjOU7HUGjHln0wS9uLtqTYLHr0fqP8QWviwJR4CEMO5FgWQpNBZXXOPNfau17N8JN3uA5gfSK96MvUQ8imo53lflx2MVMAqSeb1EJWbPnC8ll9M7WwCi6puG49VebpEpM0Pa7GKhvU0dIqL6wXYXK_pmvB3KIcVjMUhPanIDHRxdTw7MOHXorF99FyqeoCv5-NR_zkKWmJ_sgiC1InpMQMbG45r-J_HKlkMqAcOchuWupmEMQgydSqQqsXcpSrroL8icEpspoIf8t_u9d4tcNe4u5MIqqyexf-tjqP6jorarZPZ-nMzglaIVxKJCSzk21OQyAr2Tp8JIefPkozBQs8AhnJsRtJzQ8Bieb4eodu-1ABUC_CsxK3l7DAzSYXyhlWP8SrPxHyCrWFXLswJGjclPCZrcD7mHJcT6BdAfldZwvp1YbmO629qwuPGbF-V0T8kCTAC4pRpnaQmnCnauLClABeKUkkCNTqvEUXTrFM=w452-h437-no" width="452" height="437" alt="PuTTY" class="alignnone" />

Al abrir la sesión contra el servidor, nos va a aparecer una advertencia de seguridad. Simplemente le damos que sí:

<img src="https://lh3.googleusercontent.com/_-TN4WDsIIij6HLgo5xd5TC-Zv1Cs_85L_HgdnBtW9C-fbQpRHYhNfqD0f_uGJfnECvaEL0B6XU2lVYvyRiiswEAseyaD8zDIc3Qa95sTgwLKdwkpmra2lLr-dTy85IE4J7gozBHP7-_fdJuOKEOwk8a8dkA1TwkqB_tEMr9iVttCqEt0vxV5El1xr7_q9-oyz3cQRX8ru_w5G_i3AxfKMP7PM6GDb0x_PwvHid02i-XIiezJd6DN2XZfKHeb571cH9y7tXPY4kmFCzU7H6HAj-qjyHoFpO2kHMEmfTpcWkMPHRu6v-CbxcquznWwh4mlMXGfr5sp9Fv-vSEAVPNAYzbfwaJUWaC8A0O2aixA2RTU2D2hV3pJTeFBpsw-HtzY4IMGBDLSG45gQLVYNV5fiT5CYHY2e5pukgKLnp1KcJpzG9havgDfd8GyLt45ZGIO5EXNfp1cDAGqdvOdIX95pyoKt9qSr8mFMj1yfSeA-bJzD62yklkDuc6JKoYFOxTJyklcpm9pNRflnVpG_xYUdu1X_dPnyHqtLUxZtYIJ-vIlA6p05ovmShnLGEywam1zE_m=w431-h293-no" width="431" height="293" alt="PuTTY - Advertencia" class="alignnone" />

Ingresamos las credenciales que definimos cuando creamos la VM, para luego comenzar a ejecutar algunos comandos.

El primero, va a actualizar el hostname:

    sudo chef-marketplace-ctl hostname chef-XXXX.cloudapp.net
    

Luego de haber configurado el nombre, debemos terminar la instalación ejecutando lo siguiente:

    sudo chef-server-ctl marketplace-setup -u chefAdmin -p XXXX
    

(Cambiar los datos por los ingresados anteriormente)

Al finalizar el proceso, nos va a solicitar ingresar:

  * Nombre
  * Apellido
  * Email
  * Organización

Después nos va a consultar si aceptamos el _Chef License Agreement_ y al finalizar esta etapa tenemos nuestro servidor Chef implementado en Azure listo para usar!

<img src="https://lh3.googleusercontent.com/pwKvkjJuYioJUcCFoGkUJP3d4F8xPdqID_9QxfdZztzafjJYZ2PDCuMMklNwFYFMIWVWPuEody7C2F8G3I4diIO8zcGq9_ao5dWHh9JX0f7ci6XUGEuFm8f_BWlEOwpZFBuamWUbIMYCYjYK7lHdOBDCVND3mS9OY1AQtXwPpA-5vZ_XYVqJHmMSAu30fAxfGtqHOpe7AJQ08iNWSYrAHLkPsuTf8iz3IugGt4ZD5UI26EntWYJ4E9w_U6hagCIfwt_YYnIcPyUjZTDtLzTro5seMUNJiSfB6XK2qkcFVWIhlcAcWjtM9atGdlTj3OB0kyioLYXi3LoRK-EmuEvySZLWZEW5ZIsgiT9TKUseeH2F7HaoOBaeVSXA6Ox6rpqs-tYrkPTfKlP2VGHb3lZRiYM6o6YHKmEqnhcfTOjJ6jV30QP2TD24uaqbU1xV9n2ph4ApgEZ5ND9jGR4tRYUQfPR8SxJyyUJJCMBoU-8LYIJt87zJuqE8jfSSPrD0MCRDLUuk5u4lUAocxu0qJRJX4swRGlBCGPGZgek6eRfiNRM79Ftbsn7SEKnvfkkNwDqLI26t=w663-h419-no" width="663" height="419" alt="Chef session with PuTTY" class="alignnone" />

Accedemos a la dirección del servidor, ingoramos la advertencia de seguridad y listo! Podemos acceder al portal:

<img src="https://lh3.googleusercontent.com/yX8llqt0k4Dd0AmozBIXce95_xzkTWWHzikxhC3qAgazbIb0qA_XXbmFAaBdUs24MjGbf6q8dwVsjPm-VZ1a3MYMmqbIK02AcnihuYGM0IopH4dnY5O0lZV5I2I658Eog1trAN1iwbuePhuWQsatGWKMtJnd9KwXFOZF-cOeu_KCwUfUemKWwpSL3yARB4peBvIlIuzDgTXZOF1w1McvfCyHuLyUWAk37nYVOO5fhqHAz81bbyQf5mfUnr41181L7FmL0LkDqepWekDAqPMJu5uerz-EUtiO5yR-tZVX05MK1gRdWBPI6p9Za4ul9G8zO4pHJ22H8mI3MsqIShaDtP3H-SUbbIe6K4sLzExGMQF2R3bNwS92H9V7q7zq2qsaURv9Lcv3RIRmm5SDMEe3zVu0Y_4kq1aJR0AcVK1OHbO3nixL_aZUwlgPtwvOPpZcEUnXYmrWD52uMrqiYdrLfVSpvq1pw3F7w0Hx8r3Wx1c3q8O9WzG8Gg0x7gqV45ZBYH3Vli_g0PoSt7xNUCtrweAn7oaqw2euhZqtXvaza60GWi_YFERkzZpJ9lplRT42wlGF=w940-h430-no" width="940" height="430" alt="Chef management console" class="alignnone" />

En próximas entregas vamos a ver que podemos hacer con Chef y Azure para poder administrar y configurar nuestros servidores.

Saludos,