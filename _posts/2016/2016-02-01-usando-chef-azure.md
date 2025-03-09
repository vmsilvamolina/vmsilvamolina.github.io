---
title: Usando Chef en Azure
date: 2016-02-01T20:05:48+00:00
author: Victor Silva
layout: post
permalink: /usando-chef-azure/
medium_post:
  - 'O:11:"Medium_Post":9:{s:16:"author_image_url";N;s:10:"author_url";N;s:10:"cross_link";s:2:"no";s:2:"id";N;s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:4:"none";s:3:"url";N;}'
dsq_thread_id:
  - "4543609562"
categories:
  - Azure
  - DevOps
tags:
  - Azure
  - Chef
  - Chef Client
  - Chef Server
---
En el post anterior (Chef y Azure) vimos como implementar un servidor de Chef en Azure, usando el marketplace de Azure para facilitar la instalación de Chef.

Hoy quier compartir como facilitar la administración y configuración de nuestros servidores usando Chef en Azure. Algunas de los ejemplos van a ser como definir algunas recetas y "
cookbooks"
 para poder empezar a entender como trabaja esta herramienta y como nos puede facilitar el trabajo del día a día.

Vamos a comenzar ingresando a nuestra consola de administración de Azure, ingresando como URL la dirección que nos indica Azure en los settings del cloud service.

<img src="https://lh3.googleusercontent.com/V4El_t8zAaiyNgg40B8mkhjviZGapw-N8SYn_4K_GXAmbo8YW7-A2ZYfmHu9Z2BVYGxR6DorMAKW7BfaJXc_r4esKgtu3W4wcp5oIZ4wPpNeVu08i7mTMzvyAgXIY-NnRvLKbvDEaNWt4_Adq05jydJWl1B_suTvm3EZQxuNY9bcTzFBAIEfClmMDKf8D6WZmfhyPl0hofmzaVrygHtRBsCWeqIYgaHHxKJ4d6nZHwz7gqEFu59_R6kWvibgQ2LFMWwpxNfNrpQnNdUWKf54pV-yZoM-Aagw63bcTHLDbyNcB660Crz-_gZ5XAeXzV-I3EjIoUtdnsP88wC8fjWUdKhvFsL1BRyXl9lNdBJzP0JI_Ls8G_eRm6rYnQPCEZzi3ABaf3vAcb_cXEhnX6W0cn7C-V3r6Y90SEqDsG6AoCoiFKAxBmIXXEIDotyRWW59HscQNdeg4SdfF_UStR6YVaDKiZe2nK7hLG7RjoWSAjjsljCt0iOS1_HaeqKCJXZFQDX6uGIzDEGerMKtqP7BQWB-PEuSfSPpVmnppIJeeZ-8aSyGC1ucBHgi3_-YxT2tzRQp=w940-h430-no" width="940" height="430" alt="Chef Management Console" class="alignnone" />

Vamos a a ingresar las credenciales definidas anteriormente.

Despues de haber ingresado al portal, vamos a ir a la sección **Administration** y seleccionamos el ícono de engranaje, que nos va a desplegar un menú con opciones. De esas opciones, seleccionamos **Starter Kit**.

<img src="https://lh3.googleusercontent.com/5AfiWM1sd8mroP-weCbAkjkF8NK8vC-ZQifcsL9c5HPb-NpHeOuLTUOSamM8Hkfdzp_k07JFnehZs0wsEXd74UrnYT-NHQoHq8zQlN75PruLthsezMIgmPa9b2mqivzwt53i4cxvGSOskavwvLTnXYkbr4kQJy5YYR7VrioNhfPZ_ZHTbK8y2tKoGohGFxLRbotXpK0ge9-h6NB3G-GUJDSuL9-BvhDh7xhA-j_A6rtaXNphBwAYJchjvSHMOq7OjXGJSbN9W4Q65JYhGf3hP9-IRub0feW3WdIVmrI5y4D9m-wN1_swLdgbQ3K39j0bysRA8J2LHo40MYTlbqCs30w1BkhASSdMIyaMvHdiyS2oSEq_VN1km7jYI7VtGq_C-nxPVAM05nxqFuTdKBPLj2oyWeQ0vQn6MO5Wuk4u6KObUDeZNmFIOKD2b7jlTL8EdP9Jenbbj7HOLfRTHVBDCE6-CtPVtZyGJulgTnOTnGThf_iebYyk-vP2YaVT6Kr7ZR_qxplawOykv4r070sHNit-Rvv_JMsZtcvxK_w5z0LUswR8zd7Svx3wgi5ilw5BCGE0=w943-h564-no" width="943" height="564" alt="Menu desplegado" class="alignnone" />

