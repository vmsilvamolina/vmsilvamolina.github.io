---
layout: single
title: PowerShell posts
permalink: /powershell/
sitemap: false
---

<table>
<tr>
    <th>Fecha</th>
    <th>Titulo</th> 
</tr>
{% for post in site.categories.PowerShell %}
<tr>
<!--<li><span>{{ post.date | date_to_string }}</span> &nbsp; <a href="{{ post.url }}">{{ post.title }}</a></li>-->
    <td><span>{{ post.date | date_to_string }}</span></td>
    <td><a href="{{ post.url }}">{{ post.title }}</a></td>
</tr>
{% endfor %}
</table>