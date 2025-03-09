--- 
title: "How to install Azure VM agent on Linux [English]"
author: Victor Silva
date: 2021-01-15T15:34:00+00:00 
layout: post 
permalink: /install-azure-vm-linux-agent/
excerpt: 'Azure Virtual Machines use a lightweight process that manages the interaction with the Azure Fabric Controller, has a fundamental role in enabling and executing virtual machine extensions. This extension also enables administrative features such as resetting a password of a VM user. Another key point is to work with post-deployment configurations like software installation and configuration or enable backup.'
categories: 
  - Azure
tags: 
  - Bash
  - Azure
  - Azure Virtual Machines
  - WALinuxAgent
---

Azure Virtual Machines use a lightweight process that manages the interaction with the Azure Fabric Controller, has a fundamental role in enabling and executing virtual machine extensions. This extension also enables administrative features such as resetting a password of a VM user. Another key point is to work with post-deployment configurations like software installation and configuration or enable backup.

This agent, written in Python, supports a wide variety of common Linux distributable operative systems like Ubuntu, CentOS, Fedora, Red Hat, and more. If I need to make a recommendation, I would recommend never removing this from your Azure VM (Linux VM in this case), because actions or tasks could start to generate errors.

### Requisites

The first thing that you need to check the internet connection from the Azure VM. You can run a ping or curl to validate the navigation. 

The Microsoft Azure Linux Agent depends on some system packages to function:

* Python 2.6+
* OpenSSL 1.0+
* OpenSSH 5.3+
* Filesystem utilities: sfdisk, fdisk, mkfs, parted
* Password tools: chpasswd, sudo
* Text processing tools: sed, grep
* Network tools: ip-route

Being an administrative task, since it is required to modify components and add new ones to the system, it is necessary to have root privileges to the system.

### Installation

To get the package to install, exist a GitHub repository where the agent was packed and published. The repository URL is [https://github.com/Azure/WALinuxAgent/releases/latest](https://github.com/Azure/WALinuxAgent/releases/latest). You need to go to the Releases section and find the list of the version published (the last version figuring at the top). Now, we are ready to choose the file to download. Exist two options to use: one with the `zip` extension and the other with `tar.gz` extension. 

> We will select the zip file for this explanation.

Linux had the command `wget` used to download files from the internet in moments like this. It supports downloading multiple files, downloading in the background, resuming downloads, limiting the bandwidth used for downloads, and more. The syntax is pretty easy, you need only to write wget following the URL and press enter to start to download the agent files.


Copy the URL from the Source code.zip file and use it:

{% highlight posh%}
wget https://github.com/Azure/WALinuxAgent/archive/refs/tags/v2.2.53.zip
{% endhighlight %}


Paying attention to the previous command: the URL changed to adding the **/releases/latest** because it referred to the release section commented before and selecting the latest version of the agent.

Next, we need to unzip the file downloaded. How? Easy, running the command:

{% highlight posh%}
unzip v2.2.53.zip
{% endhighlight %}


Where are the people that say work with Linux is difficult? XD

Continuing with our steps to install the agent let's move to the folder previously created after unzipping the file running the super-powerful cd and perform the installation:

{% highlight posh%}
cd WALinuxAgent-2.53
sudo python setup.py install
{% endhighlight %}

Perfect! If you are reading this, your goal task is done and I have an action to check that:

{% highlight posh%}
systemctl status waagent
{% endhighlight %}

Before going to the Azure portal to assume that the agent is reporting correctly, I recommend restarting the agent using another option of systemctl:

{% highlight posh%}
sudo systemctl restart waagent
{% endhighlight %}

At this point, you already have your Azure VM with the agent installed and working properly. 

Happy scripting!