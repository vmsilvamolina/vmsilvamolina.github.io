---
title: Accediendo a MySQL desde PowerShell
date: 2017-04-05T13:38:34+00:00
author: Victor Silva
layout: post
permalink: /mysql-desde-powershell/
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";N;s:10:"author_url";N;s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";N;s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:4:"none";s:3:"url";N;}'
dsq_thread_id:
  - "6023105935"
categories:
  - PowerShell
tags:
  - MySQL
  - PowerShell
  - PowerShell Scripting
---

Hace unos días me surgió la necesidad de trabajar con una base de datos con **_MySQL_**, en un servidor Ubuntu, generado desde el marketplace de Azure. Por ello es que estoy compartiendo este post, para dejar accesible estos "apuntes" de lo que sería lo necesario para poder acceder a una base de datos MySQL desde PowerShell.

Para los administradores de sistemas que trabajan en estos tiempos modernos no es nuevo el tener que tomar el control de plataformas heterogéneas. Hoy es común tener ambientes con Windows y Linux conviviendo en el mismo datacenter, así como soluciones que se interconectan entre sí. Por ello es necesario conocer como interactuar con cada sistema en particular.

## Primer paso

A modo de requisito es necesario contar con el [MySQL .NET Connector](http://dev.mysql.com/downloads/connector/net/) en el equipo que va a ejecutar PowerShell:

<img src="https://cu0w0a-ch3302.files.1drv.com/y4marVeE8IrJeCOuh35amZKoK39M8iHHFgfdMBlSPyZ_azOK-m67jiYdcKpVxXxpJxdW46zGH5f41gaqcq9GHQyJVZEUqUwHOjyWamNEclpaj8kdmN9DNXZNlbb6zHusg_POEopxIWB69jYiNpCo0Rr2_gHBOt1D_XDLQhzJYZ9UWcg-1avorEJ5TYdyADayVQ5w5qidnnVEpNdwp61EXh6kw?width=953&#038;height=416&#038;cropmode=none" width="953" height="416" alt="Descarga del conector para MySQL" class="alignnone size-medium" />

Simplemente hay que descargarlo e instalarlo, siguiendo los pasos del asistente que básicamente se reducen a siguiente y siguiente hasta el final.

Posterior a la instalación hay que integrar en el script (o en el bloque de código a ejecutar) lo siguiente:

{% highlight posh %}
[void][System.Reflection.Assembly]::LoadWithPartialName("MySql.Data")
{% endhighlight %}

Y lo siguiente es realizar la conexión y la estructura de información necesaria antes de pasar a detallar el query a ejecutar:

{% highlight posh %}
$MySQLAdminUserName = 'root'
$MySQLAdminPassword = 'Ultr@P@ssw0rd'
$MySQLDatabase = 'databaseName'
$MySQLHost = 'MySQLServer'
$ConnectionString = "server=" + $MySQLHost + ";port=3306;uid=" + $MySQLAdminUserName + ";pwd=" + $MySQLAdminPassword + ";database="+$MySQLDatabase
{% endhighlight %}

Hasta ahora nada raro, simplemente definimos las variables que van a contener nuestra información de conexión, en donde detallamos usuario admin, passsword, servidor, base de datos y el connection string.

Definimos la query a ejecutar:

{% highlight posh %}
$Query = "SHOW tables"
{% endhighlight %}

Lo siguiente es armar una estructura de conexión, que es requerida para poder ejecutar nuestra query (que también vamos a definir) utilizando el conector ya invocado:

{% highlight posh %}
$Connection = New-Object MySql.Data.MySqlClient.MySqlConnection
$Connection.ConnectionString = $ConnectionString
$Connection.Open()
$Command = New-Object MySql.Data.MySqlClient.MySqlCommand($Query, $Connection)
$DataAdapter = New-Object MySql.Data.MySqlClient.MySqlDataAdapter($Command)
$DataSet = New-Object System.Data.DataSet
$RecordCount = $dataAdapter.Fill($dataSet, "data")
$DataSet.Tables[0]
{% endhighlight %}

Y listo! Nuestra primer consulta a MySQL desde PowerShell.

## Organizando el trabajo&#8230;

Ahora que tenemos claro el procedimiento para realizar consultas a nuestra base de datos, vamos a generar algunas funciones para que nos facilite el trabajo a la hora de realizar tareas un poco más complejas con MySQL.

La primera función que vamos a armar es un Cmdlet para realizar la conexión con el servidor:

{% highlight posh %}
function Connect-MySqlServer {

    [OutputType('MySql.Data.MySqlClient.MySqlConnection')]
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [pscredential]$Credential,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$MySQLHost,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [int]$Port = 3306,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$MySQLDatabase
    )


    $MySQLAdminUserName = $Credential.UserName
    $MySQLAdminPassword = $Credential.GetNetworkCredential().Password

    if ($PSBoundParameters.ContainsKey('Database')) {
        $ConnectionString = "server=" + $MySQLHost + ";port=" + $Port + ";uid=" + $MySQLAdminUserName + ";pwd=" + $MySQLAdminPassword + ";database="+$MySQLDatabase
    } else {
        "server=" + $MySQLHost + ";port=" + $Port + ";uid=" + $MySQLAdminUserName + ";pwd=" + $MySQLAdminPassword
    }

    try {
        [MySql.Data.MySqlClient.MySqlConnection]$conn = New-Object MySql.Data.MySqlClient.MySqlConnection($connectionString)
        $conn.Open()
        $Global:MySQLConnection = $conn
        if ($PSBoundParameters.ContainsKey('Database')) {
            $null =  New-Object MySql.Data.MySqlClient.MySqlCommand("USE $MySQLDatabase", $conn)
        }
        $conn
    } catch {
        Write-Error -Message $_.Exception.Message
    }
}
{% endhighlight %}

Perfecto! Tenemos nuestra primer función para conectarnos a nuestro servidor, ahora necesitamos una función que nos permita cerrar la sesión que generamos en el servidor. Para ello vamos a escribir lo siguiente:

{% highlight posh %}
function Disconnect-MySqlServer {

    [OutputType('MySql.Data.MySqlClient.MySqlConnection')]
    [CmdletBinding()]
    Param
    (
        [Parameter(ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [MySql.Data.MySqlClient.MySqlConnection]$Connection = $MySQLConnection
    )

    try {
        $Connection.Close()
        $Connection
    } catch {
        Write-Error -Message $_.Exception.Message
    }
}
{% endhighlight %}

Ya que al definir en la primer función una variable global, podemos invocarla como valor predeterminado del parámetro de nuestra función para desconectarnos y así simplemente ejecutar:

{% highlight posh %}
Disconnect-MySqlServer -Connection
{% endhighlight %}

<img src="https://cu0r0a-ch3302.files.1drv.com/y4mTjuCejvJMHZLvxfoS-4fplwU2TWpBEofIpbVVYJd46j9kJUG_4UlpUaR23l8Y-HprsU9mEDBdCjwfVrVv6feDDEIANIw0tgy_6xgeJQyYowhDKFkjTxAVAzRhVMaKTGsj7Rcq6yzUoC98Hym68GdC-lJaAHMG-dlDWJvygJSeWhLYdKNsZFFP_8dO_O5hkOq4H8PaRwhK1k4K-mw4LPVKQ?width=779&#038;height=281&#038;cropmode=none" width="779" height="281" alt="Cerrando una sesión de MySQL desde PowerShell" class="alignnone size-medium" />

Y listo! Estamos fuera del servidor de MySQL desde PowerShell.

Happy scripting!