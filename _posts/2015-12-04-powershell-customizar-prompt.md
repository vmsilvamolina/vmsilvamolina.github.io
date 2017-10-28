---
id: 947
title: 'PowerShell &#8211; Customizar el prompt'
date: 2015-12-04T22:09:26+00:00
author: Victor Silva
layout: single
guid: http://blog.victorsilva.com.uy/?p=947
permalink: /powershell-customizar-prompt/
dsq_thread_id:
  - "4488031977"
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";s:68:"https://cdn-images-1.medium.com/fit/c/200/200/0*Sz3Js055VwE6KyPu.jpg";s:10:"author_url";s:33:"https://medium.com/@vmsilvamolina";s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";s:12:"b1706affbec0";s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:6:"public";s:3:"url";s:78:"https://medium.com/@vmsilvamolina/powershell-customizar-el-prompt-b1706affbec0";}'
categories:
  - PowerShell
tags:
  - Consola
  - Custom
  - Customizar
  - PowerShell
---
PowerShell ofrece muchas maneras de hacernos felices y una de ellas es la customización de la consola 🙂

Hoy quiero compartir como customizar el prompt de nuestra consola para darle un toque más personalizado y/o diferente.

Así es como se ve por defecto:

<img src="https://lh3.googleusercontent.com/09zJKkdFkFVFkdjZFd9pekOt0FYvjhulUKC2uA6IFNdUKpwmp7TpEuehTulRHTsMa1a6Lf33EAblHSwgpbs7zaSz6Mj8BGrEnP7Zp2Oaa-cQoPYlC5gz_eZFv1pkPg5GrV9Y02T99bEoZL1ySIr2nzQnbA_gFIaRcL3DU-LsF5n67JW4UsIeU4HV_IhgoXgh6h383kp3-iX6efgFLv0L42RR-NRZ6v7N23aksAwsX_Nrbkoj6OltKE9rwV5bkWFXf-DRKpM02a6Daa7kss7DE4_Ga6h20C6MBwIJURNcG6v46_m5aYHi_LyDnD-O1qG1p6hTtJIn8X2vd0P2a9V2IDjb_rgI2Zg4-4BK_Ckz9mll76nvHDS_Kb6r3UVQqzGW-ECEqU0RWAapTP3G5f9vE-Ice0oB4iYBmOs1ntbjm5pTutANyOigTbg-LDawJuK4TtIhmNQrR9-f3BCcJPCmUgMONb3By2Fk9kv3dx-u8Fn5ZEscUHzspRxa0x88bL3kXnglQPgDj0XIbCjBjr1boVfGHzeXmBjctxEi9lEycTC05JA77REdDiwAM5w3LKOd74Nm=w571-h303-no" width="571" height="303" alt="Consola de PowerShell" class="alignnone" />

## Primeros pasos

Lo primero que me gustaría compartir es cómo hacer para poder modificar nuestro perfil en PowerShell, para ello, debemos situarnos en la ruta de nuestro perfil dentro de la carpeta documentos, ahí van a encontrar la carpeta _WidowsPowerShell_ y dentro de ella, el archivo **_Microsoft.PowerShell_profile.ps1_**

En mi caso la ruta completa es: **C:\Users\Victor\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1**

Ahora bien, teniendo ubicado el archivo a modificar vamos a ver algunas cosas.

Primero debemos definir, por ejemplo, una función en donde poder ubicar nuestros cambios. Para ser consecuente, voy a generar una función llamada **prompt**, donde le voy a indicar que me devuelta (return) el símbolo numeral (o sharp):

    function Prompt {
        return "#";
    }
    

Si guardamos los cambios y ejecutamos una nueva consola de PowerShell vamos a ver lo siguiente:

<img src="https://lh3.googleusercontent.com/zlT_xRqsICG8p3RYAKOw4-e6cgUenoe3P20AX0iynE_4m2hYg1AALzImSJ_kTcOsMKHT8o_rz1HpExsEw1Yj8Phqt9KVPpmdpVE-njNldsdXJmJH6gr9JqVgfvMGsGQYzu_KQeevqL5M82IzfIY8QAHU6H0KvoVW8wjDlroX3wi2S_-yjeNeGs6BFidmu9U_tVcSQg-L75hdh8hFK1H25G1xbQonMS1IJOZRM1DeOlSay2-xdadezsgfghYZFAj9wGT8CHBUrTbSUB9aWx4KkyqVi2agKbV2gpvJJAtubPl51b63-IR_9-kWY-oQJ-QkrARDqr4BnCjbaDP7PmRavhsDGVVSDP1PN2vF_ncpqmfi2UrW4RLXBUCISwwOLn2-JCFNlQf8OQKcy5rqQxzRgji4vteuJtT_T8p1c0jo-QmuOQF71OypsgJAAiRHs857bJWcxiVUbhqeK8TPgvfugjQNBp3daHp45wMZAHwnm8xVnpWroNvEbF79zGIqzbqAD_1yFSCBH4q7zC7dx92ASdxJ8gzALFlPjpXIG1tIwCBL4uRYZhbMsrhOxRcT439I2KYC=w591-h165-no" width="591" height="165" alt="Consola con el # como prompt" class="alignnone" />

