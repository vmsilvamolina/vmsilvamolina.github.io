---
title: Integración de Ansible y Azure (parte 2)
date: 2018-06-01T18:57:00+00:00
author: Victor Silva
layout: post
permalink: /integracion-ansible-azure-2/
excerpt: "En la entrega anterior se prepararon las credenciales que vamos a utilizar al momento de generar nuestros playbooks en Ansible. Como se comentó anteriormente Ansible, siendo un lenguaje declarativo, permite trabajar de tal manera que simplifica las tareas de administración de la infraestructura sumado a la flexibilidad generada a la hora de implementar soluciones, y sin tener que implementar agentes para tal fin."
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
<li>Integración de Ansible y Azure - Hello world!</li>
<li><a href="https://blog.victorsilva.com.uy/integracion-ansible-azure-3/">Integración de Ansible y Azure - Desplegar una VM</a></li>
</div>{: .notice}

En la entrega anterior se prepararon las credenciales que vamos a utilizar al momento de generar nuestros playbooks en Ansible. Como se comentó anteriormente Ansible, siendo un lenguaje declarativo, permite trabajar de tal manera que simplifica las tareas de administración de la infraestructura sumado a la flexibilidad generada a la hora de implementar soluciones, y sin tener que implementar agentes para tal fin. Estas tareas se agrupan en playbooks y, para no aburrir con el teórico, vamos a comenzar a definir un playbook y ver la estructura que presentan.

## Anatomía de un playbook

{% highlight plaintext %}
  ---
  - hosts: webservers
    vars:
      http_port: 80
      max_clients: 200
    remote_user: root
    tasks:
    - name: ensure apache is at the latest version
      yum:
        name: httpd
        state: latest
    - name: write the apache config file
      template:
        src: /srv/httpd.j2
        dest: /etc/httpd.conf
      notify:
      - restart apache
    - name: ensure apache is running (and enable it at boot)
      service:
        name: httpd
        state: started
        enabled: yes
    handlers:
      - name: restart apache
        service:
          name: httpd
          state: restarted
{% endhighlight %}

El bloque de código anterior es un playbook, y como tal, se pueden observar agrupaciones que permiten descifrar sin mayor esfuerzo ciertas tareas, variables, etc. Vamos a realizar comentarios sobre cada una de ellas:

### hosts

Dentro de la sección hosts vamos a poder definir el host o el grupo de host donde se ejecutarán las tareas. Este valor es obligatorio.

### vars

Son variables definidas para determinar la configuración de los recursos a implementar por medio de las tareas.

### tasks

Lista de acciones a ejecutar, en donde se pueden invocar módulos externos y usar las variables definidas anteriormente (en caso que se hayan definido).

### handlers

Los handlers son nuestra forma de llamar a una tarea después de que se completa otra tarea previamente.

Continuará...

Happy scripting!