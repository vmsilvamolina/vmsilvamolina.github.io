---
title: Marvel from PowerShell [English]
date: 2018-02-14T22:30:46
author: Victor Silva
layout: single
permalink: /marvel-from-powershell/
categories:
  - PowerShell
  - APIs
tags:
  - PowerShell
  - API
  - Marvel
  - Marvel Comics
---

<p>This is my first post in English :)</p>{: .notice--success}

After watched the last movie of Marvel, Black Panther, I was starting search about the world of comics and wrote a small PowerShell module to interact with the [Marvel Comics REST API](https://developer.marvel.com/).

{% include video id="xjDjIWPwcPU" provider="youtube" %}

Marvel had publish a REST API which allows you gather data regarding the entire Marvel Comics Universe and create amazing websites and apps with that free data. For example, you can access to the characters info, comics, comics stories and much more. And you might be wondering what does this have to do with PowerShell?  Well, I love read and search about everything. I knew I had to find a way to add this into the console. So, I created a module to access to all the information from PowerShell console. 😎

### Install the module
The module can be installed from the PowerShell Gallery using the following complex command:

{% highlight posh %}
Install-Module -Name PSMarvel
{% endhighlight %}


## How to work?

There are a couple of things you will need to setup before you can use the module:

First, setup a Marvel API key (create an account). [Link]()https://developer.marvel.com/account. After complete the registration process you'll have this data:

<img src="https://b6amog.ch.files.1drv.com/y4mqq_JCyRKwrKAjg_5t1P79Q6z3WGUSffQYh3CcboOQjVbMnF59dEvWcKWMuJg8RDTkYqT2veKM24JkdnJa3USU08qeZOjdp0nh-XnfWN4583Q5G90KTs1xIYh3DsDMULtCCPDljO5k_XZdGo4w1FH0nXgULXv_w_JH1I2xKjPx8nMV3ZN3GCheItBA6lExLOq61BwL0Ov_xWCboj2Ntz3uA?width=780&height=480&cropmode=none" alt="API keys" class="alignnone size-full">

With the keys, you can start to consume the API using the cmdlet [Invoke-RestMethod](). I wrote the following function to start accessing information:

{% highlight posh %}
#API Keys and TS
$MarvelPublic = "baXXXXXXXXXXXXXXXXXXXXXXXX38"
$MarvelPrivate = "62fXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX41"
$MarvelTS = New-TimeSpan -End (Get-Date -Year 2018 -Month 1 -Day 1)

#Form the hash as Marvel requires 
$ToHash = $MarvelTS.ToString() + $MarvelPrivate.ToString() + $MarvelPublic.ToString()
$StringBuilder = New-Object System.Text.StringBuilder 
[System.Security.Cryptography.HashAlgorithm]::Create("MD5").ComputeHash([System.Text.Encoding]::UTF8.GetBytes($ToHash)) | % {
    [Void]$StringBuilder.Append($_.ToString("x2")) 
}
$MD5 = $StringBuilder.ToString()
{% endhighlight %}

How to search any character? We'll use the parameter **nameStartsWith** with the URL and the apikey like this:

{% highlight posh %}
#Call the API gateway
$StartWith = "Spider"
$Url = "https://gateway.marvel.com:443/v1/public/characters?nameStartsWith=$StartWith&apikey=$MarvelPublic&hash=$MD5&ts=$MarvelTS"
{% endhighlight %}

And manipulate the data:

{% highlight posh %}
$Results = Invoke-WebRequest $Url
$Content = $results.Content
$Output = ConvertFrom-Json $Content
#Display only the name list
$Output.data.results.name
{% endhighlight %}

The result:

<img src="https://dkahog.ch.files.1drv.com/y4m_lXkn_v8kMkL3LU1ax8ndP_dG8YHjkyeSJ50A7hjwMrAYstgE1yb29eO56nREqH9bPrGa4QLUFvG-hPWFMJwCgk6CFDyziqL-gmo_fsKOnBPFuXnppWDQHne3sCq8SKDFNJ3IXg6EyDNP5d-a-Y3BH6lF6Vrgstabvnepw3p4C4kT9h1e1UWXvVJGCZ0bS5FUdfS3zJgDEh92FgJx05ktg?width=460&height=318&cropmode=none" alt="Display only the name list" class="alignnone size-full">

## What contain the module?

The module has the following commands:

{% highlight posh %}
Get-Command -Module PSMarvel
{% endhighlight %}

<!-- <imagen con los comandos> -->


## Contributing
The module is available on github, feel free to contribute via issues or pull requests.

Hope you enjoyed this module and article! 💪

<p><b>Disclaimer:</b> Data provided by <a href="http://marvel.com">Marvel</a>. © 2018 MARVEL </p>{: .notice--info}