---
layout: single
title: All posts
permalink: /allposts/
sitemap: false
---

<ul class="taxonomy__index">
  {% assign postsInYear = site.posts | group_by_exp: 'post', 'post.date | date: "%Y"' %}
  {% for year in postsInYear %}
    <li>
      <a href="#{{ year.name }}">
        <strong>{{ year.name }}</strong> <span class="taxonomy__count">{{ year.items | size }}</span>
      </a>
    </li>
  {% endfor %}
</ul>

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