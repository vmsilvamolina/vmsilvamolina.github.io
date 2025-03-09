---
title: 'AADSTS50008: SAML token is invalid'
date: 2016-07-01T13:13:56+00:00
author: Victor Silva
layout: post
permalink: /aadsts50008-saml-token-is-invalid/
medium_post:
  - 'O:11:"Medium_Post":11:{s:16:"author_image_url";N;s:10:"author_url";N;s:11:"byline_name";N;s:12:"byline_email";N;s:10:"cross_link";s:2:"no";s:2:"id";N;s:21:"follower_notification";s:3:"yes";s:7:"license";s:19:"all-rights-reserved";s:14:"publication_id";s:2:"-1";s:6:"status";s:4:"none";s:3:"url";N;}'
dsq_thread_id:
  - "5058479644"
categories:
  - Office 365
  - PowerShell
tags:
  - AADSTS50008
  - Office 365
  - Portal STS
  - PowerShell
  - SAML token is invalid
  - STS
format: aside
---
Si están leyendo esto seguramente es porque en Office 365 dentro de una implementación de federación de Active Directory, al intentar acceder al portal STS, les apareció el siguiente error al momento de validar las credenciales:

> AADSTS50008: SAML token is invalid

<img src="https://lh3.googleusercontent.com/3FOE5JRHiVVCunTlNVFhD4Agt0Q0DUFAj2hr_4DKQlKvwl_KM7amSWNoEdDNks3VQ6zI480rLYRctZtHiqiuJZ0GgpQY456Hwg0zxYX4oh5kvPtOQD6bmd5ZIoqbW8aTlcTvdpuuZxyMaHrWLeHc7uiqAoPMCsAHJh8hCXqjEg6qYQgJhavHmvoS6Y25iwviG6eY5b4ROGZ5_8ASI8wSZmG7u90u8OkqYVQLdkWZEOavZGOqXbeDdU3Q7yO-LAO8BH3MyUzBb72zcwhEONWA_xiavzq3YWuvQvtTJhqUIDvFpCWLo1z2qT-QuWWQZvbur3M7iQRw8CHkec9QclfRM6XWvAXwtZFM-BXCHLnzpu5zFmu_Ytzl7WsKKmrv0elM8Na9B5e4VEO4g849gzsiQElAeqt6NrEwK7DfFf7O9FyB8IXqod663ZaFQ2AhZ9PfPVqP-_ywFyLvY_d2m6jGYGfUVAt2UNew0NqSsQvo1I-E8-g0gBEPAj7bikHkKmVxOn3B1e50LE53CdleNxSLslUzX1vkNXyVgaovfuNfC3gjI128uHHS3G1OWm9uf7slV8dvqhpInHjQSl3SeJheNkOUA4kmK2C97n_RPYRk70M8cZD6=w1024-h553-no" width="1024" height="553" alt="AADSTS50008: SAML token is invalid" class="alignnone size-medium" />

Este es un error que puede verse relacionado con diferentes aspectos de la configuración, como cambios en los certificados, o actualizaciones de dominios (adicionales a la organización, por ejemplo). En lo personal simplemente ejecutando un comando pude resolver la solución y volver a estar operativo en menos de un minuto.

Para solucionar este problema es necesario ejecutar el siguiente comando de PowerShell:

{% highlight posh%}
  Update-MsolFederatedDomain -DomainName dominio.com
{% endhighlight %}
    

Si bien el Cmdlet anterior está desarrollado principalmente para realizar cambios en los dominios, para este escenario basta simplemente ejecutarlo. Y, que de cierta manera, se vuelvan a configurar los parámetros que teníamos definidos en la implementación.

Cabe destacar [Update-MsolFederatedDomain](https://docs.microsoft.com/en-us/powershell/module/msonline/update-msolfederateddomain?view=azureadps-1.0) pertenece al módulo **_msonline_**, por lo que hay que tener ésta consideración a la hora de ejecutarlo. Lo recomendado es ejecutarlo en el servidor que tiene el portal de ADFS implementado. En todo caso para comprobar que el módulo se encuentre cargado en la consola de PowerShell que tenemos en ejecución, basta con correr:

{% highlight posh%}
  Get-Module
{% endhighlight %}
    

Y de los resultados deplegados, buscar msonline, como se comentó anteriormente.

En caso de que no funcione correctamente lo mejor va a ser realizar un troubleshooting más exhaustivo de la implementación del portal STS o del escenario híbrido en Office 365. Se puede partir el diagnóstigo desde la funcionalidad de los servicios, los certificados que interfieren (o son utilizados) en la publicación de portal y las cuentas de servicios involucradas.

Y si con el cmdlet anterior, funcionó correctamente, les recomiendo revisar cómo [Customizar la web de ADFS](http://blog.victorsilva.com.uy/customizar-la-web-adfs/). El post comparte como darle un cambio visual al portal, agregando logos y textos de ayuda.

Happy scripting!