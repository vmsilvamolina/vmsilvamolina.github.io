---
layout: single
title: All posts
permalink: /allposts/
sitemap: false
---

<table>
<tr>
    <th>Fecha</th>
    <th>Titulo</th> 
</tr>
{% for post in site.posts %}
<tr>
    <td><span>{{ post.date | date_to_string }}</span></td>
    <td><a href="{{ post.url }}">{{ post.title }}</a></td>
</tr>
{% endfor %}
</table>