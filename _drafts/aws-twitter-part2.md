--- 
title: "Using a Lambda Function to automated blog post on Twitter (part 1) [English]" 
author: Victor Silva
date: 2019-01-12T15:24:00+00:00 
layout: single 
permalink: /aws-lambda-powershell-twitter-2/ 
excerpt: "Well, after all the steps required to set the dev environment, we are ready to start to work with AWS Lambda and PowerShell Core. As the title indicates, the purpose of this post is share how to send posts from my blog to twitter without any human interaction." 
categories: 
  - PowerShell 
  - AWS 
  - DevOps 
tags: 
  - PowerShell
  - PowerShell Core 
  - AWS 
  - Serverless 
  - Lambda 
  - Scripting
  - Automation 
  - English
--- 

<div>
<p>This post is part of a series of related posts:</p>
<li><a href="https://blog.victorsilva.com.uy/aws-lambda-powershell-twitter/">Lambda Function to automated blog post on Twitter - Setting up a development environment</a></li>
<li>Lambda Function to automated blog post on Twitter - Configuring source files and AWS storage</li>
<li>Lambda Function to automated blog post on Twitter - Creating the schedule</li>
</div>{: .notice--success}

## Using Lambda function to publish on twitter

Well, after all the steps required to set the dev environment, we are ready to start to work with AWS Lambda and PowerShell Core. As the title indicates, the purpose of this post is share how to send posts from my blog to twitter without any human interaction.

First we need to modify a little the blog, adding a new file called ***entries.json*** that centralize all the entries.

{% highlight plaintext%}
  ---
  layout: null
  permalink: /entries.json
  sitemap: false
  ---

  {
      "title": "{{ site.title}}",
      "description": "{{ site.description }}",
      "url": "{{ site.url }}",
      "date": "{{ site.time | date_to_rfc822 }}",
      "posts": [
          {% for post in site.posts %}
          {% if post.hide_from_feed != true %}
          {% if forloop.first != true %},{% endif %}
          {
          "title": "{{ post.title }}",
          "url": "{{ post.url | prepend: site.baseurl }}",
          "date": "{{ post.date | date_to_rfc822 }}",
          "tags": {{ post.tags | jsonify }},
          "categories": {{ post.categories | jsonify }}
          }
          {% endif %}
          {% endfor %}
      ]
  }
{% endhighlight %}



Install-Module AWSPowerShell.NetCore



https://docs.aws.amazon.com/lambda/latest/dg/powershell-programming-model.htm