Posteriormente seleccionamos el botón **Download Startet Kit** y seleccionamos de la advertencia que nos sugiere el botón **Proceed**.

<img src="https://lh3.googleusercontent.com/PXKUtXnkWQDCVTD0HvUm3M8_eB_Di0JeVivgJWDu_gFOt4KUdkP3R9jrA7hmZf4ecOIIO6ztd2ftf-BmEPd8MI47SM-vWUf-cQwpLs2I5JG6Uu1eNcjd2sFXoZpFuzb-YNUT5TljTr0PFxO97BkEqS3dnUV4Oom0rpeG8063xU5cx7XXLjp-pbMSxFnPhpd0jLQQyqQFN6hYJnbJ168nHpGV2sbiNcCj_8ky2U4OQbcDgCtEAMdaPz5OpcP5cT8cCxrSHxLdTo5gZrNJKlQCayoAP5-oIyAryRZ3_FuUtUNqF-AkHaA7A5iYLFVV6p0YkdWvGj_8T9wb9MBN0r9FFOHMnt71BF_dNF6tDf6cFqceGhiMKxQUbm05Yw158cR9DudsflJgTZW7YWrNPioaS56eb0RzTvaGiwA7whF0O5nQJH1ea5FAvdGhU6wpKTYpOyN7bSiDMQnI8SaUf8HvrVY6Eydjth7F-RWPaJeZuYliGZVd0agrM0I9wCI45OcyhhOFa2tS_EXT46Zj61h5dJ8QUftwzWoKXEL9d4qYa-5bV0RgIyZXF1Rv-hDc3RbOMu9P=w943-h564-no" width="943" height="564" alt="Starter Kit" class="alignnone" />

Al finalizar la descarga, vamos a ir a buscar el archivo _chef-starter.zip_ y haciendo clic derecho sobre el mismo, seleccionamos **Extract All**. Definimos como ruta destino la carpeta del perfil actual (por ejemplo: C:\Users\Victor). La extracción generará una carpeta llamada _chef-repo_.

# Instalar el cliente de Chef

Ahora vamos a instalar el cliente de chef, ingresando a <https://downloads.chef.io/chef-client/> cuidando de seleccionar el cliente correcto para nuestro SO.

<img src="https://lh3.googleusercontent.com/xcDOaJn2K1YcmDsyAJcP1zEqQ7hSab1vBkGG4GXmDHv9tjt5XoXAKzhFCutdfLyg9Z1OK_LOztQ9U_QyCKgl9SARWyJpiTTEc3WYacBMjCNpUB5ryTQG5zN3mQ_u-f2aA_dCl0p2FBFc4BnoBgkFyW5ECCtoTJdkgu6XbA5LaNVhGGdlvTuSmQFy49ZIKpnta1UD-c5E8QSyBLt759U3ZjwLRAck1D5QQrSrN0cIoRoXFyzjWRIm9U9G3VoAsJOvdZ_-ZB0yUkYdJD0jS928p38BWTIcubkXya-7WSC3aClneTz73hpp1BwruMqlsg21WekiHPn-0-j0MvLUTcdLWpJDkmrSOqRi7XAqoKMQF6qUGNff96bs5H8gtbtvEN7H7pwTBcYSv2tXS6Ys9wFe8CoF1fJu9BPkIXCPaTuMi9LUNLEOtpj9R8HGTT6FYvNrb76TbV3D8vSEvksMBpMzpy2lkQgtYljt6mlCSOEnfEXlr1gdHj-zPpNDa7cY-t3fX1iq25h_achynUR2ytMVAOJjA3qFd_Ek2lk1u5Dfz4Ca3sX59JHDKYyYrrLFOW54cloP=w943-h564-no" width="943" height="564" alt="Chef client - Windows" class="alignnone" />

