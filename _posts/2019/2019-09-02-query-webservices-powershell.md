---
title: "Query Webservices with Powershell [English]"
author: Victor Silva
date: 2019-09-02T22:21:00+00:00
layout: post
permalink: /query-webservices-powershell/
excerpt: "This post will introduce you to webservices and how you can interact with them using PowerShell. But first: What is a web service? The term describes a standarized way of integrating Web-based applications using the open standards (XML, SOAP, WSDL and UDDI) over an Internet protocol network."
categories:
  - PowerShell
tags:
  - PowerShell
  - Webservices
---

This post will introduce you to webservices and how you can interact with them using PowerShell. But first: What is a web service? The term describes a standarized way of integrating Web-based applications using the open standards (XML, SOAP, WSDL and UDDI) over an Internet protocol network. 

## Hands on

First, we need a Webservice to start to illustrate how to work with PowerShell. We’ll use a simple calculator web services running on this website http://www.dneonline.com/calculator.asmx.

If you go to the above website you'll see a list of math operations available to use. As you can see bellow, there are 4 methods listed:

<img src="/assets/images/postsImages/PS_WS_01.png" alt="Webservice example" class="alignnone"/>

We'll start with the Add method, then open PowerShell and start typing the following:

{% highlight posh%}
  $URI = "http://www.dneonline.com/calculator.asmx"
{% endhighlight %}

Second, invoke the command `New-WebServiceProxy` 

{% highlight posh%}
  $proxy = New-WebServiceProxy -Uri $URI -Class calculator -Namespace webservice
{% endhighlight %}


Where we're going to name the class in a way that allows us to identify the webservice. For the example we simply use "namespace".

Then we can execute the following command to identify the available methods of the webservice:

{% highlight posh%}
  $proxy | gm
{% endhighlight %}

<img src="/assets/images/postsImages/WS_1.png>

In our case, we can take *Add*, where the output of the previous command indicates the following:

<img src="/assets/images/postsImages/WS_2.png>

That gives us a clue of how to consume it... To make a sum I invoke the `Add` method as follows:

{% highlight posh%}
  $proxy.Add(1,2)
{% endhighlight %}

Obtaining the result of the operation:

<img src="/assets/images/postsImages/WS_3.png>

This is an easy way to consume a webservice using PowerShell.

Happy scripting!
