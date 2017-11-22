---
title: Utilizando Gherkin con Pester 
date: 2017-11-03T22:17:33+00:00
author: Victor Silva
layout: single
permalink: /gherkin-con-pester/
categories:
  - PowerShell
tags:
  - PowerShell
  - Pester
  - Gherkin
---

Hace un tiempo leí por ahí que Pester tenía una característica secreta, muy interesante, de la que tenía que hablar en mi blog. Para los que no recuerdan que es Pester, les comparto un enlace a un post en el blog del que hablamos sobre [Pester](https://blog.victorsilva.com.uy/pester-framework/). De lo que quiero hablar es sobre la compatibilidad con las especificaciones de características al estilo Gherkin. Para ser sinceros no tenía mucha idea sobre lo que era Gherkin, pero luego de leer un poco entendí que podría ser muy útil.

### Gherkin



Esta característica le permite definir sus características y especificaciones en una simple sintaxis legible para el negocio. Luego, crea un script de validación que se ejecuta con esa especificación. Le dará resultados de aprobado / reprobado en cada elemento como Pester. Creo que esto es increíble y que más personas necesitan saberlo. No estoy exactamente seguro de cuándo se presentó esta característica, por lo que es posible que deba actualizar Pester para obtenerla.


