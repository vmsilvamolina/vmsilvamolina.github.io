--- 
title: "Automate the posts on Twitter using a AWS Lambda function and PowerShell [English]" 
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
  - PowerShell Core 
  - AWS 
  - Serverless 
  - Lambda
  - S3
  - Scripting
  - Automation
  - English
--- 

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

## Prepare the blog for collect the data

Well, after all the steps required to set the dev environment, we are ready to start to work with the next section: collect the data. As the section title indicates, the main purpose of this post is share how to modify the blog adding a new file to join all the posts info  and creating another file that save all the published Tweets.

### All posts

First we need to improve the blog, adding a new file called ***entries.html*** that centralize all the entries with a specific format (JSON). Store it in the root directory.

<script src="https://gist.github.com/vmsilvamolina/0595b11f66d553a00f9718a774a5c777.js"></script>

The file will show all the posts published, as shown in the image:

<img src="https://8gmarg.ch.files.1drv.com/y4mrJRh7wHVbXCTmGYIpQHhndOnwWs4zni1EhoLiWsI_2zQY3GXSLuEEsOmimJoaMZPZTTPNF48sH7Yx-LzoeQiOCoMHh2eRcNkUTNDGouFP7UbZKP70rLGZle9rZ3pzTR2oQ5BLCpnd5_O3kKD6ZXHnShGJFfqWyS7w1xxvnGLluwurcobFYkJEwEbMjIpzriNLjp77k3UJou_QNYtvDMbpQ" height="398" alt="entries.html file" class="alignnone" />

### History file

We need to have a file that work as history record to save all the previous Tweets published because I don't like repeat the same post 2 times in a row, for example. The first step is define what type of info the file will save, for example, the date of the last published tweet and a list of previously published posts, like this:

{% highlight json%}
  {
    "lastTweetedDate": "",
    "tweetedPosts": []
  }
{% endhighlight %}


### AWS S3 bucket

You need to create a AWS S3 bucket and upload the history file, because you need to access to this file each time that the Lambda function run. 

Before run any command associated to AWS, I´ll explain a way to set the access to the cloud services from the console. Using the commands provided from Amazon, you have a pair of parameters to set the info related to your credentials:

* **AccessKey**
* **SecretAccessKey**

How to obtain that values? You need to login to the AWS console ([https://aws.amazon.com/console/](https://aws.amazon.com/console/)). Under your profile name, select the option: **My security credentials**. Select the section **Access keys (access key ID and secret access key)** and click over the button **Create New Access Key**. The last step is download the file with the info or select the *Show Access Key* option to copy/paste to a secure site (I´ll explain how to use *Environment Variables* with Lambda to store securely that info).

Now, you can use the following command (you must have installed the **AWSPowerShell.NetCore** module, previously commented):

{% highlight posh%}
  New-S3Bucket -BucketName '\<bucketName\>' -AccessKey '\<accessKey\>' -SecretAccessKey '\<secretAccessKey\>' -PublicReadOnly
{% endhighlight %}

Perfect! The following step is upload the history file to the new S3 bucket, using the command:

{% highlight posh%}
  Write-S3Object -BucketName $bucketName -File C:\history.json -AccessKey $accessKey -SecretAccessKey $secretAccessKey
{% endhighlight %}

**Note:** I replace the values with variables (strings) to simplify the syntax.

Well, The last configuration step over the files is grant the public access (read)

## Using Lambda function to publish on Twitter

So when, 

{% highlight posh%}
  # Define variables and extra info
  $bucketName = ""
  $historyFile = "https://s3.\<AWSregion\>.amazonaws.com/$bucketName/history.json"
  $blogFeed = "https://blog.victorsilva.com.uy/entries.json"

  # Load history file and blog entries
  $history = Invoke-WebRequest -Uri $historyFile | ConvertFrom-Json
  $feed = Invoke-RestMethod -Uri $blogFeed

  # Get a post from the list of available posts that we haven't already tweeted
  $tweetedUrls = $history.tweetedPosts | Select-Object -ExpandProperty url
  $postsToPublish = $feed.posts.Where({$_.url -notin $tweetedUrls})
  $post = $postsToPublish | Get-Random

  # Hashtags
  $hashtags = ""
  $post.tags | Foreach-Object {
      $hashtags += (' #' + ($_ -replace ' ', ''))
  }
  $hashtags = $hashtags.Trim()

  #Tweet info
  $title = $post.title
  $link = "https://blog.victorsilva.com.uy"+$post.url
  $body = "Blog post: $title`n$link`n$hashtags"

  #Tweet using the API
  <#
  $oAuth = @{
      ApiKey            = $env:TWITTER_CONSUMER_KEY
      ApiSecret         = $env:TWITTER_CONSUMER_SECRET
      AccessToken       = $env:TWITTER_ACCESS_TOKEN
      AccessTokenSecret = $env:TWITTER_ACCESS_SECRET
  }
  $tweetParams = @{
      ResourceURL   = 'statuses/update.json'
      RestVerb      = 'POST'
      Parameters    = @{
          status = $tweetText
      }
      OAuthSettings = $oAuth
  }
  $tweet     = Invoke-TwitterRestMethod @tweetParams
  $tweetJson = $tweet | ConvertTo-Json
  Write-Output "Tweet sent:`n$tweetJson"
  #>

  #Save teh info to the history
  $date = (Get-Date).ToUniversalTime().ToString('u')
  $tweetedPost = @{
    url = $post.url
    tweetDate = $date
  }
  $history.lastTweetedDate = $date
  $history.tweetedPosts += $tweetedPost
  Write-S3Object -BucketName $bucketName -Key history.json -AccessKey $accessKey -SecretAccessKey $secretAccessKey -Content ($history | ConvertTo-Json)

{% endhighlight %}

## Little tips...

1- **Fix all the tags**: Bacause every tweet use each tag with hashtag, you need to correct every tag to share specific information about your post.
2- **Fix the titles**: You must correct all the URL: If a URL is too long you can set a new URL and redirect from the all with the redirect_from plugin from Jekyll. Another approach is add a service like **bit.ly** to generate a short URL.
3- 

Happy scripting!