Al finalizar la descarga vamos a ejecutar el archivo _.msi_ para comenzar la instalación.

Aceptamos los términos y seleccionamos siguiente para avanzar hasta las features a instalar, en esa pantalla seleccionamos todas las opciones:

<img src="https://lh3.googleusercontent.com/BsZvaykVvJU4VCni8M9YJ1ah-kd_HhjrDlvcxZM6Zrr0GNRtlUZ3JGmCdPLGnxgZ2VZFqr4DNx6V8c-QcHrLR-9TvSWNa5uGgH_Tvsr3HLiANF90WK8St5Trr22XJB6oPjTink4oaDNZWTZTfcS_DMddCDMzhoiV17UaYmMPIIV1oUCnLXrUGmW73U85reP8r3GdLDItc1e_9g0OGx6mAPhroMHftrFQ23G0Pu9SqCh2zylZGlw-vNGIoXiVLtMMjrKMH35KPKu_mZh2D6xDD-8eNRyRYJWLCK8qXxIi0zjvSNWclQuGUmbkVpXfmRDZ1GVySeMYW9KfL9Uwz80bAorsb8khesrzvX5i5hqkuaPotR0_HN2EUGhZPL5GfVCJYgqiUGYcQcJTSF0GdDv4DdnwolQM1GHtGkhlWQLnevo87iR_c4BGdTYIH5DiQ8747cLiBjXGKwzDukP9jy7t3J1L00qip4hGMGX1MT6V9oIHHlueiR02l9FVW-2Wpgu9VKvTLMle8QIprS4ZiXIeN5BslCteD2z8b7CQSotoNw0Mjlb9pJHAWuJwvbSc9SkOKU85=w514-h411-no" width="514" height="411" alt="Chef client - all features selected" class="alignnone" />

Abrir el explorador y navegar hasta la carpeta extraída anteriormente (C:\Users\<user-name>\chef-repo.chef). Si revisamos los archivos, tiene que incluír los siguientes archivos:

  * <cheforganizationname>-validator.pem
  * <chefuser>.pem
  * knife.rb

Modificar el archivo knife.rb, cambiando el valor del la propiedad **_chef\_server\_url_**, en donde vamos a definir la URL actual de nuestro servidor _Chef_. Luego agregar la siguiente línea:

> ssl\_verify\_mode :verify_none

Nuestro archivo **knife.rb** se tiene que ver mas o menos así:

<img src="https://lh3.googleusercontent.com/r8wkoG1tzHFgArbexM0N8ZUU1U4TtyTMMe90fPCAKKycy2rzJXpEmsO_00DPPdZ2peefjyuStPI2ADsSNygTnxSO_RF9pQP4wSNca-ks1ebeUZBLx-j2158faEfezxTFOUdoxaGsnUpm-QHmbfzCJcfCV6v2VpbF5dqhiivoCvqB5eze3P0OJkNUwjY2YEXK16C5-PZ2WGJrwOYNw8q2mLUZx7lDWjUONQz0YR_du-Q-LQdfC0nxvspJJnVZzBeH-2zUHm9mw5FqMirdX3zhkOwH2-moPFBPnU6HeD2BdMGI3Jt93f4Tw4l54gJfAvW-XL30Xwx96rezWFX8cvUj7YCurFTxbjuP5ap7uh796BrHV2Ox1kassq0Exe40ZlpYaP3vE-sCZ7ckXzgcDZvNToLa4OsPG2eKjI4d8RbCpBBYPosRLaMDTnBQZYkypqY4UMd97KElbwzPAu0XszErwyN3SvTP53J9h1SITF8slmL4nlISjxJW-CZ3OWYCSSyr2I0yiIIKGXYN1uzS8CzTnr4UuUxn63L_NsCuZba4mwS09W4wLCSlnKXw-mcAwj8V_5Z7=w890-h337-no" width="890" height="337" alt="knife.rb" class="alignnone" />