Ya con esto podemos hacer algunas modificaciones, como: \* &#8220;>&#8221; \* &#8220;&#8211;>&#8221;

O agregar una variable, de la siguiente manera utilizando la hora:

    function Prompt {
        Write-Host ("[") -nonewline
        Write-Host (Get-Date -format HH:mm:ss) -nonewline
        Write-Host ("] #") -nonewline
        return " ";
    }
    

Dejando el símbolo numeral, como separador (para que quede más ordenado).

## Agregando colores

Teniendo la base anterior, podemos tomar la función y agregarle un poco de color y algún símbolo más:

function Prompt { Write-Host (&#8220;[&#8220;) -nonewline -foregroundcolor DarkGray Write-Host (Get-Date -format HH:mm:ss) -nonewline Write-Host (&#8220;] &#8220;) -nonewline -foregroundcolor DarkGray Write-Host ($PWD) -nonewline -foregroundcolor Green Write-Host (&#8221; | &#8220;) -nonewline -foregroundcolor DarkGray Write-Host (&#8220;#&#8221;) -nonewline -foregroundcolor Yellow return &#8221; &#8220;; }

<img src="https://lh3.googleusercontent.com/koZP67pX1yJ0wnS1slM5zmFy_58tyqzMkQ77406YEoicL8C_uo-1rfXOZ1lh29XQRlAdEeNB-MJ0VlhwHaASX6HpyiEzUGI0NfIaSToFPGyXATrqWETqFyg1kwNTK_H5GHilT2FRRIl9rNzbNB8j9X0P5r2CZ3t3H-EPmDHILDpWMiPmAA_xJOQFf3UV_Zubbql-HDZhxDWZj7PfXXzjGSjk5khTQRTG6p5GQB2M1sBoboPDRqA4PqMyDacpccwxcp4ykXivzTbas3B86p5Hop6oV-o1DomOus1mzV5znpUU9fnNO4hWBxtXzZWQl0as9aslMBo_fiCe54lRaiasLMJP6Gb0kSRrLoE6u1LOInqIP1ROhxb912aG9jw6rOzNB_C3HCz4FfJveOKirBj1LvHrxDGb1tdhWeFInByFZxp1Fwkqopm0IY-wGggbozFvdW-YMbkgWRLQQnsAqWonfvEtq1f8i1OGBQG2LiVntRPxoXQ4yoUfoyY4SJYRYj4bDNuntjTrlexvsX8k1KhWNHV8Jlf6DCJrPqDWNXqYmCyGoSPNmXw4NFaSwmD2qd95Amaf=w540-h279-no" width="540" height="279" alt="Prompt con hora, ubicación y #" class="alignnone" />

## Cambiando el título de la ventana

También podemos hacerle cambios visuales al título de la ventana, como en este ejemplo, agregando mi nombre y la versión de PowerShell:

    (Get-Host).UI.RawUI.WindowTitle =  "Victor" + " (v" + (Get-Host).Version + ")";
    

<img src="https://lh3.googleusercontent.com/qoMO8tPm4-R2flW4hG4iaSZZBLGrowvfKoKuIKLuNhHRvMDGIc00J72VF1u9WQM-OosGD09RU8XZYZNN7k_rrxs5knlvCqKhzaL2czu49f4x9gU0P61ftURovYZXV2q3aFBsF2m-3w8LcD1W_G8N99QEE-BCl4qj3w0nsbAxkMKVO4gxrY_Afyxsvv_yaCLu6FNpsBpxbUuPn7q77X9krE_XFVfq_8l-0hSrpl2-C9ZA02NJNO944keW84vA_k-MMSzhbQjyKKY9WYvIpeSTJ8m1SZkX_oFeeMNAA1DvSJzmhXpSMga8zizZoit1og-7L0QywMw6jjEccFMmMWHe2hzP6HF-SlFrcFcMnbio8VDfl3ihYjdel2Dpp0sesh4OmnZR9YVowvA-XCrgNguFrlx4iRFMImFgxl1hDAbRALXBy8TyeRmqqXWPeBlhly7h6GCNeEKXQdTSHiXA8NohMNas_Zru0MEtpt0Rh1R0RNv4Kbk_5F-tqa-fPMc8j4UuWufKrYyCiPEWL6TbW6ELD_eEARym-sCWLL7cH-4WxVsaJSerAYfi8rqIx6-AIxG75L0a=w567-h296-no" width="567" height="296" alt="Título cambiado" class="alignnone" />

Saludos,