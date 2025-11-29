---
title: Integración de Ansible y Azure (parte 3)
date: 2018-06-15T18:57:00+00:00
author: Victor Silva
layout: post
permalink: /integracion-ansible-azure-3/
excerpt: "Con lo expuesto en las entradas anteriores sobre Ansible vamos a desplegar una VM en Azure de una forma sencilla utilizando la CLI de Azure y un playbook con unas pocas líneas de código, sin tener que instalar ningún tipo de software adicional."
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
<li><a href="https://blog.victorsilva.com.uy/integracion-ansible-azure/">Integración de Ansible y Azure - Introducción</a></li>
<li><a href="https://blog.victorsilva.com.uy/integracion-ansible-azure-2/">Integración de Ansible y Azure - Hello world!</a></li>
<li>Integración de Ansible y Azure - Desplegar una VM</li>
</div>{: .notice}

Con lo expuesto en las entradas anteriores sobre Ansible vamos a desplegar una VM en Azure de una forma sencilla utilizando la CLI de Azure y un playbook con unas pocas líneas de código, sin tener que instalar ningún tipo de software adicional.

Lo primero obviamente es ingresar a https://shell.azure.com y validar nuestro usuario con las credenciales correspondientes.

Ya habiendo iniciado sesión, el primer paso es generar un Resource Group.

### Resource Group

Desde la consola Azure Cloud Shell ejecutar el siguiente comando:

{% highlight bash%}
  az group create --name Ansible --location eastus
{% endhighlight %}

A modo de comprobar que se ejecutó correctamente el comando anterior, es posible determinar si el recurso fue creado o no, ejecutando:

{% highlight bash%}
  az group list --o table
{% endhighlight %}

### Networking

Luego de contar con el Resource Group, lo siguiente es crear la red a la que se va a conectar la VM:

{% highlight bash%}
  az network vnet create --resource-group Ansible --name vNET --address-prefix 10.0.0.0/16 --subnet-name Subnet --subnet-prefix 10.0.1.0/24
{% endhighlight %}

En caso de querer observar si los recursos de networking han sido creados satisfactoriamente, se encuentra a disposición la siguiente línea de código:

{% highlight bash%}    
  az resource list --resource-group Ansible --o table
{% endhighlight %}

### Obtener nuestra clave pública

Para conectarnos de forma más segura, en lugar de definir una contraseña, vamos a utilizar una clave pública (para ello previamente se deben de haber realizado los pasos definidos en la siguiente entrada https://blog.victorsilva.com.uy/integracion-ansible-azure/):

{% highlight bash%}
  cat ~/.ssh/id_rsa.pub
{% endhighlight %}

### Crear el Playbook

Luego de cumplir con los requisitos para el despliegue, resta generar el archivo .yml donde se definirán los recursos a implementar en Azure:

{% highlight bash%}
  vi azure_create_vm.yml
{% endhighlight %}

Dentro del archivo que acabamos de generar, debemos insertar la siguiente información:

{% highlight plaintext%}    
  - name: Create Azure VM
  hosts: localhost
  connection: local
  tasks:
  - name: Create VM
      azure_rm_virtualmachine:
      resource_group: Ansible
      name: CentOS
      vm_size: Standard_DS1_v2
      admin_username: vmsilvamolina
      ssh_password_enabled: false
      ssh_public_keys: 
          - path: /home/vmsilvamolina/.ssh/authorized_keys
          key_data: "ssh-rsa AAAAB3Nza{spin}q4711"
      image:
          offer: CentOS
          publisher: OpenLogic
          sku: '7.5'
          version: latest
{% endhighlight %}

### Ejecutar el Playbook

Resta únicamente ejecutar el Playbook para aprovisionar nuestra VM en Azure desde la consola Azure Cloud Shell:

{% highlight bash%}    
  ansible-playbook azure_create_vm.yml
{% endhighlight %}

En caso de querer identificar la IP pública de la VM recién implementada, una opción es ejecutar lo siguiente:

{% highlight bash%}
  azure vm show Ansible CentOS | grep "Public IP address" | awk -F ":" '{print $3}'
{% endhighlight %}

Y así termina esta serie de posts relacionados con Ansible y la relación con Azure. Seguramente escriba más posts sobre Ansible porque realmente es una excelente herramienta que todos los admins o roles relacionados con DevOps deben conocer.

Happy scripting!