Ahora vamos a crear un nuevo archivo, dentro de la _C:\Users\<user-name>\chef-repo.chef_.

> **Recomendación:** Unsar algún editor de texto del tipo _Atom_, _Sublime Text_, _VS Code_ o _Notepad++_ para poder manipular mejor los archivos que son de texto, como por ejemplo los que tienen extensión **.rb** (Ruby).

Vamos a agregar la siguientes líneas:

    log_level        :info
    log_location     STDOUT
    chef_server_url  "https://siteurl.cloudapp.net/organizations/azurechef"
    validation_client_name "azurechef-validator"
    validation_key "{current_dir}/azurechef-validator.pem"
    client_key "{current_dir}/demouser.pem"
    ssl_verify_mode :verify_none
    

Donde "
siteurl"
 es el nombre de nuestro server (que conforma la URL del sitio). Vamos a guardar este archivo con el nombre:

**_client.rb_**

Teniendo el archivo creado, vamo a ejecutar los siguientes comandos:

    cd C:\Users\nombre_usuario\chef-repo
    knife ssl fetch
    

<img src="https://lh3.googleusercontent.com/ar3tyKqregx8XJtQr1JyvZr4JCuGlCDql64OuVPcczYLsvUc4zIxBDIYh1R2tgBvyr03FhYWDtzTwVsDeKsxy9lclRnQ1nJRsDyqbyhkHZLKx2vLtvBglwS4d0pyPUkHKx-cONwtIn0o4oqCMS2Ps4gRmrOS8dLa3TMJ2K31ZTbV-m37SfVs12ybtOopOvruEUvKX2tGkT_BM9tllliJme6HJI13gNZwKHEJbaMnK4wgvmDboR7guSOp757im4F-SDL6u8ICKuKmwkD-jmZxiOSDdfdlfFGTEyMBbR_gqe4h7-Vb85vt6vDNEIDN1AK3X0l4hIF4qvswvtGwJmf1Vf1GovKQkIhvpbb0hiFR7QtH6NgFRH7dwWZATIC8kK06j4doZqg3b0ujMmccA7auVqKDasi_WnBIDKZgi00RTxejRvsuO2P0QkHzGbi1hrja8ETDZWN0Stbr3ru8DLAq3AnV-8NLRDj4mr4IiCeFeQkv9kizPgOTel6eqAl3qdmsSo-90-spxONniosnWTalywRyRzdD_K4RCSW1svxm_YjWoqhKioRMZh27HDFr-Cdxb7qA=w865-h224-no" width="865" height="224" alt="knife ssl fetch" class="alignnone" />

# Descargar e instalar Cookbooks

Los Cookbooks de Chef se pueden descargar manualmente desde <https://supermarket.chef.io/>. Éste repositorio de cookbooks es creado y mantenido por la comunidad de Chef.

Vamos a abrir una consola de PowerShell usando el _Run as Administrator_. Para ejecutar los comandos debemos estar ubicados en la ruta **_C:\Users\nombre_usuario\chef-repo_**

Para este ejemplo vamos a usar el cookbook **learn\_chef\_iis** que nos permite instalar y realizar una configuración mínima en el IIS.

Vamos a ejecutar:

    knife cookbook site download lear_chef_iis
    tar -zxvf learn_chef_iis-0.2.0.tar.gz -C cookbooks
    rm learn_chef_iis*.tar.gz
    

