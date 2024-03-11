---
title: ''
author: Victor Silva
date: 2023-03-12T21:48:18+00:00
layout: single
permalink: /powershell/
excerpt: ''
categories:
  - PowerShell
tags:
  - 
  - 
  - PowerShell
---

Demo Sensitive Info in your terminal
https://blog.technodrone.cloud/2021/07/demo-sensitive-info-terminal.html



I would like to share something really useful that I learned today from a colleague (huge shout out to Boaz Ziniman - a fellow AWS Developer Advocate)

Have you ever demoed something on your your terminal and while running through the demo - you have on the screen some information that you do not want to actually show the rest of the world?

For example you are demoing your AWS setup and you want to show the setup of your ~/.aws/credentials file - but you dont really want to show the real contents of your AWS Access KEY and your AWS Secret Access Key - because this sensitive information you should not be sharing.

Perhaps you do not want share your AWS Account ID (12 digit number) when demo’ing something in your account either.

So Boaz introduced me to a feature in iTerm2 - called Triggers.

    A trigger is an action that is performed when text matching some regular expression is received in a terminal session.

If you can write a regular expression for something - you can use triggers to hide it from showing up in your console while sharing your screen. Really, it’s that simple.

In iTerm2 -> Preferences -> Profiles -> Advanced -> Triggers -> Edit

iTerm2 settings

Here are a few examples and the relevant regex.

    hide your AWS Account ID from appearing in your terminal
    ((?<=:)(\d{12})(?=:)|(?<=")(\d{12})(?="))
    hide your AWS Access Key ID
    (A3T[A-Z0-9]|AKIA|AGPA|AIDA|AROA|AIPA|ANPA|ANVA|ASIA)[A-Z0-9]{17}

And to hide them from the screen choose the Highlight Text.. action and choose the same color for the Text and the Background

triggers example

This is what it looks like on my terminal

hidden content

You no longer have to modify screenshots, or blur out recordings with software after they have been recorded. It is all built into your terminal.




https://learn.microsoft.com/en-us/rest/api/defenderforcloud/assignments/list?tabs=HTTP