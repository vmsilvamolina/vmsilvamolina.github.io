---
title: Temas en Windows PowerShell ISE
date: 2016-05-07T13:09:18+00:00
author: Victor Silva
layout: post
permalink: /temas-en-windows-powershell-ise/
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";N;s:10:"author_url";N;s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";N;s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:4:"none";s:3:"url";N;}'
dsq_thread_id:
  - "4852153062"
categories:
  - PowerShell
tags:
  - ISE
  - ISE Themes
  - Temas para la ISE
  - Themes
  - Windows PowerShell ISE
---
Para los que les gusta modificar y cambiar las cosas y no se conforman con las cosas _por defecto_, hoy quiero compartir como agregar un tema en nuestra querida **ISE** de PowerShell. Los temas en Windows PowerShell ISE permiten cambiar la visual a la hora de escribir nuestros scrits, ya sea por comodidad visual (algunos prefieren temas claros y otros _darks_) o simplemente por la estética de nuestra consola.

## Fuente

Lo primero que vamos a ver es un repositorio de temas. Estos temas son creados en base a los que usa [Eclipse](http://www.eclipsecolorthemes.org/):

[https://github.com/marzme/PowerShell\_ISE\_Themes](https://github.com/marzme/PowerShell_ISE_Themes)

Hay varios interesantes dentro de la lista. En lo personal me gustó **_Ambients_**:

<img src="https://lh3.googleusercontent.com/d9nOuRpVRqzGrTCV6mKFHylIZgBDhWzP_3MiV78b-pMctOn7NAnjpdFf2XKAbC5eiBAOMJGoN_bEJU3i_jU-e8E46aV4JxI9-qXoamiDjC3NTS8VjqOWWISupneE8d0JnfeT-l0FYTW2OZ8oRMRy19QQx58ieT4aGqBFS25ZY072UII6Ij8sKhoNeOSGaughuh4AvQxnLzKMcynsznek2T_6-1ANCPexMJyI2kyhiZHLttsRWRf_dhMvH8wWK6H-yqF2ddu9evNQqyUaeoQhLncPEzfcRWSs_NdE3qEYyENtB6LuvfVH3qQCeOkItQAca23yE9hzynnaUFoG5FXt1zSWAXx_zewyWD-Sj8yyGZc0jJ3KozF5NXmLJ6l_WTxI8POnliHmJj6K-DHS98NIyKFkkODigmt2wtnn1Mq7dCMPS78vyr4IEeiv61UKDBM690ym4J5cifZqSErqi7muG0YpQ61tV-paJV0gPv2iA4u3KJELztA_tuvN9i0Vd8EUvMkSJTXcEIhI90g9221ZZ5jpapGLM3-f0wL8UMINibBoTiVeb9eEdTWDASuxYFSZdG9so11zbx__Ug7tG1vBZ_5BLmH-Srs=w522-h148-no" width="522" height="148" alt="Windows PowerShell ISE Ambients theme" class="alignnone" />

## Cómo cambiar el tema?

Ahora que tenemos varios temas para elegir, vamos a ver como tenemos que hacer para poder modificar el tema por defecto en nustra **_ISE_**, para ello primero tenemos que tener los archivos que definen los temas localmente, por lo que les voy a compartir el enlace para descargarlos a todos: [Temas](https://github.com/marzme/PowerShell_ISE_Themes/archive/master.zip)

El compilado anterior cuenta con 22 temas para poder instalar. Todos los temas están ordenados en carpetas y cuentan con una imagen que ejemplifica el resultado final luego de aplicarlo.

Si prestan atención a los archivos tienen una extensión especial (_NombreDelTema.**StorableColorTheme.ps1xml**_), aunque si lo revisan es simplemente un archivo XML. Por lo que si ustedes quieren generar sus propios temas no creo que sea una tarea muy compleja (salvo lo difícil de elegir los colores y que no quede muy cómodo a la hora de leer y escribir nuestros scripts).

Ahora que tenemos localmente los temas vamos a ir a nuestra consola **_ISE_** y procederemos a acceder al menú _Tools > Options > Manage Themes... > Import..._:

<img src="https://lh3.googleusercontent.com/EZ0u3RQ0QBnvMVJSAG63Ue61_fEhr1NkBIcdiOAx3BKhwBoR-ieOWmFQ4u1aNN2sXlPzQkdig_ZpUmQElE1LypQFllUdV7I0dN5CCeOGoM6YAnVIUyLY1IV_bOAaN3qrUXyjN18FOCyV8yRaWCwIr1ajYo7nQ74GTJWGLWL_ttiIMuVZfUO43O2bxBDSrrTKj30BpPmxwIcmWYPcxMN_3CLHJCyD_WqagFatKovjd6LDO8EMIaWDF9m-Sx5kEO1yWlAZnH07v8yhCxN5we26rcVCBYIUo3kEEj_byyDbveTAZysYH1zXFc4BYl7CqW-VrxsQGK71Z5ku5AfBgOwVhZpj8REc9BWsNjQ1yPzCT3DMKDKzPT3JAgAbu-PnsN-oZx_biw9oCK-ozWXkfCSazIXQbCITEzC1lzqsqVNhdC6GwZBft-F3-0iA8v5cMVRCotg_6Pu9-EHEREtPjsA_YwZqZ2q1bU9DrYizgSVau8UBerQfsjMrM5cPGkbNVQNVPjDoOADGeSqXqFx6w_DTiGSL6MR3qqoA2rVSkhw4ZlEEdFR9R7rBnujUTWiP0_TEp5NZqZ4gX1nASJEbjWiIUk4vQ8fAa5U=w942-h603-no" width="942" height="603" alt="Temas en Windows PowerShell ISE" class="alignnone" />

Vamos a navegar hasta donde se encuentre descargado el archivo _.zip_ que contiene los temas, vamos a extraerlo y luego, en la ruta donde se descomprimió el archivo vamos a seleccionar el archivo del tema que queremos instalar. En mi caso voy a instalar **Ambients**:

<img src="https://lh3.googleusercontent.com/udrWvfqFONKJGGFltzXqT0flqavEFtySs55GLvCluqfwCZNJ8L34p02EvRY2FH_0bcUsFpt8JyKJ5pZfGlJR1T6oli6WImnirEdpyfhsFqXk43Es6x66BALlL_t9mEiTgEf0tHLTUrMsy7cXA3VOcxjyNJiw4tDlaKVlyKJ0AIYvjfnyB-7gzHcU54h7yWtwG35uRa99tDzQAKlgageQdmsZmPpM9p-4eRZvGGRyNzGWrx0-mm5rey0em_4zekx7_V1O0gTg7SSMeb7XDp_iaZOBzPG6dtgoJNmvejCb7Ui6FAPyeHp8nm5SAgyPeMRXjWRBih7kV9Owct0EB7i2hmHMvFleY4nLl-jvsl4DKXUTuFhgy_CE0m4q03nXOoerZPyl9PVPJD5ZNYbJ0-CWnylHs58avNmOZSLc4bjQIHDzSGTAkCVnbsOJ_JG5S_LdoqpdMV4CseaTooTgXKrZ3lxmlRgbyZEenj9hWDl-92YflkQvesm8j_9p1DMM7_zOZ3Hotb9epzqFsPg7D0AZzSeZea1Eqmd7_DaQO9ZRYQNrxpCHyCGXQHxKGl0eS9UtFErpmqCcBilqJIZ2m-BrrN5La6BbzS8=w668-h472-no" width="668" height="472" alt="Temas en Windows PowerShell ISE" class="alignnone" />

Aplico los cambios y... listo! Ya tenemos nuestro tema instalado en nuestro perfil.

<img src="https://lh3.googleusercontent.com/VWipdvcAEG8uMoCnE6IJjnlrb1d_GE3JHVCazhGSJQ6S4qAJ1Oc5dK7nPaveA0Htm17o4XH6S8x-SKXS79s5THriOXShcF0lnAx9dWA7zhjorB29bzAmY_cHoOGPCWtgoQys3QyyATQEkagXYaz6WvtV3T4gLwp3aqdY5iQuLaptXUBrNXc8V8dXGei0ulORbx7Cs8biJ5Jw2r600-rIF4BUVn5I6A4Tfak-i2lCvsb0XAnvBWshsuu_XXwN1GGGQ5eAjevAZm4mHYJk_12gNy_FZ8VLU9PzNbF6YlVF8K52R8LF_7vub70SMxwb6kigOMT3AlWWrOiEhk4Lb5C9d0pdhZlZBQg7Pnb24fVqkLCm_aeCtenCzXTFMgSCzQFKi7eYWVEfiYhJ3DBjIvQDBfhQAGvk3ML4IHfyyffmP0BeldEZ2zFQ8Bkp6BL07uPv1LeuNhr3Sy0fv0PSv2dPH83BRbOreP9tYcbddC4qfd05Opt_OJVz9wfCvznyxPnH73LhYtPzew_EBImc8wM3pY-DX6C8PRLokVD-iArtfQ9K99dP3S38ylXGmGX0vR9HA30nlJti_K-Prn-7xozz9QmLhC3tBJE=w792-h437-no" width="792" height="437" alt="Ambients aplicado a la ISE" class="alignnone" />

Happy scripting!