<img src="https://lh3.googleusercontent.com/v45dP1rqmegVfGdCwBjXuMtG1h6hYQjDiJc0MTCmljOrmyU8gOlwk5XXlVProTuHTdHJJzr2JPjjXehwPCbWzZ3Hb2SJ9Xb2loxNF7WpQdrmvB-6jy89-VIR-eYvacFpYg1iV1N8t1ahqLJgINrQeQ0ClXkeA1tnHsAuHCn8PjarbdX3QaC9xjxTUVavVPYI9X3npEuUsY1mteR_wN-smOVUdKlRpZfR8_K8odW9dgbR2DCumDCx8ZYqvYSjwy0TADPi3U-jaJ3yCqb4zEPFtUf9odTm_r5ULmvQpoJbyVCCg00VzoA40E3P4rvUhK9nJgFtKX-mHHJAUhcbyv8UxpyfYEz23rVIunIxaXQbptTLdcXfLekFGW7rofUSn-7iHJo7IWLc6DazFQAaGHRvVFuDTh3TGdwCKJMqa5QpJYaNvJbts5c-qF9Vq7fcVkJmzFzZUXmZNMYsyOJGDledxintea9NM98JXEbEygNqYEYLYB7RitDjERgMKfvKotElsKxZAuOs77wzG8OkaD6C1lQyHXUu7nLwBRVB1kzZRs0d2p5_wsy1Ao5DcEKKEdJHYUM5=w878-h358-no" width="878" height="358" alt="Download cookbook" class="alignnone" />

Con el código anterior vamos a descargar el cookbook, vamos a extraerlo y luego eliminar el archivo original.

Luego de extraer el cookbook, vamos a subirlo a nuestro servidor Chef usando el siguiente comando:

    knife cookbook upload learn_chef_iis
    

<img src="https://lh3.googleusercontent.com/iJtENEL-J73n76WVbTYWWReDSs-M_51KuQWqpqU2cyw6XUwp_S8zAfEdVtxHOgyIWlXJMQKZSEAwmSmHA2gTfa2k_KQ4d1erq-BQepSCmTpAAaciaeSK1HuyvUJMp3lsbSLo2lRujIev6y_6791-ntZEEVDVGvXycb05xSVD_2P1QT2x4t72QrwnQpBCsyQhytSSZHckKDj4DE0JD1bd0kFFzbrO5A8UphVKFQefomLq2M5JowACekyuoFoyLNoTwf5S8PXMVYEPyIncQid36ZB8V0koYFcE5oRi3ctnRa6G0BGJvlG1gD6n_lveWQ3S_PfvGBthbkBIpPpSTlnFAkuN5scHIReASVxglGTbebvlBR3vXLgIY4la2IhuyyMNbqOLhhod0uy8O7N0PER0sPejGl__p6nS_4cE5SMka-WxwX9r5EPWIDQvNQsJZkPwyrFO6nOz-n7azy_JCrFuOcq6IPCEDoD5Ddkr-VJIvM1j_dfBz0Fp9zd-QSfJkfgz_EI5VIS3xNO7KmL60xwhZW2LEqVFkVcJflsUoabu_rTBbpn0RtHXqgiXT3Lz_gUe0hgR=w878-h228-no" width="878" height="228" alt="Cookbook upload" class="alignnone" />

Ahora podemos verificar este proceso, ingresando desde un navegador a la URL del servidor de administración de Chef

> https://[SITE URL].cloudapp.net

Luego de haber iniciado sesión, vamos a la pestaña **Policy** para verificar que se haya realizado la subida correctamente.

<img src="https://lh3.googleusercontent.com/nzBLRfq6qNJ2Dvaac1QbHAY8i0hIFgyby0xz4BcyV0GTVc9hlvBYrQ6r3QTj6CNqhWlhybOWziTPCne6z8XywJXxFeA4sEnz1Bypv8yr-vwqzPXg3JXg1KZ7Tyg6K-azEUip-XCPTu_JyBJC1yvMZc1PrCM4ak1ZRnsofnrYThGizjd8nxnOQ-sQu4CUInDFcXIfJlC3-BgKdxvm8vetBDzhKzIb37kQRbNPFGMNhAX3SUZRRXeHT-1mCGqLSh3DYwbQ-W_xAofbHCZZPfreMHhjQFyRhdB-Cko78d2iAeh6K6XRqNIWi0frxSPkWiPzpqtY7lusm6mUFvojKXHZiNsjhZVoOAzTfdlanMi7YkG0SUcrXjFMJXJx11Cehw7qg5aD0E5ahxZCVQfksEwPnkAlYIWzG1xo1sFTdwQtlzTjB4nVt5Nd877WcbDBorq2ZGHKepIS4hbssWIP_zpfR-qjpKvH9XeIpAfEwJRxlefti7vAkxR7TlZmJ_nPua2O0iaP99QcrXByBQ-RkXZ6U1q3fcaFcTgGvQQ_VZ67fU4-zQkOAQhlUbmZwG4t1iW--8HM=w844-h564-no" width="844" height="564" alt="Chef Management Console - Policy" class="alignnone" />

