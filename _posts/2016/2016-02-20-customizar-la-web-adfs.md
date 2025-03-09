---
title: 'Customizar la web de ADFS - Parte 1'
date: 2016-02-20T21:45:22+00:00
author: Victor Silva
layout: post
permalink: /customizar-la-web-adfs/
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";N;s:10:"author_url";N;s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";N;s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:4:"none";s:3:"url";N;}'
dsq_thread_id:
  - "4629424109"
categories:
  - Active Directory
  - Active Directory Federation Services
tags:
  - ADFS
  - Default Webpage
  - Federation Services
  - sts portal
---
## Se puede customizar la web de ADFS?

Hace unos días terminé un proyecto que incluía ADFS para validar las credenciales de los usuarios contra el Active Directory local, usando los servicios de Office 365. En el proyecto visualicé varias veces el sitio por defecto que trae el rol de Active Directory Federation Services, entonces me pregunté: se puede modificar y/o mejorar este sitio? Días después me dispuse a escribir este post para compartir mi experiencia.

<img src="https://lh3.googleusercontent.com/aK82hNJWPiJMRWAm44mzOTl_-irOoKy5-laKZIlj_Zxd3v8VqnlX39SVlECNG8PLimHkqjmiC5hTgoXLDOWHnKfA8-3JNJNTijcAaWHNcJ9aJcuPnSmA79OZcCo1hc62ih_d87OKkZl8RHkXzon_h9zGMP-EiEn8fKJ2iMdlJlt-TgeWTqglw3nWhZSY70npHNPZ03r9tyUgZMU_l1WP-Ux1_ntAmfQByFRvz2xxmChUClQmsm8_nT28Nxg_HtaDNMHgld9QaI-Ejle0q3i33W8nnUQDzgkDsgUFtEB9bTHrZzXrTd8PrgOrWvC7XZk_mKiCkWQgDNvBLCFxjRW2nfVL2FNT-gFeHTezz2tF7tjIzbiiiAdRSh4GIHD_7HyMNv6h7j5hjniHrG53A3sS29MZjE8lRam9ltzqfemJiYZcRGH0lo7IWymQjcC6EvfwLCP9n5ddhhc_M28SCsD8QBYZTFXKsTYWssb9gSn8DlW5MbcpkSyMsMj7x553-v6nD-SqTo9ODcaVduUt858DVhue6SYcZWG4xDldO1yvtjgJZfOCR1pVjDYb_ceonI5q9j_D=w866-h633-no" width="866" height="633" alt="Customizar la web de ADFS" class="alignnone" />

## Primeros pasos

Antes de comenzar vamos a ver que partes componen el sitio de ADFS:

> Imagen

Ahora que definimos las partes, vamos a ver cómo podemos hacer para poder modificarlas:

<img src="https://lh3.googleusercontent.com/37RSOXhNcuA7S-mKhLNImKRBFoZeuHWlRW6TYj-KVkupOVhXD2k-yrqZtieocL7U1QhsNq0oxyqdWd7e0jl2Vq6qGiaPLhLWJyRsSLM0pTP0Z6412Z6wdqLIjFxLn8Gy8Ken_54AYxTkoWgqPB8jcMkA2tE4W2SqLdZ68bkcOsKZk8UMhFh5UngfrxKZg72Bycia0fXE1I6Me6staMGcaub30J8zZSpyiJvzCLuWMcUI2qcOAwbZHBEGNvsNyiz4NpFoh0N6th97PCNF5GhB5FLkE2qqwQ5JQThqmXTW4Eq7kfn0X0A4y-7VcpIAHnfPONF-r2eTzdpSm26dWiDTXh24pECRqL9HPDorC7gFjr341TUZMeIm-6k0XFk4wvmhOFJ_Maq_BhOPz9pl0dx5mO-Trv2Pp4DanHLv6TYE98EYMw54nuWAyW2ne9pJd6sijzmGrGTTuPuxismcJzexhjKkduZSlbI7Fevh_iplrV-tnzsXgDMyAOuQt8fz7ctKlHUUtqk0tPfsrzDRzRsSikw6LV25ue6-VTHZ2OxSJlurGX7XUr0RP2Cq11JG1tgnI06y=w645-h425-no" width="645" height="425" alt="Secciones del portal ADFS" class="alignnone" />

