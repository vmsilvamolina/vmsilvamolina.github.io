---
title: Evento de Red Hat (y Azure)
date: 2018-08-25T18:57:00+00:00
author: Victor Silva
layout: post
permalink: /evento-red-hat-azure/
excerpt: "El pasado Jueves 23/8 se realizó un evento de Red Hat, donde el objetivo del mismo fué hablar sobre DevOps, Automatización y PaaS organizado por AT. Tuve la suerte de que me invitaran a mostrar en vivo el uso de Ansible y Azure; los módulos disponibles junto a la manera de trabajar y como poder utilizar Ansible con plataformas Windows por medio de WinRM."
categories:
  - Azure
  - DevOps
tags:
  - Azure
  - DevOps
  - Red Hat
  - Ansible
  - PowerShell
gallery:
  - url: /assets/images/EventoRedHat/Evento-RedHat-Azure_01.jpeg
    image_path: /assets/images/EventoRedHat/Evento-RedHat-Azure_01.jpeg
    alt: "DEMO de Ansible con Azure"
    title: "DEMO de Ansible con Azure"
  - url: /assets/images/EventoRedHat/Evento-RedHat-Azure_02.jpeg
    image_path: /assets/images/EventoRedHat/Evento-RedHat-Azure_02.jpeg
    alt: "DEMO de Ansible con Azure"
    title: "DEMO de Ansible con Azure"
  - url: /assets/images/EventoRedHat/Evento-RedHat-Azure_03.jpeg
    image_path: /assets/images/EventoRedHat/Evento-RedHat-Azure_03.jpeg
    alt: "DEMO de Ansible con Azure"
    title: "DEMO de Ansible con Azure"
  - url: /assets/images/EventoRedHat/Evento-RedHat-Azure_04.jpeg
    image_path: /assets/images/EventoRedHat/Evento-RedHat-Azure_04.jpeg
    alt: "DEMO de Ansible con Azure"
    title: "DEMO de Ansible con Azure"
  - url: /assets/images/EventoRedHat/Evento-RedHat-Azure_05.jpeg
    image_path: /assets/images/EventoRedHat/Evento-RedHat-Azure_05.jpeg
    alt: "Arquitectura de Ansible"
    title: "Arquitectura de Ansible"
  - url: /assets/images/EventoRedHat/Evento-RedHat-Azure_06.jpeg
    image_path: /assets/images/EventoRedHat/Evento-RedHat-Azure_06.jpeg
    alt: "La importancia de la automatización"
    title: "La importancia de la automatización"
  - url: /assets/images/EventoRedHat/Evento-RedHat-Azure_07.jpeg
    image_path: /assets/images/EventoRedHat/Evento-RedHat-Azure_07.jpeg
    alt: "DevOps en la práctica"
    title: "DevOps en la práctica"
  - url: /assets/images/EventoRedHat/Evento-RedHat-Azure_08.jpeg
    image_path: /assets/images/EventoRedHat/Evento-RedHat-Azure_08.jpeg
    alt: "La audiencia atenta"
    title: "La audiencia atenta"
  - url: /assets/images/EventoRedHat/Evento-RedHat-Azure_09.jpeg
    image_path: /assets/images/EventoRedHat/Evento-RedHat-Azure_09.jpeg
    alt: "El equipo de speakers"
    title: "El equipo de speakers"
---

