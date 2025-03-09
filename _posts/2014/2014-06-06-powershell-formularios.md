---
title: 'Formularios en PowerShell'
date: 2014-06-06T16:01:02+00:00
author: Victor Silva
layout: post
permalink: /powershell-formularios/
dsq_thread_id:
  - "4478591231"
categories:
  - PowerShell
tags:
  - PowerShell
  - Windows Forms
  - WinForms
  - Forms
---
A la hora de crear nuestros scripts, por necesidad o por tratar de agregar una capa de interacción con el usuario, podemos crear formularios de Windows, por medio de .Net Framework, permitiendo agregar una **GUI** (Graphical User Interface) a nuestros scripts.

Para los que han usado PowerShell en varias oportunidades, estarán acostumbrados a trabajar con objetos. Pues bien, los elementos WinForms también son objetos. Y también se sabe, que cada objeto contiene un conjunto de propiedades y métodos.

Un botón, por ejemplo, tiene propiedades que definen su tamaño, posición, ubicación, texto y muchas más. Todas ellas definibles.

En cambio dentro de los métodos (mucho menos utilizados) se destacan por su uso constante: los eventos. Los formularios de Windows Forms son event driven. Esto significa que, después de haber creado la ventana, colocado los botones, etiquetas y demás, simplemente espera a que algo suceda. Espera a que nosotros hagamos clic en un botón, ingresemos algún texto, o lo que sea que nos haga reaccionar nuestro formulario. Y para configurar estas reacciones a las acciones, es que tenemos los eventos.

Cada elemento tiene una gran cantidad de eventos para todo tipo de cosas. Los obvios, como el botón izquierdo del ratón sobre un botón o un texto ingresado en un cuadro de texto, pero también algunos no tan obvios.

## Creando nuestro primer formulario

Para este primer ejemplo, vamos a describir los pasos para poder crear un formulario que nos muestre un botón (con el texto: salir) que al realizarle un clic con el botón izquierdo nos cierre el formulario.

A continuación dejo el código comentado para que pueda entender cada paso y cada línea de comandos:

{% highlight posh %}
#Cargo los Assemblies (necesario para definir el form)
[void][reflection.assembly]::loadwithpartialname("System.Windows.Forms")
[void][reflection.assembly]::loadwithpartialname("System.Drawing")
#Creo el objeto Form
$Form = New-Object System.Windows.Forms.Form
#Defino el tamaño del formulario
$Form.Size = New-Object Drawing.Size(400,200)
#Defino la posición inicial
$Form.StartPosition = "CenterScreen"
#Defino el titulo del formulario
$Form.Text = "Mi primer formulario"

#Defino el botón
$Button = New-Object System.Windows.Forms.Button
#Defino la posición del botón
$Button.Location = New-Object System.Drawing.Size(150,100)
#Defino el texto del botón
$Button.Text = "Salir"
#Defino el evento al hacer el clic
$Button.Add_Click({$Form.Close()})
#Cargo el botón al formulario
$Form.Controls.Add($Button)

#Ejecuto el formulario
[void]$Form.ShowDialog()
{% endhighlight %}

Fácil no? Bien, ahora podemos seguir agregando elementos y otro tipo de eventos a nuestro formulario.

Otro elemento muy usado aparte del botón, son las etiquetas (labels) que permiten agregar texto para hacer referencias, como el siguiente ejemplo:

<img class="alignnone" src="https://lh5.googleusercontent.com/-gOVpSRs9d9Y/U6COc4fKZEI/AAAAAAAAFCU/uSF5jkplwJg/w477-h275-no/PS_form_label.png" alt="" width="477" height="275" />

El código actualizado con la etiqueta agregada es:

{% highlight posh %}
#Cargo los Assemblies (necesario para definir el form)
[void][reflection.assembly]::loadwithpartialname("System.Windows.Forms")
[void][reflection.assembly]::loadwithpartialname("System.Drawing")
#Creo el objeto Form
$Form = New-Object System.Windows.Forms.Form
#Defino el tamaño del formulario
$Form.Size = New-Object Drawing.Size(400,200)
#Defino la posición inicial
$Form.StartPosition = "CenterScreen"
#Defino el titulo del formulario
$Form.Text = "Mi primer formulario"

#Defino la etiqueta
$Label = New-Object System.Windows.Forms.Label
#Defino el tamaño de la etiqueta
$Label.Size = New-Object System.Drawing.Size(200,20)
#Defino la posición de la etiqueta
$Label.Location = New-Object System.Drawing.Size(110,50)
#Defino el texto de la etiqueta
$Label.Text = "Esto es el texto de la etiqueta"
#Cargo la etiqueta en el formulario
$Form.Controls.Add($Label)

#Defino el botón
$Button = New-Object System.Windows.Forms.Button
#Defino la posición del botón
$Button.Location = New-Object System.Drawing.Size(150,100)
#Defino el texto del botón
$Button.Text = "Salir"
#Defino el evento al hacer el clic
$Button.Add_Click({$Form.Close()})

#Cargo el botón al formulario
$Form.Controls.Add($Button)

#Ejecuto el formulario
[void]$Form.ShowDialog()
{% endhighlight %}

Si prestan atención se creó un nuevo párrafo que define a nuestro nuevo elemento: **Label**

Creo que no es necesario explicar que se realizó para crear la etiqueta, por lo que vamos a pasar a ver otro elemento muy útil a la hora de crear nuestras interfaces gráficas para los scripts Este elemento es el: _**TextBox**_ 

El cuadro de texto es un elemento gráfico que nos permite insertar texto para poder utilizarlo dentro de nuestros scripts.

Vamos a ver como se crea un cuadro de texto, las propiedades son muy parecidas a las de las etiquetas:

{% highlight posh %}
#Defino la caja de texto
$TextBox = New-Object System.Windows.Forms.TextBox
#Defino la posición
$TextBox.Location = New-Object System.Drawing.Size(135,70)
#Defino el texto que viene por defecto
$TextBox.Text = ""
#Cargo en el formulario
$Form.Controls.Add($TextBox)
{% endhighlight %}

Ok, ya tenemos varios elementos de un formulario. Vamos a modificar algunas propiedades y metodos para que cuando hagamos clic con el botón izquierdo sobre el botón, en vez de cerrar el form, nos actualice la etiqueta con el texto ingresado en el cuadro de texto.

Lo primero que vamos a modificar es la etiqueta, para que no nos muestre texto ninguno, para ello vamos a la propiedad Text y modificamos el valor de la siguiente manera:

{% highlight posh %}
#Defino el texto de la etiqueta
$Label.Text = ""
{% endhighlight %}

Esto hará que nuestra etiqueta no muestre texto alguno.

Luego deberemos de modificar el evento del botón, para ello ingresamos las siguientes líneas de código correspondientes al evento *Add_Click*:

{% highlight posh %}
#Defino el evento al hacer el clic
$Button.Add_Click({$Label.Text = $TextBox.Text})
{% endhighlight %}

Con estos ejemplos tenemos muchas posibilidades y cosas para poder probar.

En próximos post vamos a ver mas objetos que podemos agregar a nuestros formularios.

Happy scripting!