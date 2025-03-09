---
title: 'Azure Chaos Studio [English]'
author: Victor Silva
date: 2022-12-21T23:53:56+00:00
layout: post
permalink: /azure-chaos-studio/
excerpt: 'Azure Chaos Studio is a manage service offered by Microsoft as part of its Azure cloud platform that enables users to test the resilience and reliability of their systems by introducing controlled failures and disruptions. In this blog post, we will walk through the steps for using Azure Chaos Studio to test the resilience of your systems.'
categories:
  - Azure
  - Chaos Engineering
  - Azure Chaos Studio
tags:
  - Azure
  - Chaos Engineering
  - Azure Chaos Studio
---

<div>This blog post is also a contribution to Azure Advent Calendar where during December, experts from the tech community share their knowledge through contributions of a specific technology in the Azure domain. You’re welcome to check out all the contributions here: <a href="">Azure Advent Calendar</a></div>{: .notice}

Azure Chaos Studio is a manage service offered by Microsoft as part of its Azure cloud platform that enables users to test the resilience and reliability of their systems by introducing controlled failures and disruptions. In this blog post, we will walk through the steps for using Azure Chaos Studio to test the resilience of your systems.

One of the key benefits of using Azure Chaos Studio is that it allows users to identify and address potential vulnerabilities in their systems before they become major issues. By simulating real-world scenarios such as network outages and server crashes, users can see how their systems respond and identify any areas that may be weak or prone to failure. This enables users to take steps to improve the resilience and reliability of their systems before a real-world disruption occurs.

In addition to simulating failures, Azure Chaos Studio also provides users with the ability to monitor the performance of their systems during and after a test. This allows users to see how their systems are affected by the disruptions being introduced and identify any issues that may need to be addressed.

Another important aspect of Azure Chaos Studio is the ability to run tests on a regular basis. By setting up regular tests, users can ensure that their systems are constantly being tested and evaluated for resilience and reliability. This helps to ensure that systems are always operating at their best, and enables users to identify and address any issues that may arise over time.

Overall, Azure Chaos Studio is an important tool for any organization that relies on cloud-based applications and systems. By using it to test the resilience and reliability of their systems, organizations can be confident that their systems will be able to withstand the unexpected and continue to operate even in the face of disruptions. Whether you are looking to improve the resilience of your systems or simply ensure that they are operating at their best, Azure Chaos Studio is an invaluable resource that can help you achieve your goals.

## Prerequisites

Before you can use Azure Chaos Studio, you will need to sign up for an Azure account. If you do not already have an Azure account, you can sign up for a free trial at https://azure.microsoft.com/. Once you have an Azure account, you can access Azure Chaos Studio by logging into the Azure portal and searching Chaos Studio in the seach bar.

<img src="/assets/images/postsImages/AZ_CHAOS_01.png" class="alignnone">

Now, it's time to create a Managed Identity to give Chaos Studio the ability to wreak havoc on the resources. Search `managed identities` and click on the **Create** button.

Select the `Subscription` the resources that you want to test against. Select your `Resource Group` (I prefer a new one) to place the managed identity in. Select the `Region` on the Instance details section and type in a name.

<img src="/assets/images/postsImages/AZ_CHAOS_02.png" class="alignnone">

Click on Review and create and create again.

If you prefer to use Azure CLI:

{% highlight posh%}
az login
az identity create --name AzChaos --resource-group chaosTest
{% endhighlight %}

Firstly, login to azure using the `az login` and typing the credentials previously used to login into the web portal. After that, run the second command to create resource.

## Create experiments

Once you are into the Azure Chaos Studio page, the first step is to select the application or system that you want to test, called **Targets**. You can select a specific application or system from the list of available options, or you can select an entire resource group or subscription to test all of the applications and systems within that group or subscription.

Click on the Targets option from the left side of the page, and use the search bar to select across your subscriptions the resource (or resources). I'll use a Windows 10 VM, named `W10` from the `LAB` subscription and resource group `automation`.

<img src="/assets/images/postsImages/AZ_CHAOS_03.png" class="alignnone">

Click the `Enable targets` button and select the Enable agent-based targets (VM, VMSS) because the target is a VM and you can run in-guest failures like applying virtual memory pressure or killing a specific process.

Now appears a new wizard to complete the configuration of the target, selecting the managed identity previously created. Last section in this wizard is the posibility to send diagnostic information to an Application Insights account. For this demo, select disable to skip it.

<img src="/assets/images/postsImages/AZ_CHAOS_04.png" class="alignnone">

Click to the button `Review + Enable` and click again on the button `Enable`.

Next, you will need to choose the type of test you want to run. This tests are called **Experiments**. Azure Chaos Studio provides a range of options for simulating different types of failures and disruptions, including network outages, server crashes, and other types of faults. You can select one or more types of tests to run, depending on the specific scenarios you want to test.

After you have chosen the type of test you want to run, you will need to configure the test settings. This includes specifying the duration of the test, the frequency of the disruptions, and any other relevant settings. You can also specify any additional parameters or conditions that you want to include in the test.

Click on `Experiments` and click on `Create chaos experiment`. Type a name for the experiment and select the correct Resource group and Subscription:

<img src="/assets/images/postsImages/AZ_CHAOS_05.png" class="alignnone">

Click on `Next: Experiment designer` to define the steps required. Next, click on `Add action` and select the Add fault option, because will select an option related to the system (for this demo).

Select the CPU Pressure faul from the fault list and set the time and pressure level parameters:

<img src="/assets/images/postsImages/AZ_CHAOS_06.png" class="alignnone">

Click on the Next: `Target resources` button.

Choose the W10 resource and click to Add.

<img src="/assets/images/postsImages/AZ_CHAOS_07.png" class="alignnone">

Click on `Review + Create` to access to the summary information. Click on the Create button to complete the process of create an experiment.

## Run the experiments and monitor

Once you have configured the test settings, you are ready to run the test. To start the test, simply select an experiment form the list (on the Experiments section inside the Chaos Studio welcome page) and click the "Start Experiment(s)" button. The test will then be initiated, and Azure Chaos Studio will begin introducing the specified disruptions and failures into your target system.

As the test is running, you can monitor the performance of your system in real-time using the Azure Chaos Studio interface. You can also set up alerts to notify you if certain thresholds are reached or if any issues arise during the test. Once the test is complete, you can review the results and use the insights gained to identify and address any vulnerabilities or weaknesses in your system.

<img src="/assets/images/postsImages/AZ_CHAOS_08.png" class="alignnone">

## Iteration

After you have run your initial test, you can use the insights gained to iterate and refine your tests. You can modify the test settings and parameters, add additional tests, or run tests on a regular basis to ensure that your system is constantly being tested and evaluated for resilience.

By following these steps, you can use Azure Chaos Studio to test the resilience and reliability of your systems and ensure that they are able to withstand unexpected disruptions. Whether you are looking to improve the resilience of your systems or simply ensure that they are operating at their best, Azure Chaos Studio is a powerful tool that can help you achieve your goals.

For more information about Chaos Engineering, please read the <a href="https://principlesofchaos.org/">Principles of Chaos Engineering</a>

Happy scripting!