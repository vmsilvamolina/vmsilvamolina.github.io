--- 
title: "Using a Lambda Function to send automated blog post on Twitter [English]" 
author: Victor Silva
date: 2019-01-01T19:57:00+00:00 
layout: single 
permalink: /aws-lambda-powershell-twitter/ 
excerpt: "" 
categories: 
  - PowerShell 
  - AWS 
  - DevOps 
tags: 
  - PowerShell 
  - AWS 
  - Serverless 
  - Lambda 
  - Scripting
  - Automation 
  - English
--- 

A few months ago, I started to learn about Amazon Web Services (AWS) because I had the necessity to expand my knowledge of cloud services offers. Additional to this, I follow the technical blog from Amazon and I read about the support for PowerShell Core 6 and I worked a lot with serverless (using Azure Functions) so that, serverless have a place in my heart nowadays. Well, with the above, I´ll share who to work with Amazon, in particular with the serverless solution called Lambda with PowerShell Core.

How will I explain that? Sharing with you a way to send automated blog post on Twitter without "human" interaction.

## Setting up a development environment

Before we get started developing PowerShell Core based Lambda functions, let’s set up our dev environment.

First, I recommend you to use Visual Studio Code, because the ISE (Intergated Scripting Environment) is not supported with PowerShell Core. But, you need to configure a little things before...

### Installing PowerShell Extension

Launch the Visual Studio Code app by typing code in your PowerShell session and pressing Ctrl+P to launch Quick Open. In Quick Open, type `ext install powershell` and hit *Enter*. The Extensions view opens on the Side Bar, select the PowerShell extension from Microsoft. So then, click the Install button on the PowerShell, after the install, you´ll see the Install button to Reload. Click that.

After Visual Studio Code has reload, you are ready for editing PowerShell files :)



https://docs.aws.amazon.com/lambda/latest/dg/powershell-programming-model.htm