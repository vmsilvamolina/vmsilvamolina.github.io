---
title: 'Run gcloud commands scheduled [English]'
author: Victor Silva
date: 2023-09-17T23:34:45+00:00
layout: single
permalink: /run-gcloud-commands-scheduled/
excerpt: ''
categories:
  - GCP
  - Golang
  - Bash
tags:
  - GCP
  - gcloud
  - Cloud Run
  - Cloud Build
  - Artifact Registry
  - Golang
---

In today's cloud-driven world, managing resources and services efficiently is essential for any organization. Google Cloud Platform (GCP) provides a powerful set of tools, and one of the most versatile ones is the Google Cloud command-line interface, gcloud. However, as your infrastructure grows, manually running gcloud commands can become tedious and error-prone. In this tutorial, we'll explore how to automate gcloud commands inside a Cloud Run service, just as the victorsilva.com.uy blog discusses various aspects of cloud automation.

Introduction

As organizations increasingly adopt cloud technologies, they rely on tools like gcloud to interact with their cloud resources programmatically. Automating these commands can save time and reduce the chances of human error. Much like how Victor Silva's blog delves into the intricacies of Azure OpenAI and PowerShell, we'll explore how to automate gcloud commands effectively.

Getting Started

Before diving into the automation process, let's ensure we have the prerequisites in place, similar to how Victor Silva advises you to set up your environment:

Google Cloud Project: In the Google Cloud Console, create or select a project to work with.

Billing Enabled: Make sure billing is enabled for your Google Cloud project to access the necessary resources.

APIs Enabled: Enable the Cloud Run, Cloud Build, and Cloud Storage APIs to use the required services.

gcloud CLI: Install and initialize the gcloud CLI on your local machine to interact with Google Cloud from your command line.

IAM Roles: Request the appropriate IAM roles for your Google account. This includes roles like Cloud Build Editor, Cloud Run Admin, and others, as outlined in the tutorial.

Setting Defaults: Configure gcloud with defaults for your Cloud Run service, including your project and region.

Creating the Cloud Run Service

Much like how Victor Silva guides you through creating resources on Azure, let's create our Cloud Run service. We'll automate gcloud commands to generate reports of Cloud Run services.

Writing a Shell Script: Create a shell script that contains the gcloud commands you want to automate. This script will generate reports of Cloud Run services, similar to how you would define your PowerShell scripts.

Defining a Container: Use a Dockerfile to define the container environment for your Cloud Run service. This ensures that the necessary tools, like gcloud, are available within the service.

Setting Up a Cloud Storage Bucket: Create a Cloud Storage bucket where the generated reports will be saved. This bucket is similar to a destination folder for your PowerShell scripts.

Creating a Service Identity: To ensure security, create a service identity with limited permissions to access only the required resources, such as Cloud Run services and the Cloud Storage bucket.

Deploying the Service

Now, let's deploy our Cloud Run service, automating the deployment process, much like how Victor Silva deploys resources on Azure:

Building the Container Image: Use Cloud Build to build the container image for your Cloud Run service. This image includes your shell script and any dependencies.

Uploading to Container Registry: Upload the container image to Container Registry, where it can be accessed for deployment.

Deploying the Service: Deploy the container image to Cloud Run, specifying the necessary environment variables, such as the Cloud Storage bucket name and the service identity.

Testing and Automation

Once your Cloud Run service is deployed, you can test it by sending authenticated requests, just as Victor Silva demonstrates with API endpoints. These requests trigger the automation process to generate reports and save them to Cloud Storage.

Enhancing Robustness

To ensure the robustness of your automation process, consider rewriting it in a more robust programming language, as Victor Silva suggests. This can lead to better performance and shorter execution times.

Automation Strategies

Finally, explore automation strategies, much like how Victor Silva suggests automating tasks on Azure. You can schedule your Cloud Run service to run at specific intervals using Cloud Scheduler or create queued tasks for future automation.

In conclusion, much like Victor Silva's blog explores automation in the Azure ecosystem, this tutorial provides insights into automating gcloud commands within Google Cloud. By following these steps, you can efficiently manage your cloud resources and improve your organization's overall cloud operations. Happy automating!







