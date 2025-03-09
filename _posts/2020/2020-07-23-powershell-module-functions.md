--- 
title: "PowerShell module for Azure Functions [English]"
author: Victor Silva
date: 2020-07-23T21:25:00+00:00 
layout: post 
permalink: /powershell-module-functions/
excerpt: "I'll take a look at some of the cmdlets that are included in this initial release of the new Azure Functions module for PowerShell. The detailed tasks on this post using the module include: deploy a new function app, modify some of the settings using the Update cmdlets, and then clean-up-the-house by deleting the resources at the end."
categories: 
  - Azure
  - PowerShell
tags: 
  - Azure Functions
  - PowerShell
  - Module
  - Gallery
---

I'll take a look at some of the cmdlets that are included in this initial release of the new Azure Functions module for PowerShell. The detailed tasks on this post using the module include: deploy a new function app, modify some of the settings using the Update cmdlets, and then clean-up-the-house by deleting the resources at the end.

Microsoft recently released on the PowerShell Gallery a module named `Az.Functions`, offering cmdlets to manage the Azure Functions service. According to the [PowerShell Gallery](https://www.powershellgallery.com/packages/Az.Functions/1.0.0), version 1.0.0 was released on the 19th of May (the last version is 1.0.1, released on the 23rd of June).

**Az.Functions** is now included as part of the `Az` module, wich provide a lot lot of additional modules like `Az.Account`, `Az.Storage`, `Az.Compute`, and more. So if you install the entire Az module, you’ll automatically receive Az.Functions by default.

## Installing and analyzing Az.Functions

As introduced at the beginning, the module is now published in the PowerShell Gallery, so installation is a simple as starting a new PowerShell session and running one cmdlet, depending on what is required.

If you just want only the **Az.Functions** module, run the following cmdlet:

{% highlight posh%}
  Install-Module -Name Az.Functions
{% endhighlight %}

<div><b>Note:</b> The previous command will also pull down Az.Accounts, because is needed to work correctly.</div>{: .notice--success}

On the other hand, if you prefer to get all the Azure modules is required run:

{% highlight posh%}
Install-Module -Name Az
{% endhighlight %}

Easy right? Now we let's take a look at the cmdlets that are part of this module, so will execute:

{% highlight posh%}
Get-Command -Module Az.Functions
{% endhighlight %}

Perfect! There are a lot of commands to work with Azure Functions from the comfort of the command line...

## Deploy a new function app

Before we start creating a new function app, we must specify one of the supported locations based on the type of the function app. For example, if we like to create a Function App in a Consumption plan, we need to run the following command:

{% highlight posh%}
Get-AzFunctionAppAvailableLocation -PlanType Consumption -OSType Windows
{% endhighlight %}

After choosing the location, we'll create the required Azure resources for publish my function:

{% highlight posh%}
#Variables
$ResourceGroupName = "FunctionAppPOSH"
$FunctionAppName = "FunctionApp-POSH"
$Location = "EastUS"
$guidPart = (New-Guid).ToString().Split('-')[0]
$StorageAccountName = "functionapp$guidPart"
$StorageSku = "Standard_LRS"
#Creación de recursos
New-AzResourceGroup -Name $ResourceGroupName -Location $Location
New-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -SkuName Standard_LRS -Location $Location
New-AzFunctionApp -Name $FunctionAppName -ResourceGroupName $ResourceGroupName -StorageAccount $StorageAccountName -Location $Location -Runtime "PowerShell" -RuntimeVersion "7.0"
{% endhighlight %}

If the commands finish correctly, we received a confirmation on the console about the resource created.

## Get functions and settings

We can use the `Get-AzFunctionApp` function to check existent functions, filtering for subscriptions, resource group or names like this:

{% highlight posh%}
Get-AzFunctionApp -ResourceGroupName $ResourceGroupName
{% endhighlight %}

<img src="/assets/images/postsImages/PS_FunctionModule_0.png" class="alignnone">

With the function app identified, we can manage settings or add news:

{% highlight posh%}
Update-AzFunctionAppSetting -Name $FunctionAppName -ResourceGroupName $ResourceGroupName -AppSetting @{"Test" = "SuperValue"}
{% endhighlight %}

And get the value to use in future commands:

{% highlight posh%}
Get-AzFunctionAppSetting -Name $FunctionAppName -ResourceGroupName $ResourceGroupName
{% endhighlight %}

How about if I need to select only the previous setting created, named "Test"?:

{% highlight posh%}
(Get-AzFunctionAppSetting -Name $FunctionAppName -ResourceGroupName $ResourceGroupName)["Test"]
{% endhighlight %}

An alternative to achieve that:

{% highlight posh%}
(Get-AzFunctionAppSetting -Name $FunctionAppName -ResourceGroupName $ResourceGroupName).get_Item("Test")
{% endhighlight %}

<img src="/assets/images/postsImages/PS_FunctionModule_1.png" class="alignnone">

Wait... what is the method **get_Item()**? It's a "hidden" method on hash tables.

Happy scripting!