### Nombre de la organización

Para modificar el nombre de la organización, tenemos a nuestra disposición un comando de PowerShell que nos facilita esta tarea:

[Set-AdfsGlobalWebContent](https://technet.microsoft.com/en-us/library/dn479402%28v=wps.630%29.aspx)

Una ejemplo de uso de este comando puede ser:

{% highlight posh%}
Set-AdfsGlobalWebContent –CompanyName "Contoso Corp"
{% endhighlight %}

### Logo de la organización

Ya sabemos como modificar el Nombre de la organización, ahora vamos a modificar el logo de la empresa para que le brinde al sitio una imagen más personalizada. Es necesario tener presente la ruta donde se encuentra el logo de la organización, que debe tener como medidas recomendadas 260&#215;35 @ 96 dpi y no debe pesar más de 10 KB.

Considerando lo anterior vamos a ejecutar el siguiente cmdlet:

{% highlight posh%}
Set-AdfsWebTheme -TargetName default -Logo @{path="C:\Imagenes\Contoso-logo.png"}
{% endhighlight %}

El parámetro **_TargetName_** es obligatorio. En el ejemplo anterior declaramos el valor como _default_, ya que es el valor por defecto al generar una implementación de ADFS.

### Ilustración del sitio

Tomando el caso anterior, tenemos que las medidas recomendadas para la imagen que aparece en mayor medida en el sitio son 1420&#215;1080 pixels @ 96 dpi y el tamaño no debe ser superior a 200 KB. PowerShell nos facilita la tarea ya que debemos ejecutar el mismo cmdlet que para el caso del logo, pero esta vez declarando el parámetro _Illustration_:

{% highlight posh%}
Set-AdfsWebTheme -TargetName default -Illustration @{path="C:\Imagenes\Contoso-illustration.png"}
{% endhighlight %}

### Descripción

También es posible agregar un pequeño bloque de texto para que los usuarios puedan leer a modo de información, sugerencias, etc.

{% highlight posh%}
Set-AdfsGlobalWebContent -SignInPageDescriptionText 
{% endhighlight %}

"Para iniciar sesión en el sitio es necesario contar con un usuario ya creado. Clic [aquí](http://intranet.contoso.com/registration/) para solicitar el alta."
    

Con el ejemplo anterior generamos un párrafo para dejar en claro que es necesario tener habilitado un usuario para acceder a ese sitio. Se puede usar HTML en el parámetro, por lo que pueden resaltar o generar vínculos como el del ejemplo.

### Pie de página

Dentro del sitio se pueden habilitar 3 tipos diferentes de enlaces que proporcionan información al usuario, éstos son:

  * Home
  * Privacy
  * Help

#### Home

Define el enlace para crear un vínculo a, por ejemplo, la intranet de la empresa:

{% highlight posh%}
Set-AdfsGlobalWebContent -HomeLink 'https://intranet.contoso.com' -HomeLinkText Inicio
{% endhighlight %}

#### Help

Define el link de acceso a al gún portal de ayuda para el usuario o el sitio donde se generan los incidentes, por ejemplo:

{% highlight posh%}
Set-AdfsGlobalWebContent -HelpDeskLink 'https://intranet.contoso.com/help/' -HelpDeskLinkText Ayuda
{% endhighlight %}

#### Privacy

En caso de que la organización disponga de un acuerdo de confidencialidad o de alguna política de privacidad, se puede disponer de un vínculo a esta información de la siguiente manera:

{% highlight posh%}
Set-AdfsGlobalWebContent -PrivacyLink 'https://intranet.contoso.com/privacy/' -PrivacyLinkText Política
{% endhighlight %}

Hasta acá sería el primer bloque de modificaciones que vamos a ver. En la siguiente publicación vamos a ver como armar un theme propio y como aplicarlo usando PowerShell.

Happy scripting!