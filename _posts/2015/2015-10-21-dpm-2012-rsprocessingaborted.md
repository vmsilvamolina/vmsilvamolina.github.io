---
title: 'DPM 2012 R2 - Error al procesar el informe. (rsProcessingAborted)'
date: 2015-10-21T21:32:53+00:00
author: Victor Silva
layout: post
permalink: /dpm-2012-rsprocessingaborted/
dsq_thread_id:
  - "4480612538"
categories:
  - Data Protection Manager
tags:
  - DPM
  - DPM 2012 R2
  - MSSQL
  - Reporting Services
  - rsProcessingAborted
  - SQL
  - System Center
---
## rsProcessingAborted

Hace tiempo que vengo trabajando con System Center y la verdad es que siempre estamos aprendiendo cosas nuevas y encontrando pequeños trucos o mañas para poder hacer que todo funcione de la mejora manera posible.

Hace unos días, revisando mis mails encontré que el reporte de System Center Data Protection Manager 2012 R2, que tengo programado al mail me llega en blanco. Por ello me decidí a revisar este tema desde la consola y, al intentar ejecutar el **_Recovery Points Status Report_**, me encuentro con el siguiente mensaje:

<img src="https://lh3.googleusercontent.com/9tzr_OccfQfNSCjS1GngdYdK0-OnkrRmOXVBedaNT1n5J1fxTtvVs4TTWCWhgoXYNIIl9vyezRnofWMkBXtZHYKjmbIGcO8yaYWtiwls9jd9yyQ5iW8tj9X9GuM9g-l6Z8Qtl1GbCqH4bO8zmzMp73V21m3o85fJAOiR_LSP9S4S1uaeA2wrg2-FHZceFVs_cu1jsHVYNkPNDwl1txWByLpHx6q6ycHTLONgBeRPx9hdxEAy1hw9acwnheXsRrHjgiQoH6-CSBKxI0ObhBNF27nIKJvjicZvnKrPROLWyYD1yJhABvBdZdwxg51h9D1oLI-JPCxjgrVgThX0EkjinSuaqQ_OcvM20o7eQHY-lXC45Apv8g4FnfKZLPKvU04vLB2BzGsYCqkdb5JweAt2598iEb7-ViYDX4-eH-ioj03D03WbSijX0APUXRamwTujZt4EKXauWKh4HkHWzHY2RzOPRJRr-c6e5tp2EWOdy3utdCvwHGQXi2n-ZqJPkXQjAMk8oxdRBUR9jdKiMHW8edrWXScON7R4hpMqN4lyaP0=w752-h214-no" width="752" height="214" alt="Error al procesar informe. (rsProcessingAborted)" class="alignnone" />

> Error al procesar el informe. (rsProcessingAborted) Error de ejecución de consulta para el conjunto de datos &#8216;Dataset1&#8217;. (rsErrorExecutingCommand) La conversión del tipo de datos nvarchar en datetime produjo un valor fuera del intervalo.

Revisando, encontré que los otros reportes funcionaban.

## Solución

La solución la encontré cambiando el idioma del login en el SQL del **DPMDBReaders$Servidor**

<img src="https://lh3.googleusercontent.com/zGUfhuXj2LfmHF3LvfEAhCEsD3V30tZtafZ5GU3Nz2qQQUXbWu1Q9lLFdYsUnQIBZvCSt7z1OZaSZZ7y7j62t8KAwj-dP-WhHRzmU0YZ8z_UtRZZTf1UDm2qKKUIHRcCXg04SNf8fhG7hZxGCK-pwpLpxYSwGEqA7QsuwFuMk9Hi5qOxXDlcQSsei4JdCwV96byVqYnSsrXeObISKjRSUBfNE0WQ9Fzu9VSEHPqyDGjzkYdW-sXcjQ91zLl5J8mfoeWRoLRKEmZGjU7XYF2hNNa33ViIrrjEOyG23oWGynSFLpHcYdZ--vejMN7arZqGGdAv8tbY2q9JYMiT8hc6B_EVJa_30UgywOcFaBzqpBzbAa1HESsBdR2m3uv4QRnNe0DMPLjOn2FMLClh0x2lLzeK2Q8Iv3GqiI1hKtIRDd7JBDNTtB8pBzSYWi6oViNagjr-EGZHs8uv6FVqlS9qsg857Aq5doZlVdUquGNyIVGlCWZ7VAQp8zERrZu9B_Ob_VWUHTjpzCfftzarEhr-ItBwuXZx3dRWgPUV-3PAJ-k=w438-h448-no" width="438" height="448" alt="Error al procesar informe. (rsProcessingAborted)" class="alignnone" />

