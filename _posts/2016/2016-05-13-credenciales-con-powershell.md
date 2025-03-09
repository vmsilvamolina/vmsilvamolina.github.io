---
title: Credenciales con PowerShell
date: 2016-05-13T15:29:53+00:00
author: Victor Silva
layout: post
permalink: /credenciales-con-powershell/
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";s:68:"https://cdn-images-1.medium.com/fit/c/200/200/0*Sz3Js055VwE6KyPu.jpg";s:10:"author_url";s:33:"https://medium.com/@vmsilvamolina";s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";s:12:"91608ca27c0a";s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:6:"public";s:3:"url";s:74:"https://medium.com/@vmsilvamolina/credenciales-con-powershell-91608ca27c0a";}'
dsq_thread_id:
  - "4885925779"
categories:
  - PowerShell
---
PowerShell ofrece un mundo de opciones y maneras de realizar las cosas, nunca existe una única solución para una tarea en particular. Dentro de PowerShell se encuentra la posibilidad de acceder con credenciales diferentes a las que se están utilizando en la consola al momento de ejecutarla, por lo que es indispensable conocer como manipular estos datos que en algunos casos pueden llegar a ocasionar brechas de seguridad si no se encuentran en buenas manos. Por lo que manipular credenciales con PowerShell tiene que ser un tema que debemos conocer en detalle.

## Credenciales con PowerShell

Existe un primer Cmdlet para manipular las credenciales con PowerShell, que tiene por nombre **Get-Credential**. Con este Cmdlet vamos a poder generar un objecto del tipo _PSCredential_, el cúal nos va a servir para varios y repetidos usos, como por ejemplo el siguiente:

    $Credentials = Get-Credential
    Connect-MsolService -Credential $Credential
    

<img src="https://lh3.googleusercontent.com/uJ75p2wvuWv3U5cTiKO3HXyA-CANNbTNhldYQJFS4rT90cwfrmnEUn6DZ5ndkK10jGKXVC-wZAJi96Z3qHyX-H8w7gMjpu1Mev22KypkyvYdLbsmYQRhYC0kKsJ8B30zRh11ckLuA-Tz5nwzpjjl4zjKgEMaOfHA5d3v4Hn_vKGVbKVcGRRUsB3Lz1WiREw3FBT2SACVKeVyTmzlFjOpxUIt7045vIVJqAOHLnAPasaFs7oNpjIFwu844A-QeL2Yl3ZwutycLeIJj7Rp7-fvy4l0SeQmCHfsH8AF3iWBeJ27fC1n2mhhxULTZAtLfaUayy-1ucrAX5TghH6UtK38UARyt9aSn_JAm48DUJrFDds_TOdCdZOzEr-Uil7sn3tziCzJSLqnQAN8EtxSgr9c8tAXNPwe3TV5wwgKE4dSxRqR6AOJAtfMd5x7Dq7QpfCccCUycMIDtTIvCsiUx6mQRqyLcNLguoD53dI9Nhh532NYxgAmGUUWhIdZLfuM6bopb70oBQJbdBXaK4OBTvenIm3NqUhCvRBzp10HzUsLt1nItQEct7xjw3BLYd3gR0aSakWhT_0yxuAFri03p9ZYsJH_r8tvt7M=w857-h473-no" width="857" height="473" alt="Credenciales en PowerShell" class="alignnone" />

Con el código anterior, nos va a desplegar un cuadro para poder ingresar nuestras credenciales, que nos van a servir para iniciar sesión en Office 365.

Ahora que es lo que realmente hace este cmdlet? Sabemos que genera un objeto, por lo que podemos investigar sus propiedades, vamos a ejecutar:

    $Credentials | Get-Member
    

Para poder ver todas las propiedades y métodos que contiene. Ahora que sabemos esto, podemos ejecutar

    $Credentials.UserName 
    

Para que nos devuelva el nombre ingresado en las credenciales, por ejemplo.

<img src="https://lh3.googleusercontent.com/7U_v4OjTD5Oo1SzHIt4Ivqc9rDaKtUKqlwR1_TPNOaQUm3cC3gByCPWCb-g0-KddTSlCeabInhkuM5_bZw4c__GCC2qopRqLa0x6oWIh3XMaHwniszUucmTu9AcxcEScSHLdAxyfb6safpIcgn55RnUHD-QaKkglzQP7LXzrzVYji0Xvvjeph2WiwcWXylNy-Pl_cgaLUdajaVzMUCNMi_1Koph_9YQDpEHzyK7zULhSFo4xZhjDPrmuI_l4z319PfGNhCVd9EX_Agu-6D5mioiUrqrG5u7ehknbqGvqLvalioCfPA5vlgSoj5CWfx0uUbAUv_ap9dCuAanYiKn_5J8wYDUWpyFciAtaPSjSfrFufMDuspJ8TVECorZk0vLfR1aK9xZNBZLQJowjTFLYLUk1xM3OFzcJmncYdkxl1MtaDSTk1fWfqJdc7oaWiSm8j5QzyKV7a1g2b6EPpgHwuFec8y8J5pv6KWnDIc-_NEJUhOgE3jX9ftsECbro2C9OGTEZq5hQ6AqgLYsS8wd78g3oC4NniQt11W-0Lx9qolQvrYGeP-t8Vn2RR5QqMQkN1Qnj2bK0qXUUVZ8QOBge4OftQzqtB-g=w859-h329-no" width="859" height="329" alt="Get-Credential" class="alignnone" />

## Crear un objecto SecureSctring

Básicament existen 2 maneras de crear un objecto "
SecureString"
:

    #Primera opción
    $SecureString = Read-Host -AsSecureString
    #Segunda opción
    $SecureString = ConvertTo-SecureString "Contraseña" -AsPlainText -Force
    

En el primer caso si comparamos con Get-Credential, vemos que solamente podemos proveer la contraseña. Este ejemplo va a solicitarnos que ingresemos la contraseña con un prompt en la consola misma de PowerShell.

Obviamente que la segunda opción no es muy practica en el caso de utilizarlo en un script, ya que la contraseña queda a la vista de todos, por ello es que vamos a ver como guardar las contraseñas ya encriptadas y no en forma de "
texto plano"


## Guardar una contraseña encriptada

    $SecureString = Read-Host -AsSecureString
    $EncryptedPassWord = ConvertFrom-SecureString -SecureString $SecureString
    Set-Content -Path "C:\tmp\mypass.txt" -Value $EncryptedPassWord
    

Con el bloque anterior vamos a guardar en un archivo de texto la contraseña ya encriptada.

Ahora como vamos a hacer para poder utilizar esta contraseña dentro de nuestros scripts, con el siguiente código:

    $EncryptedPassWord = Get-Content -Path "C:\tmp\mypass.txt"
    $SecureString = ConvertTo-SecureString -String $EncryptedPassWord
    $Credentials = New-Object System.Management.Automation.PSCredential "UserName", $SecureString
    

Vamos va revisar lo anterior: Primero se obtiene la contraseña encriptada del archivo de texto. Luego se guarda en la variable **$SecureString**, para posteriormente generar un objecto PSCredential (el mismo objeto que genera el Cmdlet _Get-Credential_) usando la contraseña definida en la variable **$SecureString** y definiendo el nombre del usuario como **UserName**.

Ahora bien, ya con este último procedimiento vamos a tener una mejor idea de como se manipulan las credenciales en PowerShell.
