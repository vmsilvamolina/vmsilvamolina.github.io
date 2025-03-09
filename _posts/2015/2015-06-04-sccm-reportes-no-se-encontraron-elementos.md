---
title: 'SCCM - Reportes: No se encontraron elementos'
date: 2015-06-04T12:54:19+00:00
author: Victor Silva
layout: post
permalink: /sccm-reportes-no-se-encontraron-elementos/
dsq_thread_id:
  - "4483288581"
categories:
  - Configuration Manager
  - System Center
tags:
  - mofcomp.exe
  - Reportes
  - Reporting
  - SCCM 2012
  - srsrp.log
  - System Center Configuration Manager
---
En estos días me encontré con el siguiente mensaje a la hora de acceder a los reportes del System Center Configuration Manager 2012:

<img src="https://lh5.googleusercontent.com/-8iNtL1z_kGU/VXBecf1e5ZI/AAAAAAAAG-g/r9cFALG1upM/w1044-h374-no/SCCM_Reporting_1.png" width="1044" height="374" class="alignnone" />

> No se encontraron elementos.

Ok, lo primero que voy a revisar es que aparece desde la web de Reporting Services de SQL:

<img src="https://lh6.googleusercontent.com/-ewwbGY3Zsi4/VXBfG5zVRKI/AAAAAAAAG-w/ueKbkFo2KqM/w946-h322-no/SCCM_Reporting_2.png" width="946" height="322" class="alignnone" />

Tampoco aparece nada.

El tema permisos no lo voy a revisar, ya que esto funcionaba hasta hace un tiempo sin problemas. Es por ello que me voy a inclinar en revisar el log correspondiente. Para este caso, el log es **srsrp.log**.

La ruta por defecto es **_C:\Program Files\Microsoft Configuration Manager\Logs\srsrp.log_** y me encuentro con lo siguiente:

<img src="https://lh6.googleusercontent.com/-YajMD7AmF6Q/VXBgfIAeqLI/AAAAAAAAG_U/mvc4_pGjinI/w1044-h548-no/SCCM_Reporting_3.png" width="1044" height="548" class="alignnone" />

> Could not retrieve the reporting service name for instance &#8216;SCCM&#8217;

> Clase no válida

Investigando un poco me encontré con un comando en particular que permite registrar nuevamente el proveedor WMI (en teoría al desinstalar una instancia de SQL).

El comando es cuestión es:

{% highlight bash %}
mofcomp "%programfiles(x86)%\Microsoft SQL Server\número\Shared\sqlmgmproviderxpsp2up.mof"
{% endhighlight %}

Donde <número> corresponde según la versión de SQL, dejo una tabla para comprobar:

| **Versión de SQL**           | **Número** |
| ---------------------------- | ---------- |
| Microsoft SQL Server 2012    | 110        |
| Microsoft SQL Server 2008 R2 | 100        |
| Microsoft SQL Server 2008    | 100        |

En mi caso al tener SQL 2008 R2, el comando que ejecuté fue el siguiente:

{% highlight bash %}
mofcomp.exe "C:\Program Files (x86)\Microsoft SQL Server\100\Shared\sqlmgmproviderxpsp2up.mof"
{% endhighlight %}

<img src="https://lh6.googleusercontent.com/-7pyT9jGWTNE/VXBkuuntapI/AAAAAAAAG_o/Cl1tDyPTyH0/w689-h359-no/SCCM_Reporting_4.png" width="689" height="359" class="alignnone" />

Recomiendo reiniciar el servidor luego de ejecutar el comando.

Luego de ejecutar el comando, revisamos el log y encontramos lo siguiente:

<img src="https://lh3.googleusercontent.com/-G7PvNxc8Cng/VXBliBCfeRI/AAAAAAAAG_4/kisEibqmA-c/w1044-h567-no/SCCM_Reporting_5.png" width="1044" height="567" class="alignnone" />

Y si probamos nuevamente en acceder a los reportes desde la consola de SCCM:

<img src="https://lh4.googleusercontent.com/-QSqAvphmZ50/VXBl2si4aOI/AAAAAAAAHAI/tQUBeYaABAg/w1044-h504-no/SCCM_Reporting_6.png" width="1044" height="504" class="alignnone" />

Solucionado!

Happy scripting!