--- 
title: "2 maneras de trabajar con XML desde PowerShell" #XML desde PowerShell al desnudo
author: Victor Silva
date: 2020-05-25T16:37:00+00:00 
layout: post 
permalink: /xml-powershell/
excerpt: "Una de las frustraciones más grande con las que uno se encuentra al momento de iniciarse con PowerShell es la simple tarea de introducir y extraer (u obtener) datos. Por consecuente, si se desear avanzar en el camino de luz que PowerShell nos brinda, se debe saber trabajar con XML, ya que es un formato de intercambio de datos esencial y aún vigente para garantizar la preservación de los datos de un objeto. Eso sin contar que PowerShell siempre facilita las tareas..."
categories: 
  - PowerShell
tags: 
  - PowerShell
  - XML
  - Scripting
---

Una de las frustraciones más grande con las que uno se encuentra al momento de iniciarse con PowerShell es la simple tarea de introducir y extraer (u obtener) datos. Por consecuente, si se desear avanzar en el camino de luz que PowerShell nos brinda, se debe saber trabajar con XML, ya que es un formato de intercambio de datos esencial y aún vigente para garantizar la preservación de los datos de un objeto. Eso sin contar que PowerShell siempre facilita las tareas...

## Introducción al acceso de datos XML

Primeramente vamos a ver como importar archivos XML (porque hay varias formas de hacerlo) o generarlos directamente desde la consola a partir de nuestros datos.

> Si aún no tienes muy claro como son los archivos XML, te recomiendo pasar por acá: [Introduction to XML](https://www.w3schools.com/xml/xml_whatis.asp).

Vamos a partir de un documento ejemplo, es un poco viejo, pero sigue funcionando: [Sample XML File (books.xml)](https://docs.microsoft.com/en-us/previous-versions/windows/desktop/ms762271(v=vs.85)).

Ese contenido vamos a guardarlo y vamos a nombrarlo `books.xml`, para este post voy a dejar el archivo en la raíz de mi perfil.

Ya con el archivo listo el siguiente paso es obtener la información del mismo dentro de PowerShell, donde existen varios caminos para tal fin:

{% highlight posh%}
# Método 1
$xDoc = New-Object System.Xml.XmlDocument
$file = Resolve-Path(".\books.xml")
$xDoc.load($file)
# Método 2
[xml] $xDoc = Get-Content ".\books.xml"
# Método 3
$xDoc = [xml] (Get-Content ".\books.xml")
{% endhighlight %}

Fácil, no? 

Ahoa veamos que nos devuelve al invocar la variable `$xDoc`, así como también un poco más de info al respecto:

<img src="/assets/images/postsImages/PS_XML_0.png" class="alignnone">

## Utilizando XPath

Con el archivo cargado en un objeto **XmlDocument**, es posible navegar por el árbol XML utilizando [XPath](https://www.w3.org/TR/xpath/all/). Para seleccionar un conjunto de nodos, use el método `SelectNodes`:

{% highlight posh%}
$xdoc.SelectNodes("//author")
{% endhighlight %}

<img src="/assets/images/postsImages/PS_XML_1.png" class="alignnone">

Donde el resultado es una lista de todos los autores disponibles. Pero hay un pequeño problema: existen repetidos. ¿Cómo sería la mejor manera de poder filtrar con los valores únicos? PowerShell tiene un cmdlet llamado [Select-Xml](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/select-xml?view=powershell-7), que permite realizar esto de la siguiente manera:

{% highlight posh%}
$xdoc | Select-Xml "//author" | % { $_.Node.InnerText } | select -Unique
{% endhighlight %}

O también se encuentra a disposición `SelectingleNode`, para retornr un único nodo:

{% highlight posh%}
#Toda la info del libro
$xdoc.SelectSingleNode("//book[2]")
#Solamente el título
$xdoc.SelectSingleNode("//book[2]/title")
{% endhighlight %}

<img src="/assets/images/postsImages/PS_XML_2.png" class="alignnone">

## Accediendo a XML como Objetos

Siguiendo con el mismo objeto **XmlDocument**, PowerShell también proporciona compatibilidad con objetos dinámicos para datos del tipo XML: esto permite acceder a la información que el objeto XML contiene como objetos de PowerShell, que no requieren ni el selector XPath ni la necesidad de conocer en detalle los nodos XML ni sus valores. Por ejemplo desde VSCode y gracias a Intellisense, es posible acceder al esquema cuando se cargan los datos del archivo XML. El siguiente gif muestra en acción el proceso de obtención de opciones de selección y finalización de las palabras.

<img src="/assets/images/postsImages/PS_XML_3.gif" class="alignnone">

A continuación un par de ejemplos de cómo XML se convierte en objetos de PowerShell:

<img src="/assets/images/postsImages/PS_XML_4.png" class="alignnone">

En donde también podemos acceder de forma individual a cada elemento (libro, en este caso) y sus respectivos datos:

<img src="/assets/images/postsImages/PS_XML_5.png" class="alignnone">

Vale la pena destacar que todos los XML nodes del documento se convierten en propiedades de PowerShell, donde los valores de los elementos y los valores de los atributos se tratan exactamente de la misma manera: utilizando la notación de "punto" estándar.

## Extra: Cambiar información 

Para poder trabajar correctamente con el formato XML debemos tener en cuenta el procedimiento para actualizar valores, por ejemplo. Para ello el siguiente bloque de código ejemplifica el procedimiento para ello:

{% highlight posh%}
$item = Select-XML -Xml $xDoc -XPath '//book[title="Midnight Rain"]'
$item.Node
$item.Node.price = 4.95
$xDoc.Save(".\booksNewPrice.xml")
{% endhighlight %}

Donde al revisar el archivo anterior obtenemos el precio del libro actualizado, según nuestra modificación:

{% highlight posh%}
Get-Content .\booksNewPrice.xml | Select-String "Midnight Rain" -Context 2,7
{% endhighlight %}

<img src="/assets/images/postsImages/PS_XML_6.png" class="alignnone">

Happy scripting!