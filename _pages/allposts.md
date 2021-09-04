---
layout: single
title: All posts
permalink: /allposts/
sitemap: false
---

<!--
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
-->

<div class="container">
{% for post in site.posts  %}
{% capture this_year %}{{ post.date | date: "%Y" }}{% endcapture %}
{% capture this_month %}{{ post.date | date: "%B" }}{% endcapture %}
{% capture next_year %}{{ post.previous.date | date: "%Y" }}{% endcapture %}
{% capture next_month %}{{ post.previous.date | date: "%B" }}{% endcapture %}
{% if forloop.first %}
  <div class="row">
    <div class="col-xs-2">
      <h2>{{ this_year }}</h2>
    </div>
    <div class="col-xs-2">
      <h3>{{ this_month }}</h3>
    </div>
    <div class="col-xs-8">
{% endif %}
      <h4><a href="{{ post.url }}">{{ post.title }}</a></h4>
{% if forloop.last %}
    </div>
{% else %}
{% if this_year != next_year %}
    <div class="row">
    <div class="col-xs-2">
      <h2>{{ next_year }}</h2>
    </div>
    <div class="col-xs-2">
      <h3>{{ next_month }}</h3>
    </div>
    <div class="col-xs-8">
{% else %}
{% if this_month != next_month %}
    <div class="col-xs-2">
      <h3>{{ next_month }}</h3>
    </div>
  <div>
{% endif %}
{% endif %}
{% endif %}
{% endfor %}
</div>

<!--
{% for post in site.posts  %}
{% capture this_year %}{{ post.date | date: "%Y" }}{% endcapture %}
{% capture this_month %}{{ post.date | date: "%B" }}{% endcapture %}
{% capture next_year %}{{ post.previous.date | date: "%Y" }}{% endcapture %}
{% capture next_month %}{{ post.previous.date | date: "%B" }}{% endcapture %}
{% if forloop.first %}
<h2 id="{{ this_year }}-ref">{{this_year}}</h2>
<h3 id="{{ this_year }}-{{ this_month }}-ref">{{ this_month }}</h3>
<ul>
{% endif %}
<li><a href="{{ post.url }}">{{ post.title }}</a></li>
{% if forloop.last %}
</ul>
{% else %}
{% if this_year != next_year %}
</ul>
<h2 id="{{ next_year }}-ref">{{next_year}}</h2>
<h3 id="{{ next_year }}-{{ next_month }}-ref">{{ next_month }}</h3>
<ul>
{% else %}    
{% if this_month != next_month %}
</ul>
<h3 id="{{ this_year }}-{{ next_month }}-ref">{{ next_month }}</h3>
<ul>
{% endif %}
{% endif %}
{% endif %}
{% endfor %}
-->