--- 
title: "Azure Functions with PowerShell: Swiss army knife for Ops [English]"
author: Victor Silva
date: 2020-09-06T007:45:00+00:00 
layout: single 
permalink: /functions-swiss-army-ops/
excerpt: "Nowadays, infrastructure tasks have reached a new level with the help of devs tools (like control version system) but, operations teams take all of the advantages of 'new world'? Serverless computing enables ways to build and create applications without concern about managing the infrastructure."
categories: 
  - Azure
  - PowerShell
tags: 
  - Azure Functions
  - PowerShell
  - Serverless
  - Azure
---

<div><b>Note:</b> 
This article is part of <a href="https://aka.ms/ServerlessSeptember2020">#ServerlessSeptember</a>. You'll find other helpful articles, detailed tutorials, and videos in this all-things-Serverless content collection. New articles from community members and cloud advocates are published every week from Monday to Thursday through September. 
 
Find out more about how Microsoft Azure enables your Serverless functions at <a href="https://docs.microsoft.com/azure/azure-functions/?WT.mc_id=servsept20-devto-cxaall">https://docs.microsoft.com/azure/azure-functions/</a>.</div>{: .notice--success}

Nowadays, infrastructure tasks have reached a new level with the help of devs tools (like control version system) but, operations teams take all of the advantages of 'new world'? Serverless computing enables ways to build and create applications without concern about managing the infrastructure.

With Azure Functions, you can write code with PowerShell, Python, C#, Java, and Javascript to publish these blocks of code as functions. Those functions are hosted in Azure in a container called a **Function App**. How does it work? Functions run when they are "triggered" and you'll see that in action in this post-guide. Though functions can run for a longer time under the premium and app service plans, the ultimate purpose of a function should be to do a particular task and do that task as efficiently as possible.

How Azure Functions will help with daily tasks or automate the "boring stuff"? In previous lines quote that two of the most popular scripting languages as is PowerShell and Python are available to use and... Did I mention that exists a free plan (with limitations obviously)? Functions created for default use the **Consumption plan** as a hosting plan when billing is based on the number of function executions, execution time, and memory used. In other words, you only pay for the time your functions are running.

## First step: Create a Function App

We can create an Azure Function App using the Azure Portal selecting PowerShell as the runtime. On the other hand, we can use PowerShell:

{% highlight posh%}
  #Connect to Azure
  Connect-AzAccount
  #Select the subscription
  Select-AzSubscription xxx

  #Define the function's parameters (using PowerShell splatting)
  $newFunctionAppParams = @{
    ResourceType      = 'Microsoft.Web/Sites'
    ResourceName      = 'FuntionApp-FTW'
    Kind              = 'functionapp'
    Location          = 'EastUS'
    ResourceGroupName = 'FunctionsDemo'
    Properties        = @{}
    Force             = $true
  }
  #Create the Azure resource
  $functionApp = New-AzResource @newFunctionAppParams
{% endhighlight %}

<img src="/assets/images/postsImages/PS_Functions_0.png" class="alignnone">

Azure Functions need a storage account to work correctly. Because storage accounts use a globally unique name, we'll take a section of a GUID and append it to the storage account name.

{% highlight posh%}
  #Variables
  $guidPart = (New-Guid).ToString().Split('-')[0]
  $storageAccountName = "functionapp$guidPart"
  $storageSku = 'Standard_LRS'
  #Parameters
  $newStorageParams = @{
    ResourceGroupName = 'FunctionsDemo'
    AccountName       = $storageAccountName
    Location          = 'EastUS'
    SkuName           = $storageSku
  }
  #Create storage account
  $storageAccount = New-AzStorageAccount @newStorageParams
{% endhighlight %}

Now, we take the connection string to finish the configuration:

{% highlight posh%}
  #Define variables
  $accountKey = Get-AzStorageAccountKey -ResourceGroupName 'FunctionsDemo' -AccountName $storageAccountName |
    Where-Object {$_.KeyName -eq 'Key1'} | Select-Object -ExpandProperty Value
  $storageConnectionString = "DefaultEndpointsProtocol=https;AccountName=$storageAccountName;AccountKey=$accountKey"
  # Set Function App settings
  $functionAppSettings = @{
    AzureWebJobDashboard                     = $storageConnectionString
    AzureWebJobsStorage                      = $storageConnectionString
    FUNCTIONS_EXTENSION_VERSION              = '~3'
    WEBSITE_CONTENTAZUREFILECONNECTIONSTRING = $storageConnectionString
    WEBSITE_CONTENTSHARE                     = $storageAccountName
  }
  $setWebAppParams = @{
    Name = 'FuntionApp-FTW'
    ResourceGroupName = 'FunctionsDemo'
    AppSettings = $functionAppSettings
  }
  $webApp = Set-AzWebApp @setWebAppParams
{% endhighlight %}

Perfect! In the Azure portal inside Function App now we see:

<img src="/assets/images/postsImages/PS_Functions_1.png" class="alignnone">


### Deploy the function

After the above steps, now we create a function: the Hello World function, why not?

In the Function App (FuntionApp-FTW), select **Functions**, and then select **+ Add**:

<img src="/assets/images/postsImages/PS_Functions_2.png" class="alignnone">

For this example, we use the **Timer trigger** template. Select that.


