---
title: 'Creando usuarios en Active Directory'
date: 2014-04-30T18:34:33+00:00
author: Victor Silva
layout: post
redirect_from: /creando-usuarios-en-active-directory-2/
permalink: /creando-usuarios-en-ad/
dsq_thread_id:
  - "4488050506"
categories:
  - Active Directory
tags:
  - Active Directory
  - AD
  - Crear usuarios
  - Batch
---
A menudo en los dominios los usuarios comparten muchas propiedades similares. Por ejemplo: los representantes del sector ventas pueden pertenecer a los mismos grupos de seguridad, iniciar sesión en el mismo rango de horas y tener carpetas de inicio y perfiles (como también carpetas compartidas) en el mismo servidor. Cuando se crea un nuevo usuario, simplemente se puede copiar de uno ya existente, en lugar de crear una cuenta en blanco y rellenar cada propiedad.

Ahora, que es una plantilla de usuario (template)? Es una cuenta de usuario genérica (previamente completada con propiedades comunes). Solamente alcanza con rellenar las propiedades comunes al sector y listo. Se recomienda que al crear un template de usuario, se configure el nombre con un guion bajo al principio (\_), quedando por ejemplo de esta manera: \_Marketing. Esto hará que queden todos los templates creados en la parte superior de la lista de usuarios de una OU.

>No se debe iniciar sesión con las plantillas. Por lo que se recomienda que se deshabilite el usuario.

## Usando comandos de AD y Excel
Lo primero que vamos a hacer es abrir un notepad y escribir:

{% highlight posh %}
dsadd user "cn=%1, ou=NombreOU, dc=Dominio, dc=Sufijo" - fn %2 -ln %3 -pwd P@ssw0rd -mustchpwd yes
{% endhighlight %}

<img class="alignnone" src="https://lh6.googleusercontent.com/jKOi6ZzbB4QyOm9kbP3NSOZoLXavfC6mG550JDre81s=w605-h264-no" alt="" width="605" height="264" />

Guardar el archivo con un nombre que puedan identificar para que sirve fácilmente , por ejemplo **CrearUsuario.bat**.

Ahora para crear un usuario que tenga como nombre **Tania**, como apellido **Miller** y que el nombre de usuario para iniciar sesión sea **tmiller**, se debe abrir una consola de comandos, navegar hasta la ruta donde se guardó el bat y escribir:

{% highlight posh %}
CrearUsuario tmiller Tania Miller
{% endhighlight %}

Fácil, no? Puede parecer que sí, pero... Se puede automatizar mas la tarea? Que pasa cuando son muchos usuarios a la vez? Y si están en distintas OUs? La solución a esto es crear usuarios en base a una planilla de excel. Esta planilla lo que debe contener es una lista de los nombres y apellidos de cada persona a la que se le deba crear un usuario.  

Bien… ahora partimos de una lista de usuarios creados en excel, de la siguiente manera:

<img class="alignnone" src="https://lh6.googleusercontent.com/-ptV22VcpQXU/UFe3Ig9hTfI/AAAAAAAAA3k/VWuTGAIFFWA/w362-h458-no/excel_1.png" alt="" width="362" height="458" />

A esta hoja la vamos a renombrar, por ejemplo como **InfoDeUsuarios** ya que contiene la info de los nombres, apellidos y a las OU a las que van a pertenecer. En este caso todos los usuarios van a estar debajo de la OU Principal "Usuarios" y van a estar distribuidos entre Marketing, Ventas, Desarrollo y HelpDesk (OUs secundarias).

En la siguiente hoja vamos a especificar los datos que necesitamos para poder armar el script final de la siguiente manera:

  * Nombre de dominio **Contoso.com** (Dominio y Sufijo)
  * En la columna Nombre de Usuario hay que escribir la siguiente función:


{% highlight plaintext %}    
=CONCATENAR(IZQUIERDA(InfoDeUsuarios!A2;1);InfoDeUsuarios!B2;",")
{% endhighlight %}

Lo que hace esta función es armar el nombre de inicio de cada usuario, tomando la primer letra del nombre y el apellido.

  * En la columna OU Secundaria va la función:

{% highlight plaintext %}
=CONCATENAR("ou=";InfoDeUsuarios!C2;",")
{% endhighlight %}

Lo que hace es tomar el nombre de la OU Secundaria de la lista creada en la primer hoja del libro de excel (para este ejemplo se nombro como InfoDeUsuarios)

  * En la columna OU Principal va la función:

{% highlight plaintext%}    
=CONCATENAR("ou=";InfoDeUsuarios!D2;",")
{% endhighlight %}

Toma el nombre de la OU Principal de la primer hoja. Quedando de la siguiente manera:

<img class="alignnone" src="https://lh6.googleusercontent.com/-r3Ed-xArRxw/UFfBbF-H12I/AAAAAAAAA4U/r0uY-2kQNPE/w617-h408-no/notepad3.png" alt="" width="617" height="408" />

A esta hoja la vamos a renombrar como **TodosLosDatos**. En la tercer hoja vamos a escribir una única función que vamos a extender a todas las filas que correspondan (cada fila es un usuario):

{% highlight plaintext %}
=CONCATENAR(TodosLosDatos!A4;TodosLosDatos!B4;TodosLosDatos!C4;TodosLosDatos!D4;TodosLosDatos!E4;TodosLosDatos!F4;" ";"-fn";" ";InfoDeUsuarios!A4;" ";"-ln";" ";InfoDeUsuarios!B4;" ";"-pwd";" ";"P@ssw0rd";" ";"-mustchpwd";" ";"yes")
{% endhighlight %}

Esto va a recolectar todos los datos necesarios para poder armar cada línea de comando correctamente con todo lo que nosotros llenamos anteriormente para no tener que escribir uno por uno. El resultado de esta función es lo que vamos a copiar en un notepad y lo vamos a guardar como: **AgregarUsuarios.bat**.

<img class="alignnone" src="https://lh5.googleusercontent.com/-fU1orCiMV0Q/UGzp93yf71I/AAAAAAAAA50/X1nZsDxLYFw/w788-h334-no/excel+3.png" alt="" width="788" height="334" />

Esta pagina si quieren la pueden nombrar como **GuardarComoBat** para tener una mejor referencia en el futuro. Ya con todos las líneas generadas y el archivo *.bat* guardado simplemente vamos a tener que situarnos donde este guardado el archivo y ejecutarlo como administrador. Con esto se van a crear todos los usuarios que estén en esa lista de manera automatizada.

Happy scripting!