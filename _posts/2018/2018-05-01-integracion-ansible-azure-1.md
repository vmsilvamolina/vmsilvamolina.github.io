---
title: Integración de Ansible y Azure (parte 1)
date: 2018-05-01T18:57:00+00:00
author: Victor Silva
layout: post
permalink: /integracion-ansible-azure/
excerpt: "En los días que corren, el concepto de IaC (Insfrastructure as Code) se ha vuelto moneda corriente entre los sysadmins. Por ello, creo que es necesario hablar sobre las posibilidades que Azure nos brinda realizar las tareas de la mejor manera posible."
categories:
  - Azure
tags:
  - Ansible
  - Azure
  - PowerShell
  - Infrastructure as Code
  - Azure Cloud Shell
---

<div>
<b>Note:</b>
<p>Este post pertenece a una serie de publicaciones relacionadas:</p>
<li>Integración de Ansible y Azure - Introducción</li>
<li><a href="https://blog.victorsilva.com.uy/integracion-ansible-azure-2/">Integración de Ansible y Azure - Hello world!</a></li>
<li><a href="https://blog.victorsilva.com.uy/integracion-ansible-azure-3/">Integración de Ansible y Azure - Desplegar una VM</a></li>
</div>{: .notice}

En los días que corren, el concepto de **IaC** (*Insfrastructure as Code*) se ha vuelto moneda corriente entre los sysadmins. Por ello, creo que es necesario hablar sobre las posibilidades que Azure nos brinda realizar las tareas de la mejor manera posible.

Si bien existen varias alternativas para abordar el tema de considerar la "infraestructura como código", creo que una de las herramientas que está creciendo día a día es Ansible.


## Introducción a Ansible

Ansible es un software que cae dentro de la categoría *Configuration Management Tools*. Su uso principal radica en la posibilidad de escribir en un lenguaje declarativo la configuración que debe poseer un determinado servidor (o un grupo) en los llamados **playbooks**, para posteriormente asegurarse que esos servidores se encuentren configurados tal como se definió.

Los playbooks estpan estructurados usando **YAML** (*Yet Another Markup Language*) y soportan el uso de variables (más adelante se demostrará con ejemplos).

A diferencia de otras Configuration Management Tools como *Puppet* o *Chef*, Ansible es **agent-less**, lo que significa que no requiere la instalación de ningún software en los servidores administrados. Ansible utiliza *SSH* para administrar máquinas Linux y *PowerShell* (de forma remota junto a WinRM) para administrar sistemas Windows.

Ansible incluye una suite de módulos para interactuar con ARM (Azure Resource Manager), ofreciendo mejores herramientas para crear y orquestar de forma sencilla la infraestructura en Azure. Estos módulos son bibliotecas de Python, debido a que Ansible está completamente escrito en Python y utiliza el *Azure Python SDK*.

## ¿Cómo empezamos a trabajar?

No todos los que usan Azure a diario (sin importar las tareas que realicen) conocen lo siguiente:

