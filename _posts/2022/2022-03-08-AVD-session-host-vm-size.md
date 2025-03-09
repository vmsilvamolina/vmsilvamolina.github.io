---
title: 'Change Session Host VM size in Azure Virtual Desktop [English]'
author: Victor Silva
date: 2022-03-08T15:36:14+00:00
layout: post
permalink: /change-vm-size-avd/
excerpt: 'Azure Virtual Desktop is a cloud-based virtual desktop experience that allows you to connect to Azure Virtual Machines and virtualized applications. This desktops are organized in pools named Host Pools. Each pool has a set of virtual machines that serve as the desktops or sessions and wen you add a new VM, the default size is taken from the Host Pool info.
How about to change the default size of the VM? In this article, we will use the PowerShell power to change that.'
categories:
  - Azure
  - PowerShell
tags:
  - Azure Virtual Desktop
  - Azure
  - PowerShell
  - AVD
  - ARM
---
Azure Virtual Desktop is a cloud-based virtual desktop experience that allows you to connect to Azure Virtual Machines and virtualized applications. This desktops are organized in pools named Host Pools. Each pool has a set of virtual machines that serve as the desktops or sessions and wen you add a new VM, the default size is taken from the Host Pool info.
How about to change the default size of the VM? In this article, we will use the PowerShell power to change that.

First, install the Azure PowerShell module using the `Install-Module` command (the recommended option to install using the PowerShell 7.0 LTS version or higher):
  
{% highlight posh%}
Install-Module -Name Az
{% endhighlight %}

The next step is to connect to the Azure using the `Connect-AzAccount` command:
  
{% highlight posh%}
Connect-AzAccount
{% endhighlight %}

Before start to work with PowerShell, you need to select the Azure subscription you want to work with, using the `Select-AzSubscription` command:

{% highlight posh%}
Select-AzSubscription -SubscriptionName "<subscription name>"
{% endhighlight %}


And then, we can start to define a few variables to get the necessary information before change the host pool VM size. The first one is the host pool name and then, the resource group name, required to indentify the host pool. With those values we can use the `Get-AzWvdHostPool` to save the host pool object in a variable.
Using the `Get-AzWvdSessionHost` command, we can get the session host objects (the VMs) and choose one to find the info related to the image definition.

{% highlight posh%}
$hostpoolName = "General"
$resourceGroup = "AVD-RG"
$hostpool = Get-AzWvdHostPool | Where-Object { $_.Name -eq $hostpoolName }
$sessionHosts = Get-AzWvdSessionHost -ResourceGroupName $resourceGroup -HostPoolName $hostpool.name
$existingHostName = $sessionHosts[-1].Id.Split("/")[-1]
$adDomain = $sessionHosts[-1].Id.Split("/")[-1].split(".", 2)[1]
$currentVmInfo = Get-AzVM -Name $existingHostName.Split(".")[0]
{% endhighlight %}

With a one VM selected, we can access to the image reference id:

{% highlight posh%}
$imageReference = ($currentVmInfo.storageprofile.ImageReference).id
{% endhighlight %}

And save into a variable the VM prefix from a hostname:

{% highlight posh%}
$prefix = $existingHostName.Split("-")[0] + '-' + $existingHostName.Split("-")[1]
{% endhighlight %}

Now we can extract the template used to create the hosts in the host pool from:

{% highlight posh%}
ConvertFrom-Json (Get-AzWvdHostPool -HostPoolName $hostPoolName -ResourceGroupName $resourceGroup).vmtemplate
{% endhighlight %}

With all the info we can start to define the new VM template and after that, we can use the `Update-AzWvdHostPool` command to change the default VM size for the Session Hosts into the pool. We need to change the `vmSize` value to the new size we want:

{% highlight posh%}
$newtemplatesize = @{
    domain                = $adDomain
    imageType             = 'CustomImage'
    customImageId         = $imageReference
    namePrefix            = $prefix
    osDiskType            = 'StandardSSD_LRS'
    vmSize                = @{id='Standard_D4s_v3'; cores=4; ram=16}
}
Update-AzWvdHostPool -Name $hostPoolName `
  -VMTemplate $($newtemplatesize | ConvertTo-Json) `
  -ResourceGroupName $resourceGroup
{% endhighlight %}

The full script is here:

<script src="https://gist.github.com/vmsilvamolina/61c0d6ef0b1a7456568b085c79b1f43e.js"></script>

Happy scripting!