---
layout: single
title: PowerShell posts
permalink: /powershell/
sitemap: false
---

{% for post in site.categories.PowerShell %}
<!--<li><span>{{ post.date | date_to_string }}</span> &nbsp; <a href="{{ post.url }}">{{ post.title }}</a></li>-->
<li><a href="{{ post.url }}">{{ post.title }}</a></li>
{% endfor %}