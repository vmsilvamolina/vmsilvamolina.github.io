---
title: Excel desde PowerShell
date: 2016-04-17T20:35:15+00:00
author: Victor Silva
layout: post
permalink: /excel-desde-powershell/
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";s:68:"https://cdn-images-1.medium.com/fit/c/200/200/0*Sz3Js055VwE6KyPu.jpg";s:10:"author_url";s:33:"https://medium.com/@vmsilvamolina";s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";s:12:"dc4a8693f7cf";s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:6:"public";s:3:"url";s:69:"https://medium.com/@vmsilvamolina/excel-desde-powershell-dc4a8693f7cf";}'
dsq_thread_id:
  - "4793629735"
categories:
  - PowerShell
tags:
  - Excel
  - Excel.Application
  - Microsoft Excel
  - PowerShell
---
A continuación vamos a ver como usar Excel desde PowerShell, como crear archivos, manipularlos y darles formato desde la consola de PowerShell.

Manipular datos hoy es uno de los tareas fundamentales dentro de las áreas de sistemas, en especial dentro de los departamentos de infraestrucutra y administración de sistemas. A su vez, Excel es uno de esos programas que nunca pasa de moda, por lo que nunca está de más conocer como sacarle provecho a nuestras tareas diarias.

Para manipular la aplicación Excel, vamos a utilizar plataforma COM ([COM interface](https://msdn.microsoft.com/en-us/library/windows/desktop/ff485850%28v=vs.85%29.aspx)), que básicamente es un conjunto definido de métodos soportados por un objeto, para "
llamar"
 a la aplicación en sí de la siguiente manera:

    $Excel = New-Object -ComObject Excel.Application
    

La línea anterior, nospermite abrir una instancia de la aplicación en nuestra computadora (podemos observar esto, ejecutando el administrador de tareas y revisando los procesos, donde vamos a encontrar el proceso Excel).

### Crear un archivo Excel

Para crear un nuevo archivo de Excel es necesario introducirnos a un nuevo nivel dentro del objecto COM **_Excel.Application_**, usando el método **Add**:

    $WorkBook = $Excel.Workbooks.Add()
    

<img src="https://lh3.googleusercontent.com/CVEVFkVShKTS23p1GtOfm5BMNZzxDM9VSpPS9rrV6PaUTzouebuom3zgjJNPxdYFO_og0jNNPhnX0ppXgEGJwz5-ZSMbABDg9Bq9aquAS9L9m8cIui2YqWdHwj30_53-LjKvgBfS3hOShdWbRgQpnbDc6ra2nkfHEGgsoP05HFpTODKtQ2V-Wcc8aUMUawmpsRuzIb13UP_j080NgJysKdsird0IcV9P8Win5Rbv-gRD8lxaeaCk8B49qpm088cK1scg6PUC8plVM_9gmjYNjLIl_lcLYEm71i3ebP0F3AHfPe7vOqixpBbopY9TPcSFSAVGd55egDTm_XHwaW4phFtCth05ZABp_BcM8n63_f1m90uCwyC8fJjfMVUtxvDHVS1Wy-cr8jUOkgZ4dApQ_1BKluA5M5z-ulTTwY4syve2s9E3yLMSuzg1e9hmnfQMuu17oGo-RpuBaGfYF3E8CKhLzzZnUw_QnXAbqcjR0dRTb2o1RJ5ID0qZKH9ZNq8HPEIzuSOv0J-8nSwJkkxnPgAZqF_R7fQnmo5fJtUwhUJkoWkeWEqkWGtP4tbn3RsorElO=w1097-h375-no" width="1097" height="375" alt="Excel desde PowerShell" class="alignnone" />

### Abrir un archivo

Si en vez de crear un archivo, vamos a abrir uno existente tenemos que ejecutar la siguiente línea en vez de la línea anterior:

    $Path = "C:\Users\Victor\Desktop\Planilla.xslx"
    $WorkBook = $Excel.Workbooks.Open($Path)
    

### Nombrar una hoja

Ya con el archivo abierto (libro) vamos a nombrar la hoja de nuestro _WorkBook_, de la siguiente manera:

    $WorkSheet = $WorkBook.Worksheets.Item(1)
    $WorkSheet.Name = 'Hoja Nueva'
    

### Insertar datos

Ahora que tenemos un archivo para manipular, vamos a insertar datos dentro de la planilla. Con la siguiente línea de código vamos a modificar el valor de la celda A1, insertando el texto "
Hola mundo!"
:

    $WorkSheet.Cells.Item(1,1) = 'Hola mundo!'
    

Ahora, si queremos darle un formato, como por ejemplo, dejar el texto en **negrita**, vamos a hacerlo así:

    $WorkSheet.Cells.Item(1,1).Font.Bold = $True
    

### Guardar archivo

Teniendo todos los cambios hechos en nuestro archivo, vamos a guardarlo con el nombre de _Archivo.xlsx_ y posteriormente a cerrar el proceso en ejecución de la aplicación:

    $WorkBook.SaveAs("C:\Users\Victor\Archivo.xlsx")
    $Excel.Quit()
    

Happy scripting!
