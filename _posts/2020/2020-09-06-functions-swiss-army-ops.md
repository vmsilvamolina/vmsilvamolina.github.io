--- 
title: "Azure Functions with PowerShell: Swiss army knife for Ops [English]"
author: Victor Silva
date: 2020-09-06T07:45:00+00:00 
layout: post 
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

<div>
<b>Note:</b> 
This article is part of <a href="https://aka.ms/ServerlessSeptember2020">#ServerlessSeptember</a>. You'll find other helpful articles, detailed tutorials, and videos in this all-things-Serverless content collection. New articles from community members and cloud advocates are published every week from Monday to Thursday through September. 
 
Find out more about how Microsoft Azure enables your Serverless functions at <a href="https://docs.microsoft.com/azure/azure-functions/?WT.mc_id=servsept20-devto-cxaall">https://docs.microsoft.com/azure/azure-functions/</a>.
</div>{: .notice}

Nowadays, infrastructure tasks have reached a new level with the help of devs tools (like control version system) but, operations teams take all of the advantages of 'new world'? Serverless computing enables ways to build and create applications without concern about managing the infrastructure.

With Azure Functions, you can write code with PowerShell, Python, C#, Java, and Javascript to publish these blocks of code as functions. Those functions are hosted in Azure in a container called a **Function App**. How does it work? Functions run when they are "triggered" and you'll see that in action in this post-guide. Though functions can run for a longer time under the premium and app service plans, the ultimate purpose of a function should be to do a particular task and do that task as efficiently as possible.

How will Azure Functions help with daily tasks or automate the "boring stuff"? In previous lines I quoted that two of the most popular scripting languages such as PowerShell and Python are available to use and... Did I mention that there is a free plan (with limitations obviously)? Functions created for default use the **Consumption plan** as a hosting plan when billing is based on the number of function executions, execution time, and memory used. In other words, you only pay for the time your functions are running.

## First step: Create a Function App

We can create an Azure Function App using the Azure Portal selecting PowerShell as the runtime. On the other hand, we can use PowerShell.

`Az.Functions` is the module relased at the [PowerShell Gallery](https://www.powershellgallery.com/packages/Az.Functions/1.0.1) for Microsoft to provide cmdlets to manage Azure Functions.

As I explained here, to install the module you need to run:

{% highlight posh%}
Install-Module Az.Functions
{% endhighlight %}

The following is connect to Azure:

{% highlight posh%}
#Connect to Azure
Connect-AzAccount
#Select the subscription
Select-AzSubscription xxx
{% endhighlight %}

I'll use an existing Resource Group but I need to create the Storage Account running the following:

{% highlight posh%}
#Variables
$ResourceGroupName = "FunctionsDemo"
$FunctionAppName = "FuntionApp-FTW"
$Location = "EastUS"
$guidPart = (New-Guid).ToString().Split('-')[0]
$storageAccountName = "functionapp$guidPart"
$storageSku = "Standard_LRS"
{% endhighlight %}

Azure Functions need a storage account to work correctly. Because storage accounts use a globally unique name, we'll take a section of a GUID and append it to the storage account name.

{% highlight posh%}
#Parameters
$newStorageParams = @{
  ResourceGroupName = $ResourceGroupName
  AccountName       = $storageAccountName
  Location          = $Location
  SkuName           = $storageSku
}
#Create storage account
New-AzStorageAccount @newStorageParams
{% endhighlight %}

Lastly, we can use the `New-AzFunctionApp` to deploy the function app:

{% highlight posh%}
#Parameters
$newFunctionParams = @{
  Name              = $FunctionAppName
  ResourceGroupName = $ResourceGroupName
  StorageAccount    = $storageAccountName
  Location          = $Location
  Runtime           = "PowerShell"
  RuntimeVersion    = "7.0"
}
#Create Function App
New-AzFunctionApp @newFunctionParams
{% endhighlight %}

<img src="/assets/images/postsImages/PS_Functions_0.png" class="alignnone">

Perfect! In the Azure portal inside Function App now we see:

<img src="/assets/images/postsImages/PS_Functions_1.png" class="alignnone">


### Deploy the function

After the above steps, now we create a function: the Hello World function, why not?

In the Function App (FuntionApp-FTW), select **Functions**, and then select **+ Add**:

<img src="/assets/images/postsImages/PS_Functions_2.png" class="alignnone">

For this example, we use the **HTTP trigger** template. Select that and **Create Function**.

<img src="/assets/images/postsImages/PS_Functions_3.png" class="alignnone">

Inside the function, selecting the **Code + Test** option, we can access to the code and tools for troubleshoot and test the function.

## What kind of problems can it solve?

At this moment, we start to solve some challenges/problems associated with commom requirements or daily tasks, like scheduled actions, with Azure Functions and Azure Services.

### Scenario 1 - Read web content for updates

Suppose that I have to check the Azure Stack Hub release notes for new updates. The site is: [https://docs.microsoft.com/en-us/azure-stack/operator/release-notes](https://docs.microsoft.com/en-us/azure-stack/operator/release-notes) and we need to pay attention to the **build reference** and **build type**, because if we had a new version we should receive a mail with the number and the type (full or express):

<img src="/assets/images/postsImages/PS_Functions_4.png" class="alignnone">

This function must be executed periodically since it is necessary to check for new updates of the site regularly. Therefore, the function has to **Timer trigger** (another type of function that runs periodically).

When we create a Timer trigger function, we need to define a schedule, like a cron expression:

>0 0 13 * * *

What does it mean: Run every day at 13:00hs UTC.

How do we obtain the information indicated on the image before? With PowerShell and the following code:

{% highlight posh%}
  $web = Invoke-WebRequest -Uri https://docs.microsoft.com/en-us/azure-stack/operator/release-notes -UseBasicParsing
  $buildReferenceRaw = ($web.Content `
    | Select-String -AllMatches -Pattern '(\<h2.*\>)(.*)( build.*\<\/h2\>)' `
    | Select-Object -ExpandProperty Matches)
  $buildReference = $buildReferenceRaw[0].Groups[2].Value
  $updateTypeRaw = ($web.Content `
    | Select-String -AllMatches -Pattern '(The Azure Stack Hub .* update build type is <strong>)(.*)<\/strong>.' `
    | Select-Object -ExpandProperty Matches)
  $updateType = $updateTypeRaw[0].Groups[2].Value
{% endhighlight %}

Now we need to paste this code into the function, using the code editor embedded.

Ok, now we have the values and it's time to create a message to join the info. We'll test the function using the 

{% highlight posh%}
  Write-Host "New update! The last update is ${$updateNumber} and the build type is ${$updateType}."
{% endhighlight %}

<img src="/assets/images/postsImages/PS_Functions_5.png" class="alignnone">

Perfect! An improving for that is read the previous value from a 

Awesome! The next step is to send an email with that info using for example `SendGrid` (an SMTP solution offered in the Azure marketplace, with a free tier), but that will part of a new post ;)


Happy scripting!