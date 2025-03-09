---
title: "Ejecutar scripts de PowerShell desde Ansible"
author: Victor Silva
date: 2018-12-16T23:43:01+00:00
layout: post
permalink: /powershell-desde-ansible/
excerpt: "Hace un tiempo escribí sobre Ansible y la integración, o los mecanismos disponibles, que tenemos con Azure, haciendo foco en el uso de la Azure Cloud Shell. Pero ¿que métodos tenemos a disposición si queremos utilizar PowerShell dentro de un Playbook de Ansible?"
categories:
  - PowerShell
  - DevOps
tags:
  - PowerShell
  - Ansible
  - Scripting
  - IaC
---

Hace un tiempo escribí sobre Ansible y la integración, o los mecanismos disponibles, que tenemos con Azure, haciendo foco en el uso de la Azure Cloud Shell. Pero ¿que métodos tenemos a disposición si queremos utilizar PowerShell dentro de un Playbook de Ansible?

Ansible ofrece una serie de módulos para poder interactuar con los servidores Windows:

* **win_command:** Permite ejecutar comandos incluyendo scripts de PowerShell, por medio de la invocación del ejecutable.
* **win_shell:** Es la segunda opción y la menos recomendada, ya que el entorno del usuario tiene incidencia.

Un ejemplo de uso de *win_command* sería lo siguiente:

{% highlight yaml%}
  - name: Ejecutar un script
    win_command: powershell.exe -ExecutionPolicy ByPass -File C:/temp/powershellScript.ps1
{% endhighlight %}

Donde directamente invocamos un script para ejecutar remotamente.

Obviamente esto trae asociado que anteriormente se debió copiar el archivo al destino. Ansible tiene el módulo *win_copy* para tal fin. Su uso, sería de la siguiente manera:

{% highlight yaml%}
  - win_copy:
     src: /root/ansibleFiles/powershellScript.ps1
     dest: 'C:\temp\'
     remote_src: no
{% endhighlight %}

Del otro lado tenemos el módulo win_shell, donde podríamos definir un ejemplo de uso: Comprobar si existe una carpeta y en caso que exista, generar un archivo. La situación anterior podríamos resolverla de la siguiente manera:

{% highlight yaml%}
  - name: Comprobar una carpeta y crear un archivo
    win_shell: |
      $value = Test-Path -Path C:\windows\temp
      if ($value) {
          New-Item C:\windows\temp\test.txt -ItemType File
      }
{% endhighlight %}

Más información:
[https://docs.ansible.com/ansible/latest/plugins/shell/powershell.html](https://docs.ansible.com/ansible/latest/plugins/shell/powershell.html)

Happy scripting!
