--- 
title: "Using a Lambda Function to automate blog post on Twitter (part 1) [English]" 
author: Victor Silva
date: 2019-01-01T19:57:00+00:00 
layout: single 
permalink: /aws-lambda-powershell-twitter/ 
excerpt: "A few months ago, I started to learn about Amazon Web Services (AWS) because I had the necessity to expand my knowledge of cloud services offers. Additional to this, I follow the technical blog from Amazon and I read about the support for PowerShell Core 6 and I worked a lot with serverless (using Azure Functions) so that, serverless have a place in my heart nowadays" 
categories: 
  - PowerShell 
  - AWS 
  - DevOps 
tags: 
  - PowerShell
  - PowerShell Core 
  - AWS 
  - Serverless 
  - Lambda 
  - Scripting
  - Automation 
  - English
--- 

<div>
<p>This post is part of a series of related posts:</p>
<li>Lambda Function to automate blog post on Twitter - Setting up a development environment</li>
<li>Lambda Function to automate blog post on Twitter - Configuring source files and AWS storage</li>
<li>Lambda Function to automate blog post on Twitter - Creating the schedule</li>
</div>{: .notice--success}

A few months ago, I started to learn about Amazon Web Services (AWS) because I had the necessity to expand my knowledge of cloud services offers. Additional to this, I follow the technical blog from Amazon and I read about the support for PowerShell Core 6 (I worked a lot with serverless, using Azure Functions) so that, serverless have a place in my heart nowadays. Well, with the above, I´ll share how to work with AWS, in particular with the serverless solution called Lambda with PowerShell Core.

How will I explain that? Sharing with you an excellent example: A way to send automated blog post on Twitter without "human" interaction.

## Setting up a development environment

Before we get started developing PowerShell Core based Lambda functions, let’s set up our dev environment.

First, I recommend you to use [Visual Studio Code](https://code.visualstudio.com/download), because the *ISE* (Integrated Scripting Environment) is not supported with PowerShell Core. But, you need to configure a little things before start coding...

### Installing PowerShell Extension

Launch the Visual Studio Code app by typing `code` in your PowerShell session and pressing Ctrl+P to launch *Quick Open*. In Quick Open, type `ext install powershell` and hit *Enter*. The Extensions view opens on the Side Bar, select the PowerShell extension from Microsoft. So then, click the Install button on the PowerShell, after the install, you´ll see the Install button to Reload. Click that.

After Visual Studio Code has reload, you are ready for editing PowerShell files :)

### Using PowerShell Core version

Because the objective is to use PowerShell Core, we need to add a new variable to your profile settings file.

Open VSCode and click en File, after that click on Preferences and the last step is to select Settings.

Find in the right corner up, a button with two curly brackets ({ and }). Two editor panes appear. In the right-most  pane (user settings), insert the setting bellow:

{% highlight posh%}
  "powershell.powerShellExePath": "c:/Program Files/PowerShell/6/pwsh.exe"
{% endhighlight %}

The number **6** represents the version of PowerShell (core).
Save the settings file and restart VSCode.

### Install the .NET Core SDK

Next, we need to install the .NET Core 2.2 SDK, because the Lambda support for PowerShell uses the same .NET Core. The .NET Core SDK is used by PowerShell publishing cmdlets for Lambda to create the Lambda deployment package.

You can find the .NET Core 2.2 SDK [here](https://www.microsoft.com/net/download).

### Install the PowerShell module AWSLambdaPSCore

The last component we need for the development environment is the AWSLambdaPSCore module, that you can install from the PowerShell Gallery directly, using the following command:

{% highlight posh%}
  Install-Module AWSLambdaPSCore -Scope CurrentUser
{% endhighlight %}

Additionally, we need to install the **AWSPowerShell.NetCore** module, for work with other AWS Services.

{% highlight posh%}
  Install-Module AWSPowerShell.NetCore
{% endhighlight %}

Well, After all changes we'll continue on the next post, configuing the files on the blog and the AWS S3 service for storage the records (published posts).

Happy scripting!