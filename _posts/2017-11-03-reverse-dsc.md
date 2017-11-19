---
title: Reverse DSC
date: 2017-11-03T22:17:33+00:00
author: Victor Silva
layout: single
permalink: /reverse-dsc/
categories:
  - PowerShell
tags:
  - PowerShell
  - PowerShell DSC
  - Reverse DSC
---

Hace un par de posts atrás, hablamos de PowerShell DSC y de lo bueno que era incorporarlo para las organizaciones en estos días. Y digo en estos días, haciendo referencia a la necesidad de poder cumplir con los plazos y requerimientos definidos a la hora de desplegar recursos de forma ágil, en los timepos que corren.

Hoy quiero plantear el escenario a la inversa: que sucede cuando hoy tenemos algo demasiado complejo para volver a construir (o al menos, complejo para volver atrás paso a paso al punto inicial de la configuración)?

Para ello existe *Reverse DSC*, que básicamente lo que hace es el camino inverso a lo que permite hacer PowerShell DSC, obtener la configuración para llegar a ese estado deseado actual.

### Reverse DSC, de donde sale?

Reverse DSC surje gracias a Nik Charlebois (Microsoft Premier Field Engineer, SharePoint) desarrolló un módulo para PowerShell DSC que permite hacer ingeniería inversa sobre entornos complejos ya implementados.