# Bootstrapping usando Azure

Vamos a ver como implementar el _cookbook_ **learn\_chef\_iis** desde Azure usando las **_Chef Client plugin extensions_**.

Primero vamos a generar una máquina virtual desde el portal de Azure. Para el ejemplo elegí una imagen con **Windows Server 2012 R2 Datacenter**:

<img src="https://lh3.googleusercontent.com/_pl_HO4EQ2Xr6wNguQkWBx3O2ZlGqCvyVI1SHxNjSnbPcGRCc_JANA5CidKGFoP6USHbCPV803pP21L9itFF_cwhQonzVwAVa7LXIZ0cu3AFAqE-R6ULSa2xPla7Seu4kqO6RZaa4oemaY2TUWHk3eQLm2b_BLS4XFS8KBbpP4slPf3dXCoZkK1axSQIMGoMNHQxXwL97tiXhf4EtPaYpbGD0dW9Cq6W5tLxqlXALpe0AXCuGFpzxM9LYfCpyaQRjalKF_4K9IeeveXKS0wYOjzHAyLn7Gg--tp2Z6JaPAqdsapXW1moaXiPRjJqLZbGs9mMVVmF57h-XZ9Jcxp3_rRy83W1nofXF43anXFMpCreT5YcAmEqmTQXzlCTnIxEwAphEoB6PPDFLbXOACE5s6sjZpeWdZ_zqjOhih8HIM6yRI8lxw_ymBrWlRIrC5LoPgFnNwcizVSlw-OpuW8JO2OQHmq4W_NrT4vlsAetoJMpxfRbT7jkaSzvlXxILi-c6n2fSuL1y2pEDwCdUD8Ls8TGFnwilZRaR5C5YtTTOeaM7Ox-FzPkKWYGF6yhfKUDotYH=w1109-h637-no" width="1109" height="637" alt="Windows Server 2012 R2 Datacenter" class="alignnone" />

En las propiedades de la VM, vamos a completar el hostname, el usuario y contraseña, el tipo de VM (yo lo cambié para uno básico porque es solo un ejemplo). Dentro de las configuraciones opcionales, vamos a elegir el Resource Group que ya tenemos para nuestro servidor de administración y vamos a indicarle una extensión. Ésta extensión va a ser relacionada con el cliente de Chef.

<img src="https://lh3.googleusercontent.com/sYaHEtcy8e1wpmxvkBfslLTw7wWFjSLo4um3PBYO5Q4LMOopvI58Pm_k-09OeWswcDDfMf_i0y7yifosValQ7gd-rcrflT_j9rSO0JMv-e4y0mxbK_1t0279r_AOnQ-xvY8PAEqQTq8drsHgZNsWHbIs-TGNrS05J6_BQ85MVETz69tgy9BW3NrOiWvLR4sGOB0cAbgbSJS-RJqVzhVO72Ey_LMGEMZCQ76MuUThFlmbUncRlfN7K2Xl8l6wCvZw_2b5U7kacNTiSv01l0hlosg94m0jrawzJC13c8WfslsQftJepsDWXOdX1bhFCSErHwXOU6ITP3WIV-hC1q-cBQqH3dWE1rB8NfdceTK3fL-tQH4-2_vOejfLsHmettk29KSkTFH2mfMmLi5sMa2i5kkTJXcBd5-zcm6ooOPASGe-daSZpB3Z44mK3Si0lcmkomgo5_tSkONVl6vUmm5wW2_mNtgBtr46ydCkyg3IYktEeohMcc4zO_sHhhOBN5VEaebcGA2bCPRwSMkYa5KxXgi5Py1qcgxjwEzJ3PQKUgNsBv367KG0Es-TsEPny_WqUgQC=w1259-h543-no" width="1259" height="543" alt="Configuración VM nueva" class="alignnone" />

