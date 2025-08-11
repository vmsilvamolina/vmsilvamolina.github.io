---
title: 'Exploring OCI CLI Interactive Mode [English]'
author: Victor Silva
date: 2024-04-12T06:43:26+00:00
layout: post
permalink: /oci-cli-interactive/
excerpt: "Working with Oracle Cloud Infrastructure through the command line can sometimes feel like navigating a maze of parameters, OCIDs, and complex syntax. Whether you're new to OCI or a seasoned cloud engineer, remembering every parameter for every service can be challenging. This is where OCI CLI's interactive mode (`-i`) becomes your best friend—transforming complex commands into guided, user-friendly experiences."
categories:
  - Oracle
tags:
  - Oracle Cloud
  - CLI
  - OCI
  - Command Line
---

Working with Oracle Cloud Infrastructure through the command line can sometimes feel like navigating a maze of parameters, OCIDs, and complex syntax. Whether you're new to OCI or a seasoned cloud engineer, remembering every parameter for every service can be challenging. This is where OCI CLI's interactive mode (`-i`) becomes your best friend—transforming complex commands into guided, user-friendly experiences.

In this post, I'll walk you through the power of OCI CLI interactive mode with practical examples that will change how you interact with your OCI environment.

## What is OCI CLI Interactive Mode?

Interactive mode is a feature that transforms the traditional command-line experience into a guided, step-by-step process. Instead of memorizing complex parameter combinations, you simply add the -i flag to any OCI CLI command, and the tool walks you through the available options.
Think of it as having an intelligent assistant that knows every OCI service and helps you build the perfect command without consulting documentation every time.

## Getting Started: Your First Interactive Command

Let's start with something simple—listing compute instances. Instead of remembering all the parameters, try this:

```
oci -i
```

And continue with the subcommand `compute` to start viewing the available options:

<img src="">

We can use the 

## Completing A Command




```
oci compute instance launch -i
```

<script src="https://asciinema.org/a/XjUZqwnggfu684uQyvb2rDsIV.js" id="asciicast-XjUZqwnggfu684uQyvb2rDsIV" async="true"></script>