El pasado Jueves 23/8 se realizó un evento de Red Hat, donde el objetivo del mismo fué hablar sobre DevOps, Automatización y PaaS organizado por [AT](http://www.at.uy/). Tuve la suerte de que me invitaran a mostrar en vivo el uso de Ansible y Azure; los módulos disponibles junto a la manera de trabajar y como poder utilizar Ansible con plataformas Windows por medio de WinRM.

Les comparto algunas fotos de lo que fué el evento:

{% include gallery caption="Fotos del **Evento de Red Hat**" %}

Y obviamente vamos a ver de que fueron las demos...

### Ansible, Azure y Linux

Obviamente cuando consideramos la opción de utilizar ansible, y particularmente con Azure, el primer ejemplo de Playbook muy probablemente sea el de crear una VM. O sea que ese sería nuestro *"Hello world"* en Ansible, así que decidimos ir por ese camino para comenzar la demo en el evento.

Si bien la mayoría de los ejemplos consideraba primero generar un **Resource Group** para luego crear la VM, se decidió también agregar la tarea de generar el grupo de recursos dentro del Playbook. Para ello es necesario definir el siguiente bloque:

{% highlight yaml%}
  ---
  - name: Create Azure Resource Group
    hosts: localhost
    connection: local
    vars:
      rgname: demoAnsibleRG

    tasks:
    - name: Create resource group
      azure_rm_resourcegroup:
        name: '{{ "{{ rgname " }}}}'
        location: eastus
{% endhighlight %}

El código anterior representa la primer tarea del Playbook que vamos a utilizar. Algo para resaltar es el uso de variables (para el ejemplo se usó **demoAnsibleRG**). Esta variable me permite controlar de forma global la información que proporciono al ejecutar el Playbook, tomando relevancia real al momento de contar con una definición compleja de tareas y recursos facilitando la administración.

Bien, de lo anterior tendríamos como resultado un Resource Group llamado *demoAnsibleRG* en la región *eastus*.

Una mecanismo que se encuentra disponible para poder manejar información, es la de imprimir un mensaje como salida de la ejecución del Playbook. Se puede observar el uso de esta funcionalidad al momento de generar y asignar una IP pública:

{% highlight yaml%}
  - name: Create public IP address
    azure_rm_publicipaddress:
      resource_group: '{{ "{{ rgname " }}}}'
      allocation_method: Static
      name: myPublicIP
    register: output_ip_address
  - name: Dump public IP for VM which will be created
    debug:
      msg: "The public IP is {{ "{{ output_ip_address.state.ip_address " }}}}."
{% endhighlight %}

Básicamente debemos definir una tarea e invocar **debug**, con el valor de **msg** que consideremos necesario y dentro del mensaje, llamar la variable de salida que nos interesa desplegar.

Y por último, antes de ver todo el Playbook en su totalidad, quisiera resaltar el siguiente bloque:

{% highlight yaml%}
  - name: Create Network Security Group that allows SSH
    azure_rm_securitygroup:
      resource_group: '{{ "{{ rgname " }}}}'
      name: myNetworkSecurityGroup
      rules:
        - name: SSH
          protocol: Tcp
          destination_port_range: 22
          access: Allow
          priority: 1001
          direction: Inbound
        - name: Web
          protocol: Tcp
          destination_port_range: 80
          access: Allow
          priority: 1002
          direction: Inbound
{% endhighlight %}

Simplemente revisando el nombre es suficiente para entender que estamos generando las reglas del firewall a la VM. Abrimos el puerto 22 para el servicio de SSH y el puerto 80 para un futuro web server.

De la forma anterior estamos dejando por defecto desde donde se accede (any). Para modificar esto, es necesario adicionar el parámetro **source_address_prefix** y definir el origen, por ejemplo una IP pública. Más información en el siguiente enlace: [azure_rm_securitygroup](https://docs.ansible.com/ansible/2.6/modules/azure_rm_securitygroup_module.html).

Ahora que se revisó lo más destacable del Playbook, el código completo para generar una VM, donde el SO es Linux (CentOS) en Azure es el siguiente:

{% highlight yaml%}
  ---
  - name: Create Azure VM
    hosts: localhost
    connection: local
    vars:
      vmname: demoAnsibleVM
      rgname: demoAnsibleRG

    tasks:
    - name: Create resource group
      azure_rm_resourcegroup:
        name: '{{ "{{ rgname " }}}}'
        location: eastus
    - name: Create virtual network
      azure_rm_virtualnetwork:
        resource_group: '{{ "{{ rgname " }}}}'
        name: myVnet
        address_prefixes: "10.0.0.0/16"
    - name: Add subnet
      azure_rm_subnet:
        resource_group: '{{ "{{ rgname " }}}}'
        name: mySubnet
        address_prefix: "10.0.1.0/24"
        virtual_network: myVnet
    - name: Create public IP address
      azure_rm_publicipaddress:
        resource_group: '{{ "{{ rgname " }}}}'
        allocation_method: Static
        name: myPublicIP
      register: output_ip_address
    - name: Dump public IP for VM which will be created
      debug:
        msg: "The public IP is {{ output_ip_address.state.ip_address }}."
    - name: Create Network Security Group that allows SSH
      azure_rm_securitygroup:
        resource_group: '{{ "{{ rgname " }}}}'
        name: myNetworkSecurityGroup
        rules:
          - name: SSH
            protocol: Tcp
            destination_port_range: 22
            access: Allow
            priority: 1001
            direction: Inbound
          - name: Web
            protocol: Tcp
            destination_port_range: 80
            access: Allow
            priority: 1002
            direction: Inbound
    - name: Create virtual network inteface card
      azure_rm_networkinterface:
        resource_group: '{{ "{{ rgname " }}}}'
        name: myNIC
        virtual_network: myVnet
        subnet: mySubnet
        public_ip_name: myPublicIP
        security_group: myNetworkSecurityGroup
    - name: Create VM
      azure_rm_virtualmachine:
        resource_group: '{{ "{{ rgname " }}}}'
        name: '{{ "{{ vmname " }}}}'
        vm_size: Standard_DS1_v2
        admin_username: azureuser
        ssh_password_enabled: false
        ssh_public_keys:
          - path: /home/azureuser/.ssh/authorized_keys
            key_data: 'ssh-rsa AAAAB3Nza{spin}q4711'
        network_interfaces: myNIC
        image:
          offer: CentOS
          publisher: OpenLogic
          sku: '7.5'
          version: latest
{% endhighlight %}

<div>
<b>Nota:</b>
En el parámetro <i>key_data</i> es necesario ingresar el valor completo de la clave pública.
</div>{: .notice}

### Instalar Nginx en Linux usando un inventario

Ahora que contamos con la base del servidor desplegado, podemos continuar con la siguiente etapa: convertir el servidor en un web server. Para ello es necesario instalar el rol correspondiente (nginx).

Antes de instalar el rol, vamos a generar una web custom, para ello creamos el siguiente archivo index.hml:

{% highlight html%}
  <html>
    <head>
      <title>Ansible DEMO</title>
    </head>
    <body bgcolor=white>
      <table border="0" cellpadding="10">
        <tr>
          <td>
            <img src="https://upload.wikimedia.org/wikipedia/commons/thumb/2/24/Ansible_logo.svg/2000px-Ansible_logo.svg.png" width="50px;">
          </td>
          <td>
            <h1>"Hello, Ansible ;)"</h1>
          </td>
        </tr>
      </table>
    </body>
  </html>
{% endhighlight %}

Ahora si el Playbook para instalar Nginx (llamado *deployNginx.yml*):

{% highlight yaml%}
  ---
  - name: Install Nginx
    hosts: demo_linux
    become: true
    tasks:
    - name: Add epel-release repo
      yum:
        name: epel-release
        state: present
    - name: Install nginx
      yum:
        name: nginx
        state: present
    - name: Insert Index Page
      template:
        src: index.html
        dest: /usr/share/nginx/html/index.html
    - name: Start NGiNX
      service:
        name: nginx
        state: started
{% endhighlight %}

Un detalle no menor es la siguiente línea:

{% highlight yaml%}
  hosts: demo_linux
{% endhighlight %}

No es más que la definición de un inventario. En resumidas cuentas, un inventario permite agrupar servidores en base a requerimientos, SO, rol, etc. Permitiendo aplicar ciertas tareas a diferentes servidores. Como el tema es bastante extenso, se desarrollará un post sobre este tema. Para esta ocasión se utilizó el siguiente inventario definido en un archivo llamado **hosts**:

{% highlight plaintext%}
  [demo_linux]
  <publicIpAddress>   ansible_user=azureuser
{% endhighlight %}

El valor de la IP pública deberíamos cambiarlo según la salida del primer Playbook.

Para ejecutar el Playbook con el inventario es necesario ejecutar la siguiente línea:

{% highlight bash%}
  ansible-playbook deployNginx.yml -i hosts
{% endhighlight %}

Y listo! se desplegará nuestro web server utilizando la web *index.html* escuchando por el *puerto 80* (previamente publicado desde Azure con el Network Security Group).

Happy scripting!