En la parte de idioma predeterminado, ahí seleccionamos inglés (en mi caso).

<img src="https://lh3.googleusercontent.com/N9oxhBHmwbQeCe-Jbn1XNSFUOSPC_qXwsqfZ8kDH38x26cF7zhy_SWUSJmtUMy3RZbl2Lu9niWuncZ13uOJg_apHj3zwnpLqwogTxJlSIa2a8dhuJGyacnpNFOX2W5t3_UJBZ8x0XU4C9PL8Qwb3oXeA6vlG49F2HGFdCsuoDdiEpw2LIqK43c9UeF2G1fqAWKPBo9j_0Q4vlsJ50TGs5bs4eky2a1UisQqgScJBeJpdvdLhKa_orVHhwXBU3q99P8HW0K6bDkn29R6KmwqDt8zfRe97yjOGeE_YJZhpzHUgwj9hz0A4ji1UfkP57JsbbmYjM_ZQLzx5wXND1qwB2MC4dSA9MGxB9qClGVzPJwlSpz6zPv5MnN9H6Jt85ful9-__wK-5faw_PX-5dj3DQIn3eRllsiCS_Ui-cVJEQJoqDGun5uvxXAZELhsNGOl8Vi7dHDO_5sLMIbKCcUV9LtMiMVsISUj6wMUsAjiIuJtH752Uwar0_HNC9p8-Tp4-tureL_FEuSnJgIsrlfDJ_OcwvPyTrn5ndBhaPVnhm-0=w704-h634-no" width="704" height="634" alt="Error al procesar informe. (rsProcessingAborted)" class="alignnone" />

Y listo! Ahora quedó funcionando el reporte de DPM.

<img src="https://lh3.googleusercontent.com/l83HutQJ_DBjfLH60cMVpIH_pOFQ351WJCjm22C2nznetOtE5vt-kygjUGKo_h5N12KDqAYMMmDaBMgswyco-wWNDOUReOpKHYQRnV18494JOb0lp33os2AITdHwOjUFnt4vAdjgfnfvVlyG3-8XTkYXkSVgHi6h1NPZqXJXs_3u5D0PwEOkei2qBN9azVoq07MLklh5MXvJnZ5fYfUuAQLEjUHHBE223JwX7K3YYKmu_Hero5-VxVeqLXGAh0OKtioaZ3LsDxLAMl2giJUiY1dWOj3aoEYTBJ0Q92KCplYXoLb4Cb8z9_MsACDwVbsQvSQ5c7VoBCvhmdAxAJKEKy-TDxFGNiCsQQo1TIZnRPgZkvBejlEopfXIHsz10DJsCkmKHIaWJwfMloJTRCsxFNeaByzLC4Cug-WfnWzJ8u1ZTH1xh8P9ZRNZIfWMyE9zr2yiJ-XPeg-NZ5IamuYIZphzhO1akFrO_AIJ3tSI6ctdDipC7C7faYJLu9AEucU13SmYSenPUTrg_cs_3GX8jQ7nLXbQSYFb6JAePlicd1c=w866-h594-no" width="866" height="594" alt="Error al procesar informe. (rsProcessingAborted)" class="alignnone" />

Les comparto un enlace sobre las nuevas funciones de DPM: [enlace](https://technet.microsoft.com/en-us/library/dn296613.aspx)

Saludos,