Dentro de las propiedades de la extensión del cliente vamos a subir los archivos que estuvimos manipulando hace unos minutos:

  * En Validation Key, vamos a subir el _azurechef-validator.pem_
  * En Client RB, vamos a subir el _client.rb_

Ambos archivos se encuentran en la ruta **C:\Users\nombre_usuario\chef-repo.chef**.

En el campo _Run List_ vamos a ingresar el nombre del cookbook que queremos asociar, en este caso _learn\_chef\_iis_.

<img src="https://lh3.googleusercontent.com/ZNPDVLHg-RsLLewpbYLOnfPrJTUN6YEW4E9Z_ya26PT3-qNp2wqvhPau18jrK_HXlGd2Kz-hURVpTO2KgBMC0_5Lfi_2GSEEDjB-J9oAV-VuD5Hw5P-2tTdXIW9YkM33FckpjtyOa5a9qntohMnr0CTDHT_d1IeELL4SVEBKVD8s-GYXDcrhE92HqNYzgWwKux54vmt3GaeWQaFlNSAurRiiA_jKrlNchJk1zDKyzVCWaKTCrSczKReR0mpff2n6KhlQ7OEoTEnLDjgXGY5sVbO8xd5iHehgYEN1UPDKZQeRISV5SMQ2FUdwmWSwDQvtveUKTF2dm4IjTOUHOtcKWUtldhfyGm3qQi2eTVyrpRNbGdGjco-H5iHTTaxG2qvDyEUN8YvRUmx9bOO7BUiTZSBER8GqqUj8EbcmL2QRairuKFNDkq_travthfSM_wubUeRNLxovz0m7vLU_kJJCdL_dMAtRvd6mWk46ibUACxzx1-0iihg91l91sIBcjR9GTTPm1yU7Gja1qP2lKS6FxO4GlB07J_3Ee2hJIXaAA4d5BsEvCO0SeDX6vDQmgSGGNADd=w304-h391-no" width="304" height="391" alt="Extensión del cliente de Chef" class="alignnone" />

Posteriormente vamos a la sección de Endpoint Configuration y vamos a agregar 2 puertos para poder acceder de manera remota; el HTTP y HTTPS:

<img src="https://lh3.googleusercontent.com/oNkyzUkizpAlMZtb-F7B7ltcmzh986x_l-XuGle2iaPeEAdjTnGEmf45e3WvWeiwN8642iFCot8OVCNd5HLogUvSltxy4LnZXHWUgBCOYFlQ4OC__vnm5ZO0_pkVhnBfB-y4v7ypUU8HPx3Os1Ce3yghG64Jnh8HoqsmLWqrnfjtJ-T-lL8UTxHFDRyFIyZ4AbQLim8lbE29H6QlI5Uwp7STBex0OtvUFYuTBz837I1P_f81RPVrJnVZR2xw4MH6KD7OR-Vkt8veu0QpeSU5jdfRVGzP6QqCPtn7FKYrj0_RWPTl44FNUnQajATqWRqn7Ws5078QNB07f5wXlstTK_ZB0e2NuJKqEAkal9M1f3PLyjvoaLy4uw5FCZwGwlhpivBCIiqiK4ZWlc6PChxBsRvKhn6zhSbUuJFK46zgyBDgMjhYZDBbYWHncOV4XhO3dNGn1MW0ygk6Z8zkfzN0VqHA1ngfLftebSgoCJY9SsA4bcXuZHDoeQ2hhSv7SAOPJZ13VRChSbcADgDKaLqNgzhZmsRvrF1yG8FiN2eJwsQpByUxgR6fQ4986S93E6BHtJEY=w552-h347-no" width="552" height="347" alt="Endpoint configuration" class="alignnone" />

Al finalizar la implementación de la VM en Azure, se puede revisar en la consola de Chef que ya hay actividad relacionada con el cookbook; aparece como ejecutado con un _success_ como status.

Para verificar si realmente se instaló el rol de IIS, basta con navegar tomando la URL desde las propiedades de la VM (**DNS Name**). Como resultado se va a desplegar un **hello world** gracias a la configuración del cookbook.

Y todo usando Chef en Azure.

Saludos,