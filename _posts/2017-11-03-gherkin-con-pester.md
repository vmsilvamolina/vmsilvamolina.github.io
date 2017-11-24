---
title: Utilizando Gherkin con Pester 
date: 2017-11-03T22:17:33+00:00
author: Victor Silva
layout: single
permalink: /gherkin-con-pester/
categories:
  - PowerShell
tags:
  - PowerShell
  - Pester
  - Gherkin
---

Hace un tiempo leí por ahí que Pester tenía una característica secreta, muy interesante, de la que tenía que hablar en mi blog. Para los que no recuerdan que es Pester, les comparto un enlace a un post en el blog del que hablamos sobre [Pester](https://blog.victorsilva.com.uy/pester-framework/). De lo que quiero hablar es sobre la compatibilidad con las especificaciones de características al estilo Gherkin. Para ser sinceros no tenía mucha idea sobre lo que era Gherkin, pero luego de leer un poco entendí que podría ser muy útil.

### Gherkin

Gherkin básicamente es un **Business Readable Domain Specific Language** que permite describir el comportamiento del software sin detallar cómo se implementa dicho comportamiento. Por más información sobre lo que es DSL o Domain Specific Language les recomiendo revisar la entrada en Wikipedia sobre el tema [aquí](https://en.wikipedia.org/wiki/Domain-specific_language). Adicional a lo anterior, su gran propósito es servir para dos pilares fundamentales hoy por hoy en desarrollo de software (y en nuestro caso, scripting): documentación de lo desarrollado y pruebas automatizadas. Es aquí donde entra en relación con PowerShell gracias a Pester.

Esta característica permite definir sus *features* y especificaciones en una sintaxis simple y legible. Entonces vamos a ver que lo primero que va a pasar es que se crea un script de validación que se ejecuta con esa especificación definida. Luego, generará resultados de pass/fail en cada elemento como Pester. Ahora que tenemos una idea general de lo que nos proporciona, vamos a definir nuestra primer especificación.

### Primer especificación

Vamos a comenzar definiendo nuestra primer especificación que por obvias razones va a ser bastante simple. Para ello debemos generar un archivo de texto plano que deben guardarse con la extensión *.feature*, que nos va a permitir procesarla de forma correcta.

Para el ejemplo, vamos a considerar como *feature* la copia de un archivo:

{% highlight plaintext %}
Feature: You can copy one file

Scenario: The file exists, and the target folder exists
    Given we have a source file
    And we have a destination folder
    When we call Copy-Item
    Then we have a new file in the destination
    And the new file is the same as the original file
{% endhighlight %}

El bloque anterior lo vamos a guardar como ***CopyItem.feature***. Ya con este archivo en cuestión tenemos nuestra primer especificación al estilo Gherkin.

Ahora para tener un resultado de lo que generamos, a pesar de que faltan definir componetes, podemos ubicarnos en la ruta donde se encuentra el archivo que acabamos de generar y ejecutamos:

{% highlight posh %}
Invoke-Gherkin
{% endhighlight %}

> Comprobar que se encuentre instalada la última versión de Pester, ya que la compatibilidad con Gherkin no estaba presente en todas las versiones. Para actualizar el módulo basta con ejecutar 'Update-Module -Name Pester'.

Y obtendríamos como resultado:

<img src="https://o4qgrq.ch.files.1drv.com/y4mKPs0Z2aUNTdh4UQehZ3BPqqxOT88RTNII_nFKQ-4X4swxxMBZoogeGcLLggJEItKiNpBiCxpq2KjwaUFSetc8b2HHx5wxr3EAcKbLd4tJTlYswYk-kNT9cZYZuM7T-gXBlbB1TvT_SKb1K9xpHF_ZXClB7XNpIoGGP8-ErrUVuEwnUou8CskshKizCMyYsYUVGNHgXo8dYtAVidPS3aJWA?width=568&height=375&cropmode=none" width="568" height="375" alt="Invoke-Gherkin" class="alignnone size-full" />

Con lo anterior obtendríamos enumeradas todas las especificaciones de las funciones que tenemos definidas, y luego, ejecuta las pruebas correspondientes. Como todavía no hemos creado ninguna prueba, ninguna pasó de forma satisfactoria.

Todas las comprobaciones que se definen para una función de Gherkin se llaman pasos. Para ello es necesario generar un archivo con un nombre con extensión *.Steps.ps1*.

### Definiendo los Steps

Ahora que tenemos definido el concepto de "steps", vamos a definirlos como indica el siguiente archivo, guardándolo bajo el nombre ***CopyItem.Steps.ps1***:

{% highlight posh %}
Given 'we have a source file' {
    mkdir C:\source -ErrorAction SilentlyContinue
    Set-Content 'C:\source\something.txt' -Value 'Data'
    'C:\source\something.txt' | Should Exist
}

Given 'we have a destination folder' {
    mkdir C:\target -ErrorAction SilentlyContinue
    'C:\target' | Should Exist
}

When 'we call Copy-Item' {
    { Copy-Item c:\source\something.txt C:\target } | Should Not Throw
}

Then 'we have a new file in the destination' {
    'C:\target\something.txt' | Should Exist
}

And 'the new file is the same as the original file' {
    $primary = Get-FileHash C:\target\something.txt
    $secondary = Get-FileHash C:\source\something.txt
    $secondary.Hash | Should Be $primary.Hash
}
{% endhighlight %}

Si se presta atención a lo declaradon anteriormente, queda visiblemente que se creó una prueba al estilo Pester para las líneas en la especificación definida. Cada una de las líenas anteriores comienza con una palabra clave: *Given*, *And*, *When* o *Then* (*But* también es una palabra clave válida para utilizar). La descripción se extrae directamente de la especificación, ya que *Invoke-Gherkin* usa esa descripción para hacer la coincidencia.

También quiero señalar que las palabras clave de paso (Given, And, When, Then, But) son intercambiables dentro del código.

* Given - Configurar o preparar una acción
* When  - Para las acciones
* Then  - Para la validación
* And y But - Permiten que la especificación fluya mejor y coincida con cualquier prueba de Given, When y Then
