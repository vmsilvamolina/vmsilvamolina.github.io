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




ForEach-Object -Parallel works by forking work off to separate background runspaces.

Runspaces are the components that host your execution context, including all the variables defined in the current scope, so code that executes in a different runspace than the one you're calling the code from will not be able to "see" the variables you've defined.

You can instruct PowerShell to copy a reference to a variable from the calling runspace into the background runspace by using the using: scope modifier when referring to the variable inside the ForEach-Object block:

$testArrayP | ForEach-Object -Parallel{ 
    ($using:outputArrayP).Add("Hello $_")>$null
} -ThrottleLimit 5

https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_scopes?view=powershell-7.3#scope-modifiers



I created a ForEach-Object which works, but as soon as I add the -Parallel flag the loop fails with "you cannot call a method on a null-valued expression". I'm using Powershell 7.2

$outputArray = [System.Collections.ArrayList]@()
$outputArrayP = [System.Collections.ArrayList]@()
$testArray =[System.Collections.ArrayList]@()
$testArrayP =[System.Collections.ArrayList]@()

for ($i=0; $i -le 1000;$i++){
    $testArray.Add("Hello $i")>$null
    $testArrayP.Add("Hello $i")>$null
}

$testArray | ForEach-Object { 
    $outputArray.Add("Hello $_")>$null
}

$testArrayP | ForEach-Object -Parallel{ 
    $outputArrayP.Add("Hello $_")>$null
} -ThrottleLimit 5

The actual code stores database queries in an array that I want to run in parallel instead of this sample code.

Related question Making Requests in Parallel with Powershell results in "You cannot call a method on a null-valued expression" where the answer code works also in parallel, but does not answer why my code would fail.