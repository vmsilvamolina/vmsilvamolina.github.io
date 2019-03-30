--- 
title: "Azure Front Door desde PowerShell" 
author: Victor Silva
date: 2019-02-20T13:27:00+00:00 
layout: single 
permalink: /azure-front-door-powershell/ 
excerpt: "" 
categories: 
  - PowerShell 
  - Azure
  - DevOps 
tags: 
  - PowerShell
  - Azure
  - Azure Front Door
--- 

Azure Front Door proporciona un punto de entrada brindando un servicio de failover global y eficiente para generar alta disponibilidad sin perder performance. De lo anterior, los que trabajan (o han trabajado) con Azure se estarán preguntando que diferencias hay con los servicios de Networking que hoy se ofrecen, como **Azure Traffic Manager** o... acá algunas características:


* Reverse Proxy (SSL Termination, ruteo basado en URL, URL rewrite y session affinity)
* Web Application Firewall (WAF)
* Accelerated Global routing
* Global Load Balancing entre el backend geo-distribuido
* Algo de CDN (cache de solicitudes)


## Implementar: ARM en acción

Para realizar la implementación vamos a apoyarnos en un template


https://vincentlauzon.com/2019/06/11/azure-front-door-with-app-service/
https://github.com/vplauzon/app-service/blob/master/front-door/deploy.json  
http://www.opsman.co.za/ding-dong-its-azure-front-door/
