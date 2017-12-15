---
layout: single
title: Azure posts
permalink: /azure/
sitemap: false
---

<table>
<tr>
    <th>Fecha</th>
    <th>Titulo</th> 
</tr>
{% for post in site.categories.Azure %}
<tr>
<!--<li><span>{{ post.date | date_to_string }}</span> &nbsp; <a href="{{ post.url }}">{{ post.title }}</a></li>-->
    <td><span>{{ post.date | date_to_string }}</span></td>
    <td><a href="{{ post.url }}">{{ post.title }}</a></td>
</tr>
{% endfor %}
</table>