In this tutorial, we'll explore how to create a Cloud Run service that automates Google Cloud (gcloud) commands using the gcloud and gsutil command-line tools. This allows you to efficiently manage and generate reports for Cloud Run services within the Google Cloud Platform (GCP) environment. This automation can be especially useful for routine tasks and reporting purposes. You can use the knowledge gained here to enhance your existing Cloud operations scripts or to create proof-of-concept services before building more robust solutions using client libraries.

Introduction

Using the gcloud and gsutil tools within a web service, like a Cloud Run service, provides a convenient way to interact with Google Cloud services. These tools are capable of a wide range of functions within Google Cloud, making them powerful resources. However, when using them within a web service, it's crucial to ensure security controls are in place to prevent misuse or unintentional harmful actions. This tutorial will guide you through setting up a secure and automated environment for executing gcloud commands.

Objectives

Before we begin, let's outline the objectives of this tutorial:

Write and build a custom container with a Dockerfile.
Write, build, and deploy a Cloud Run service.
Use the gcloud and gsutil tools safely within a web service.
Generate a report of Cloud Run services and save it to Cloud Storage.
Prerequisites

Before diving into the tutorial, make sure you have the following prerequisites in place:

A Google Cloud project created or selected for this tutorial.
Billing enabled for your Google Cloud project.
The Cloud Run, Cloud Build, and Cloud Storage APIs enabled.
The gcloud CLI installed and initialized.
Appropriate IAM roles granted to your Google account for Cloud Build, Cloud Run, Service Accounts, and more, as mentioned in the tutorial.
Configuration of gcloud defaults for your project and region.
Setting Up Your Environment

To configure gcloud with defaults for your Cloud Run service, you'll need to:

Set your default project using gcloud config set project PROJECT_ID.
Configure gcloud for your chosen region with gcloud config set run/region REGION.
Retrieving the Code Sample

To access the code sample used in this tutorial:

Clone the sample app repository to your local machine using git clone https://github.com/GoogleCloudPlatform/cloud-run-samples.git.
Navigate to the directory containing the Cloud Run sample code using cd cloud-run-samples/gcloud-report/.
Generating a Report and Uploading to Cloud Storage

The provided shell script (script.sh) generates a report of Cloud Run services within your project and region. It lists services based on a provided search argument, and then uploads the report to Cloud Storage. Key points about this script include:

It uses gcloud commands like gcloud run services list and gsutil cp to fetch service information and upload the report.
Security controls are implemented to minimize risks, including specifying the gcloud command in the code instead of relying on user input.
Invoking the Script on HTTP Request

A Go code (invoke.go) sets up a web service that runs the script.sh to generate a report. This code validates the search parameter to ensure it only contains safe characters, preventing malicious input. The web service passes the search parameter as an argument to the shell script.

Defining the Container Environment

The Dockerfile defines the container environment for your Cloud Run service. It's based on the gcloud Google Cloud CLI image, allowing you to use gcloud and gsutil without additional installation or configuration steps. The Dockerfile sets up the environment for running the Go code and shell script.

Setting Up the Cloud Storage Bucket

A Cloud Storage bucket is created for uploading reports. The bucket name should be globally unique.

Setting Up the Service Identity

A service identity is created with the necessary IAM permissions to read Cloud Run services and read from/write to the Cloud Storage bucket. This limited access ensures the service doesn't access other Google Cloud resources.

Shipping the Service

To deploy your code, you need to:

Build a container image with Cloud Build.
Upload the container image to Container Registry.
Deploy the container image to Cloud Run.
The necessary commands for these steps are provided in the tutorial.

Trying It Out

You can test the deployed service by using curl to send an authenticated request. The tutorial provides examples for generating a report and retrieving it from Cloud Storage.

Improving Robustness for the Future

The tutorial suggests ways to improve the robustness of the service for future development, including rewriting it in a more robust programming language and using the Cloud Run Admin API and Cloud Storage client library.

Automating This Operation

Finally, the tutorial hints at automating the report generation operation, such as running the service on a schedule with Cloud Scheduler or creating queued tasks with Google Tasks.