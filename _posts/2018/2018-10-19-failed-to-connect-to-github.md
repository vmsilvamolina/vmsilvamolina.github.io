---
title: "Failed to connect to github.com port 443: Timed out [English]"
author: Victor Silva
date: 2018-10-19T20:04:00+00:00
layout: post
permalink: /failed-to-connect-to-github/
excerpt: "Last week I worked behind a corporate proxy. This really was a headache because everyone knows that you have an implicit restriction when you try to surf the web. But ... I didn´t know the problems I could have with GitHub, trying to sync my repos."
categories:
  - PowerShell
  - DevOps
tags:
  - PowerShell
  - Git
  - GitHub
  - Proxy
  - git config
  - DevOps
  - Automatización
  - posh-git
  - English
---

Last week I worked behind a corporate proxy. This really was a headache because everyone knows that you have an implicit restriction when you try to surf the web. But ... I didn´t know the problems I could have with GitHub, trying to sync my repos.

On my everyday tasks I use a lot PowerShell. When I need to acomplish a task, first I try to solve with the command line (if it´s possible, obviously).  

So then, when I tried to clone locally a repo, using the `git clone` command:

{% highlight bash%}
  git clone https://github.com/vmsilvamolina/vmsilvamolina.github.io.git
{% endhighlight %}

After the execution (I had to wait a few minutes), I got the following error:

> Filed to connecto to github.com port 443: Time out

<img src="https://v5xycw.ch.files.1drv.com/y4mrtQAQcEaHoY96kKJ8lx4VVV2246qethFvhz5g-NJUAUZ0cV39bk5BB9gCHqZqlFnME64tK1ZIjDDu4OKYqP3w1kRfUpL6GoKgUx-tABjimhU0ycETo8Vfs1NQgZ3TMYQ09GuIMc2v3wi9RqiMsQo6riJRJRfAYj5kcGG7YSXFDprFavHPThvaKyrD-qE0JnwmbXrki0DcOr5rmpny5-t5A?width=1129&height=73&cropmode=none" alt="Failed to connect to github.com port 443: Timed out" class="alignnone" />

## Solution

If you ever used Git in your life, you know there is a local configuration for parametrize the user experience. Git provides a tool called **git config** that lets you get and set configuration variables that control all aspects of how Git looks and operates. Among all the values, you can config the username, password, text editor and more.

For list your configuration settings, you can use the `git config --list` command.

If you check the result of that, you cand find the next setting:

> http.proxy

That's my boy! ;)

Well, we'll find how we can set the values to intent to use the proxy reading the help file. How we can access it? Executing the following:

{% highlight bash%}
  git config --list
{% endhighlight %}


> **http.proxy** 
> 
> Override the HTTP proxy, normally configured using the *http_proxy*, *https_proxy*, and *all_proxy* environment variables (see curl(1)). In addition to the syntax understood by curl, it is possible to specify a proxy string with a user name but no password, in which case git will attempt to acquire one in the same way it does for other credentials. See gitcredentials(7) for more information. The syntax thus is *[protocol://][user[:password]@]proxyhost[:port]*. This can be overridden on a per-remote basis; see remote.\<name\>.proxy

Perfect!

For solve the "*Failed to connect to github.com port 443: Timed out*" message we need to run:

{% highlight bash%}
  git config --global http.proxy http://domain.local\vsilva:Passw0rd@proxyServer:8080
{% endhighlight %}

Done! You can check if the setting was applied running `git config --global http.proxy`


Additional info:
* [git config](https://git-scm.com/docs/git-config)

Happy scripting!