[Azure Cloud Shell](https://shell.azure.com)

<img src="https://alqurw.ch.files.1drv.com/y4m7h89LcIGxewlFtxbhGa0xWRMcTCJaUGK2RvWBLEaG6DNwIO8-_OyRpGyOmVq6iLMRa_D6wDIOz9JGkkfAaIP6HFzFS20u-s2ERDlSA3PsbZ_lSBClYR9TnjuPovygyPRQRDmOTW2SKbYkRgwXaZw0e2vNSsSR3VI5BMiYm-k41fOAlhzPKsoWuD3eqPAqVw285gMG2t_C7kE7S1V-wu0lg?width=802&height=479&cropmode=none" width="802" height="479" alt="Azure Cloud Shell" class="alignnone size-medium" />

Y menos aún, saben que dentro de la shell que proporciona Azure, se encuentra instalado Ansible por defecto. Para comprobar ésto, basta con ejecutar lo siguiente (y de paso vamos a saber la versión que se encuentra instalada):

{% highlight bash%}
  ansible --version
{% endhighlight %}

<img src="https://alqvrw.ch.files.1drv.com/y4mld6QRzFmMDCxo-d8kDWOJ5klGQnFbvty4r2nDkWVmzPCgYDZ1icJ7MkFRv9y_W50p-I3tza7ZbO-GQkHIfemQNiUsK6mfDccQJI-YPLzmLmXH5qaTQv8_9SYcB13Z_R_m6jMyAmNcFuEgICUitp6siuqb6wl4OFjEdr5gawxhM1g-iw7N7qCzN0Jwt4zkOsMgicrvutTClh6FcMesuXxag?width=802&height=532&cropmode=none" width="802" height="532" alt="Ansible version" class="alignnone size-medium" />

Si desean saber que otras herramientas se encuentran disponibles en la Azure Cloud Shell, existe el siguiente enlace:

[Features & tools for Bash in Azure Cloud Shell](https://docs.microsoft.com/en-us/azure/cloud-shell/features#tools)

### Azure credentials

Ansible se comunica con Azure usando un nombre de usuario y contraseña o un **service principal**. Un *Azure service principal* es una identidad de seguridad que puede ser utilizada en aplicaciones, servicios y herramientas de automatización (como Ansible, por ejemplo). El usuario define y controla los permisos sobre qué operaciones puede realizar el service principal en Azure.

Para crear un service principal dentro de la Azure Cloud Shell se debe ejecutar:

{% highlight bash%}
  az ad sp create-for-rbac --query '{"client_id": appId, "secret": password, "tenant": tenant}'
{% endhighlight %}

Más información: [az ad sp create-for-rbac](https://docs.microsoft.com/en-us/cli/azure/ad/sp?view=azure-cli-latest#az-ad-sp-create-for-rbac)

El resultado debería ser similar al siguiente:

{% highlight json%}
  {
    "client_id": "eec5624a-90f8-4386-8a87-02730b5410d5",
    "secret": "531dcffa-3aff-4488-99bb-4816c395ea3f",
    "tenant": "72f988bf-86f1-41af-91ab-2d7cd011db47"
  }
{% endhighlight %}

Para autenticar contra Azure es necesario contar con el *subscription ID*, ejecutando el comando [az account show](https://docs.microsoft.com/en-us/cli/azure/account?view=azure-cli-latest#az-account-show):

{% highlight bash%}
  az account show --query "{ subscription_id: id }"
{% endhighlight %}

### Crear el archivo de credenciales para Ansible

Para proveer de credenciales a Ansible es posible generar variables de entorno o crear un archivo local.

Dentro de la consola vamos a ejecutar los siguientes comandos para crear el archivo de credenciales para Ansible:

{% highlight bash%}
  mkdir ~/.azure
  vi ~/.azure/credentials
{% endhighlight %}

Para los que no tienen mucho dominio del editor de textos **vi**, en esta oportunidad lo único que debemos saber es que para poder ingresar valores en el nuevo archivo *credentials*, es necesario pulsar la tecla **Insert**.
Para guardar los cambios y salir del editor, debemos pulsar la tecla **Esc**, escribir <b>:wq</b> y pulsar la tecla **Enter**.

<img src="https://q17vrw.ch.files.1drv.com/y4m8EBK32TWMxjyvxbdTL1iSrTpqvR4S7CN_dfWw5A0KUWOPQmtQJAHt2whJbFi5LUUspBZh_ALGExW9zNW6B7XxhrJmTvvg1cqoD2K5-h69EjHdbumovq3qhjuG5SxoRGj__m1F_utGKo4s99V-PFmwFXTkxEjVjL9o0sFX2t_TA4X66_ZFzjayA70doWjtrGgduyC82a9s2jUcsWHzL9bog?width=997&height=533&cropmode=none" width="997" height="533" alt="Ansible credentials file" class="alignnone size-medium" />

Los valores a ingresar dentro del archivo tienen que tener la siguiente forma:

{% highlight text%}
  [default]
  subscription_id=xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  client_id=eec5624a-90f8-4386-8a87-02730b5410d5
  secret=531dcffa-3aff-4488-99bb-4816c395ea3f
  tenant=72f988bf-86f1-41af-91ab-2d7cd011db47
{% endhighlight %}

Que corresponden a la salida de los comandos anteriormente ejecutados (*az ad sp create-for-rbac* y *az account show*).

Continuará...

Happy scripting!