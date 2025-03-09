--- 
title: "Automate the posts on Twitter using a AWS Lambda function and PowerShell [English]" 
author: Victor Silva
date: 2019-01-01T19:57:00+00:00 
layout: post 
permalink: /aws-lambda-powershell-twitter/ 
excerpt: "A few months ago, I started to learn about Amazon Web Services (AWS) because I had the necessity to expand my knowledge of cloud services offers. Additional to this, I follow the technical blog from Amazon and I read about the support for PowerShell Core 6 and I worked a lot with serverless (using Azure Functions) so for that, serverless have a place in my heart nowadays" 
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

A few months ago, I started learning about Amazon Web Services (AWS) because I had the necessity to expand my knowledge of cloud services offers. In addition to this, I follow Amazon´s technical blog and I read about the support for PowerShell Core 6 (I worked a lot with serverless, using Azure Functions) so for that, serverless has a place in my heart nowadays. Well, with the above, I´ll share how to work with AWS, in particular with the serverless solution called Lambda with PowerShell Core.

How will I explain that in detail? By sharing with you an excellent example: A way to send automated blog post on Twitter without "human" interaction.

## Setting up a development environment

Before we get started developing PowerShell Core based Lambda functions, let’s set up our dev environment.

First, I recommend you to use [Visual Studio Code](https://code.visualstudio.com/download), because the *ISE* (Integrated Scripting Environment) doesn't support PowerShell Core. But, you need to configure a few things before start coding...

### Installing PowerShell Extension

Launch the Visual Studio Code app by typing `code` in your PowerShell session and pressing Ctrl+P to launch *Quick Open*. In Quick Open, type `ext install powershell` and hit *Enter*. The Extensions view opens on the side bar, select the PowerShell extension from Microsoft. So then, click the Install button on PowerShell, after the setup, you´ll see the Install button to Reload. Click that.

After Visual Studio Code has reloaded, you are ready for editing PowerShell files :)

### Using PowerShell Core version

Because the objective is to use PowerShell Core, we need to add a new variable to your profile settings file.

Open VSCode and click *File*, after that click on *Preferences* and the last step is to select *Settings*.

Find up in the right corner, a button with two curly brackets ({ and }). Two editor panes will appear. In the right-most pane (user settings), insert the setting bellow:

{% highlight posh%}
  "powershell.powerShellExePath": "c:/Program Files/PowerShell/6/pwsh.exe"
{% endhighlight %}

The number **6** represents the version of PowerShell (core).
Save the settings file and restart VSCode.

### Install the .NET Core SDK

Next, we need to install the .NET Core 2.2 SDK, because the Lambda support for PowerShell uses the same .NET Core. The .NET Core SDK is used by PowerShell publishing cmdlets for Lambda to create the Lambda deployment package.

