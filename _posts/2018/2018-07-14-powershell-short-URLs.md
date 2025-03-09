---
title: Acortar URLs con PowerShell
date: 2018-07-14T15:57:00+00:00
author: Victor Silva
layout: post
permalink: /powershell-short-URLs/
excerpt: "Desde hace un tiempo soy usuario de Bit.ly, si no lo conocen la explicación más breve es un servicio (y app) para acortar los links (URLs). Dentro de las opciones que permite se encuentran: Modificar el nombre, Agregar etiquetas, Dashboard de información, Cantidad de clics en el enlace."
categories:
  - PowerShell
tags:
  - PowerShell
  - Short URL
  - Bit.ly
  - Acortar enlaces
---

Desde hace un tiempo soy usuario de [**Bit.ly**](https://app.bitly.com), si no lo conocen la explicación más breve es un servicio (y app) para acortar los links (URLs). Dentro de las opciones que permite se encuentran:

- Modificar el nombre
- Agregar etiquetas
- Dashboard de información
- Cantidad de clics en el enlace

Realmente es muy útil, y la utilizo para compartir mis demos, PPTs, código, etc. ya que me permite generar un enlace fácil de recordar y asociado al contenido.

Hace un tiempo utilizo la API para trabajar desde PowerShell porque creo que es un poco ir contra la corriente hacerlo por la web, debido a que la API es muy simple, por ello quiero compartir el procedimiento.

### API, ¿cómo tengo acceso a ella?

Lo primero es ingresar a la siguiente URL: https://bit.ly, iniciar sesión (pueden registrarse también con una cuenta de Twitter, Facebook o Google) y luego seleccionar la cuenta desde el menú para acceder la opción **edit profile**. Dentro de edit profile, se encuentra la opción ***Generic Access Token***:

<img src="https://wmdtzg.ch.files.1drv.com/y4m-hIPWa6QU6mufC9NJoH2QK5TRTPHSi5j8-Z-dR6AkYRbMpy02qrr9kTknCAZT_4X7uwxNum3KbyDtJoFRdfIg8cnxdOxXAMWS6TDKdjYNqCN6tnjdqKU_9VYbHn4oeJHceDZEtjlNFK2Cgr4bICWKwm_eBTDGDZSnrs6W6Atny6DgBI_rxzT31y9KJBe-8RWzWPC3-_JMU5UmwbdC66QVw?width=303&height=564&cropmode=none" width="303" height="564" alt="Bit.ly access token" class="alignnone" />

Para generar un token, se debe ingresar la contraseña de la cuenta y seleccionar el botón **Generate token**. Ya con el token generado, lo siguiente es ejecutar el siguiente bloque de código, donde guardamos el resultado en la variable <strong>$MyURL</strong>:

{% highlight posh%}
	$OAuthToken = "b21c4a6***************************b709bd"
	$LongURL = "https://blog.victorsilva.com.uy"
	# Llamada a la API
	$MyURL=Invoke-WebRequest -Uri https://api-ssl.bitly.com/v3/shorten -Body @{access_token=$OAuthToken;longURL=$LongURL} -Method Get
{% endhighlight %}

<img src="https://htfaww.ch.files.1drv.com/y4m4EFmNainLkGOZWpbBlWvU_HKJs7LgxyqteB-Lv7_o-M6oZOEXpFH3UYw-jcmdWKWqF3kKZfHdYve7MbyTDJSoMq1_G23XSHKBd156A8f-r_zo4ukx9CkFqb_QaPSEbKyN6LcfFz0uFnITf2DVpBBXxz76LnVFA5chpr64vhMqq5zQ_z0SnJL4o4hcowGzHkmAJ5Mg3Iguj0KDCDtdhBfJg?width=889&height=452&cropmode=none" width="889" height="452" alt="API de Bit.ly en PowerShell " class="alignnone" />

Ahora que tenemos el resultado, podemos observar que se encuentra la URL dentro de la información que despliega la salida en consola de la variable *$MyURL* (la URL corta es: "http://bit.ly/2uYW60F").

Para poder organizar mejor la información es posible convertir a JSON todos los datos:

{% highlight posh%}	
	#Guardar la información como JSON
	$MyURLjson = $MyURL.Content | convertfrom-json
	# Imprimir la URL
	$MyURLjson.data.url
{% endhighlight %}

<img src="https://ikybqg.ch.files.1drv.com/y4meHEWZ_LDJxiSM9j-jYvT5EGEBqzDlBP_jZs5gwEaTuEHTVbzIfkTOvjZItukix6IO86o6tZUmFA-yoBt_BDJAHSOfP0Dgbm1UcGgQyjFnAgD2MHqAeXT__iafbuv1lZWHYbWvBvdZOLcjA9yYm-fZkHy5ziA41WBGdt4kscEkbLTsrxkaIFggn_nI4LmhDIUpkxbidJSLl-Bk323vzIAjg?width=889&height=149&cropmode=none" width="889" height="149" alt="Filtrar el resultado en JSON" class="alignnone" />

### Siguientes pasos...

En caso de utilizar esto de forma frecuente, o al menos, pensando en organizar mejor esta funcionalidad es que vamos a armar una simple función.

El código para ello es el siguiente:

{% highlight posh%}
	function Short-URL {
	    [CmdletBinding()]
    	param(
        	[Parameter(Mandatory=$true)][string]$LongURL
    	)
		$OAuthToken = "b21c4a6***************************b709bd"
		$MyURL=Invoke-WebRequest -Uri https://api-ssl.bitly.com/v3/shorten -Body @{access_token=$OAuthToken;longURL=$LongURL} -Method Get
		$MyURLjson = $MyURL.Content | ConvertFrom-Json
		$MyURLjson | Select-Object @{Name="Short URL";Expression={($_.data.url)}}, @{Name="Long URL";Expression={($_.data.long_url)}}
	}
{% endhighlight %}

<img src="https://jqpgkw.ch.files.1drv.com/y4mfiYPVgyyIM1wVJX3qDM4q_Z_TNU-iO_CH4ddNo_QYMag590F2tCdKdPHeG--qOg2FvsA8CGN-A8eS5MkvgXEaLLQD0VkDo3qnZ3ZhMlQUi18rHI4VJrJyrQJO7ZrnsBYIQcKB8Dj6DLFed2EF-nHqcfghaRyic8-aup81e3czhqAmd-3A_LH1i0q0UV-9zKdWdCLSOoxDr3Qrlw34CpzPg?width=859&height=185&cropmode=none" width="859" height="185" alt="Función utilizando la API de Bit.ly" class="alignnone" />

Por más información, el enlace a la documentación es el siguiente: https://dev.bitly.com/

Happy scripting!