You can find the .NET Core 2.2 SDK [here](https://www.microsoft.com/net/download).

### Install the PowerShell module AWSLambdaPSCore

The last component we need for the development environment is the **AWSLambdaPSCore** module, that you can install from the PowerShell Gallery directly, using the following command:

{% highlight posh%}
  Install-Module AWSLambdaPSCore -Scope CurrentUser
{% endhighlight %}

Additionally, we need to install the **AWSPowerShell.NetCore** module, for work with other AWS Services.

{% highlight posh%}
  Install-Module AWSPowerShell.NetCore
{% endhighlight %}

Well, after all changes we'll continue on the next post, configuring the files on the blog and the AWS S3 service for storing the records (published posts).

## Prepare the blog for collecting the data

After all the steps required to set the dev environment, we are ready to start working with the next section: collecting the data. As the section title indicates, the main purpose of this post is sharing how to modify the blog adding a new file to join all the posts info  and creating another file that save all the published Tweets.

### All posts

First we need to improve the blog, adding a new file called ***entries.html*** that centralize all the entries with a specific format (JSON). Store it in the root directory.

<script src="https://gist.github.com/vmsilvamolina/0595b11f66d553a00f9718a774a5c777.js"></script>

The file will show all the posts published, as shown in the image:

<img src="https://8gmarg.ch.files.1drv.com/y4mrJRh7wHVbXCTmGYIpQHhndOnwWs4zni1EhoLiWsI_2zQY3GXSLuEEsOmimJoaMZPZTTPNF48sH7Yx-LzoeQiOCoMHh2eRcNkUTNDGouFP7UbZKP70rLGZle9rZ3pzTR2oQ5BLCpnd5_O3kKD6ZXHnShGJFfqWyS7w1xxvnGLluwurcobFYkJEwEbMjIpzriNLjp77k3UJou_QNYtvDMbpQ" height="398" alt="entries.html file" class="alignnone" />

### History file

We need to have a file that work as history record to save all the previous Tweets published because I don't like repeating the same post 2 times in a row, for example. The first step is defining what type of info the file will save, for example, the date of the last published tweet and a list of previously published posts, like this:

{% highlight json%}
  {
    "lastTweetedDate": "",
    "tweetedPosts": []
  }
{% endhighlight %}

### AWS S3 bucket

You need to create a AWS S3 bucket and upload the history file, because you need to access this file each time that the Lambda function run. 

Before running any command associated to AWS, I´ll explain a way to set the access to the cloud services from the console. Using the commands provided from Amazon, you have a pair of parameters to set the info related to your credentials:

* **AccessKey**
* **SecretAccessKey**

How to obtain those values? You need to login to the AWS console ([https://aws.amazon.com/console/](https://aws.amazon.com/console/)). Under your profile name, select the option: **My security credentials**. Select the section **Access keys (access key ID and secret access key)** and click over the button **Create New Access Key**. The last step is downloading the file with the info or select the *Show Access Key* option to copy/paste to a secure site (I´ll explain how to use *Environment Variables* with Lambda to store securely that info).

Now, you can use the following command (you must have installed the **AWSPowerShell.NetCore** module, previously commented):

{% highlight posh%}
  New-S3Bucket -BucketName '\<bucketName\>' -AccessKey '\<accessKey\>' -SecretAccessKey '\<secretAccessKey\>' -PublicReadOnly
{% endhighlight %}

Perfect! The following step is upload the history file to the new S3 bucket, using the command:

{% highlight posh%}
  Write-S3Object -BucketName $bucketName -File C:\history.json -AccessKey $accessKey -SecretAccessKey $secretAccessKey
{% endhighlight %}

**Note:** I replaced the values with variables (strings) to simplify the syntax.

Well, The last configuration step over the files is grant the public access (read), inside the overview tab, select the button **Make public**:

<img src="https://v5xzcw.ch.files.1drv.com/y4m0THkeEZyPty26-6K1MVDtZJzH2JS8D8gnYqvu1ViDpnxtJOLqPAhcb7Wsa6ifeBc2kOfsRFqqvpxnHuWzoJiKwlmg221vFsEocd1xaasUGZR5H4Z5Ze7mjHNlzo_jQjaxOIzI8RvZdZpO2EJAqbUx3W5ISp_yUBC9hAygTzrM2FhvXrunvclPFNfnhXI5fK1LPvCeqtp_T6YhGKVS1bp_Q?width=937&height=220&cropmode=none" alt="" class="alignnone" height="200" />

## Create the Lambda function to publish on Twitter

So, now we need to create the Lambda Function, running the following commmand:

{% highlight posh%}
  New-AWSPowerShellLambda -ScriptName "TwitterBlog" -Template Basic
{% endhighlight %}

After that, edit the function file running the commands below:

{% highlight posh%}
  cd .\TwitterBlog\
  code .\TwitterBlog.ps1
{% endhighlight %}

And add the next code to the function file (TwitterBlog.ps1):

{% highlight posh%}
  # Define variables and extra info
  $bucketName = "" #Add the Bucket name
  $historyFile = "https://s3.\<AWSregion\>.amazonaws.com/$bucketName/history.json" #Add the correct region
  $blogFeed = "https://blogDomain.com/entries.json" #Change the URL with the correct file

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

  [Reflection.Assembly]::LoadWithPartialName("System.Security")
  [Reflection.Assembly]::LoadWithPartialName("System.Net")  
      
  # Set your OAuth variables and such
  $message = [System.Uri]::EscapeDataString($body)
  $oauth_consumer_key = $env:twitterConsumerKey
  $oauth_consumer_secret = $env:twitterConsumerSecret
  $oauth_token = $env:twitterToken
  $oauth_token_secret = $env:twitterTokenSecret
  $random = New-Object -type Random
  $oauth_nonce = $random.Next()
  $culture = New-Object System.Globalization.CultureInfo("en-US")
  $ts = [System.DateTime]::UtcNow - [System.DateTime]::ParseExact("01/01/1970", "dd/MM/yyyy", $null)
  $oauth_timestamp = [System.Convert]::ToInt64($ts.TotalSeconds).ToString()
      
  # Build base signature
  $signature = "POST&"
  $signature += [System.Uri]::EscapeDataString("https://api.twitter.com/1.1/statuses/update.json") + "&"
  $signature += [System.Uri]::EscapeDataString("oauth_consumer_key=" + $oauth_consumer_key + "&")
  $signature += [System.Uri]::EscapeDataString("oauth_nonce=" + $oauth_nonce + "&")
  $signature += [System.Uri]::EscapeDataString("oauth_signature_method=HMAC-SHA1&")
  $signature += [System.Uri]::EscapeDataString("oauth_timestamp=" + $oauth_timestamp + "&")
  $signature += [System.Uri]::EscapeDataString("oauth_token=" + $oauth_token + "&")
  $signature += [System.Uri]::EscapeDataString("oauth_version=1.0&")
  $signature += [System.Uri]::EscapeDataString("status=" + $message)
  $signature_key = [System.Uri]::EscapeDataString($oauth_consumer_secret) + "&" + [System.Uri]::EscapeDataString($oauth_token_secret)
      
  # Convert via SHA1
  $hmacsha1 = new-object System.Security.Cryptography.HMACSHA1
  $hmacsha1.Key = [System.Text.Encoding]::ASCII.GetBytes($signature_key)
  $oauth_signature = [System.Convert]::ToBase64String($hmacsha1.ComputeHash([System.Text.Encoding]::ASCII.GetBytes($signature)))
      
  # Build OAuth Header
  $oauth_authorization = 'OAuth '
  $oauth_authorization += 'oauth_consumer_key="' + [System.Uri]::EscapeDataString($oauth_consumer_key) + '", '
  $oauth_authorization += 'oauth_nonce="' + [System.Uri]::EscapeDataString($oauth_nonce) + '", '
  $oauth_authorization += 'oauth_signature="' + [System.Uri]::EscapeDataString($oauth_signature) + '", '
  $oauth_authorization += 'oauth_signature_method="HMAC-SHA1", '
  $oauth_authorization += 'oauth_timestamp="' + [System.Uri]::EscapeDataString($oauth_timestamp) + '", '
  $oauth_authorization += 'oauth_token="' + [System.Uri]::EscapeDataString($oauth_token) + '", '
  $oauth_authorization += 'oauth_version="1.0"'
      
  # Build body
  $post_body = [System.Text.Encoding]::ASCII.GetBytes("status=" + $message)
      
  # Set basic information for Invoke-RestMethod
  $headers = @{"Authorization" = $oauth_authorization}
  $contenttype = "application/x-www-form-urlencoded"
  $post_body

  #Post a Tweet
  $tweet = Invoke-RestMethod -Method Post -Uri "https://api.twitter.com/1.1/statuses/update.json" -Headers $headers -ContentType $contenttype -Body $post_body
  $tweetJson = $tweet | ConvertTo-Json
  Write-Output "Tweet sent:`n$tweetJson"

  #Save teh info to the history
  $date = (Get-Date).ToUniversalTime().ToString('u')
  $tweetedPost = @{
    url = $post.url
    tweetDate = $date
  }
  $history.lastTweetedDate = $date
  $history.tweetedPosts += $tweetedPost
  Write-S3Object -BucketName $bucketName -Key history.json -AccessKey $env:accessKey -SecretAccessKey $env:secretAccessKey -Content ($history | ConvertTo-Json) -PublicReadOnly

{% endhighlight %}

If you pay attention, I defined some environment variables. These are for hiding information about private keys and secrets from AWS access and Twitter API.

**Note:** To obtain the Twitter's keys and secrets, access to: [https://developer.twitter.com/en/apps](https://developer.twitter.com/en/apps)

You can read the next document to learn how to use environment variables on AWS services:[https://docs.aws.amazon.com/lambda/latest/dg/env_variables.html](https://docs.aws.amazon.com/lambda/latest/dg/env_variables.html)

## Publish the Lambda function

To publish the Lambda function, you can run the command:

{% highlight posh%}
  Publish-AWSPowerShellLambda -ScriptPath .\TwitterBlog.ps1 -Name "TwitterBlog" -Region <region>
{% endhighlight %}

You need to define a role following the instructions. Only need **AWSLambdaEdgeExecutionRole** permission.

### Workaround

If you had problems executing the previous command, the alternative way to publish the function is execute the command **New-AWSPowerShellLambdaPackage** with the following syntax:

{% highlight posh%}
  New-AWSPowerShellLambdaPackage -ScriptPath .\TwitterBlog.ps1 -OutputPackage fileUploader.zip
{% endhighlight %}

And upload the file on the AWS Lambda console, specifying the **LambdaHandler** (appearing on the output from the above command) on the *Function Code* section.

After that, click on the **Save** button.

<img src="https://vcbmaq.ch.files.1drv.com/y4mpd3TbNyj5tuhQbi2jdOJTFvUZq4xu8YoCeP9HxhLSvBu0izjv5S3DTNHi-BzHIsh69spHG8Fu9WQzufyofjOwozz-_9ZsOaetoRp2wj7UhulzRA-M4-KiQltVlIx5BGn0YmROBAbMs55D_pKyXfFMclbNgeeS_6UhmqY-R7gaeJswowb3l92Z_Z8M6Z0AJd8QBLz2AkSO_LxnbBoEDPCHQ?width=1497&height=766&cropmode=none" alt="New-AWSPowerShellLambdaPackage example" class="alignnone" />

## Trigger: CloudWatch Events

The last step is coming: the function exist and the necessary files too. Let’s set up the CloudWatch schedule event to trigger the Lambda function. To do that, go to the configuration section in the Lambda console and select CloudWatch Events in the configure triggers section.

<img src="https://hjf9iw.ch.files.1drv.com/y4m2X6II_S_Vp0HOMjKtbDBKa2FGHQ3ZdnjyLRQ2g2CjVlRx0zyW43t_fNPKQdQA9IKduMR_Nh3HzYss4upv1Q6ZbtVH0kUE9xZ-3Gyx2r7Ma1jpOaSn1mt2sZpKVZyqbJVnQsLDpO_3Fxjn-y-TSiyHfSWT_YcPOgfcSntaqZAckRcx0joOoisYZgKbYJMrpvIBxLYbdE5xCaIuQbIZ8gq1w?width=1694&height=350&cropmode=none" alt="AWS Lambda function with CloudWatch Events" class="alignnone" />

This opens a new Configure trigger panel to set up the schedule event. We’ll need to set the following fields.

Select the **Create a new rule** option and define a unique name to identify this rule. Set to **Scheduled expression** the rule type. The expression identifies the frequency to run the script (this can be expressed in either a Cron expression or a Rate expression). To see our new PowerShell based Lambda function in action, let’s set this value to `rate(5 minutes)` to have it run every 5 minutes.

And voilà! After a few minutes you can see a tweet published from AWS Lambda function using PowerShell Core.

<img src="https://iaykxg.ch.files.1drv.com/y4mKaqkG7vuBER-gubKPILnyZokbumOPnv7A-2XBiR8JliVUkkNByyQBfJD1zsxO5KB2329C8aW7iJna8jv6Fc_6ugDp407rWMNKMIi1ZzrVw_bTKD8h8AHQNpdGcoshFx2Cv6ubd69EZSCcZffTUIrpyuJ-JLw4gySp9-MG_7tdSFDX7rxYu9N7GcJRntH-wcLPz-oxJ5mJE68XkvmAgQiGA?width=952&height=450&cropmode=none" alt="Tweeet example using AWS Lambda function and PowerShell Core" class="alignnone" />

## Little tips...

A short list to check on your blog before start using that!

1. **Fix all the tags**: Bacause every tweet use each tag as hashtag, you need to correct every tag to share specific information about your post.
2. **Fix the titles**: You must correct all the URLs: If a URL is too long you can set a new URL and redirect from the old with the *redirect_from* plugin from Jekyll. Another approach is adding a service like **bit.ly** to generate a short URL.
3. **Update the content**: If you start publishing old posts, you need to work to update all the content of your posts.

Happy scripting!