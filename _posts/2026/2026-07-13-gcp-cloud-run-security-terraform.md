---
title: 'GCP Cloud Run Security Terraform: IAM, Egress, BinAuthz'
author: Victor Silva
date: 2026-07-13T00:00:00+00:00
layout: post
permalink: /gcp-cloud-run-security-terraform/
excerpt: "Cloud Run no tiene cluster_admission_rules. IAM invoker bindings, Direct VPC egress y Binary Authorization por servicio, con Terraform, sin repetir GKE."
categories:
  - GCP
  - Security
tags:
  - GCP
  - Cloud Run
  - Terraform
  - Binary Authorization
  - IAM
  - VPC
  - Security
  - google_cloud_run_v2_service
  - Direct VPC egress
  - service-to-service authentication
---

Cuando migrás una carga de trabajo de GKE a Cloud Run, es tentador asumir que el hardening que ya construiste se traslada directo. No es así. Cloud Run es un plano de control completamente distinto — no hay cluster, no hay admission webhook, no hay `cluster_admission_rules`. Cada uno de los tres controles que cubrí para GKE en posts anteriores tiene un equivalente en Cloud Run, pero la implementación en Terraform cambia lo suficiente como para que copiar y pegar el HCL de GKE no funcione.

Este post asume que ya conocés el modelo de IAM de GCP de [IAM fundamentals con Terraform](/gcp-iam-fundamentals-terraform/) y el modelo de Binary Authorization — attestors, políticas, `global_policy_evaluation_mode` — de [Binary Authorization para GKE](/gcp-binary-authorization-gke-terraform/). No repito esos fundamentos acá. Cubro la delta específica de Cloud Run: el invoker binding en `google_cloud_run_v2_service_iam_member`, el egress privado a VPC sin un cluster que lo intermedie, y Binary Authorization enganchado a nivel de servicio en lugar de nivel de cluster.

Una aclaración antes de arrancar: el provider `google` tiene dos generaciones de recurso para Cloud Run — `google_cloud_run_service` (v1) y `google_cloud_run_v2_service` (v2). Ninguna está deprecada, pero `vpc_access.network_interfaces` (Direct VPC egress) y el bloque `binary_authorization` completo solo existen en el schema de v2. Todos los ejemplos apuntan a v2; si todavía tenés servicios en v1, migrarlos es prerequisito.

## Arquitectura: los tres controles y dónde viven

A diferencia de GKE, donde IAM, red y Binary Authorization se configuran en recursos separados (cluster, VPC, policy singleton del proyecto), en Cloud Run los tres controles conviven directamente en el recurso `google_cloud_run_v2_service` — con la excepción del invoker binding, que es un recurso IAM aparte adjunto al servicio.

```
google_cloud_run_v2_service
  │
  ├── invoker_iam_disabled / IAM binding externo
  │     └── controla QUIÉN puede invocar (allUsers, SA específica, IAP)
  │
  ├── template.vpc_access
  │     ├── connector (Serverless VPC Access, legacy)
  │     └── network_interfaces (Direct VPC egress, GA desde 2024)
  │           └── controla A DÓNDE puede salir el tráfico
  │
  └── binary_authorization
        ├── use_default (política del proyecto)
        └── policy (platform policy específica de Cloud Run)
              └── controla QUÉ IMAGEN puede correr
```

Ningún cluster de por medio, ningún admission webhook — cada servicio evalúa estos tres controles de forma independiente en el momento del deploy o de la invocación. En GKE, Binary Authorization tiene una política singleton por proyecto con reglas por cluster (`cluster_admission_rules`); en Cloud Run no existe ese concepto — la política se referencia servicio por servicio a través de un *platform policy*, un tipo de recurso distinto al `google_binary_authorization_policy` clásico. Volvemos sobre esto más abajo.

## Prerequisitos

Para seguir el post necesitás:

- Terraform 1.5 o superior
- El provider `google` en versión 5.x o superior (`invoker_iam_disabled` y `network_interfaces` son campos relativamente recientes)
- Un proyecto de GCP con billing habilitado
- Las siguientes APIs habilitadas: `run.googleapis.com`, `vpcaccess.googleapis.com`, `binaryauthorization.googleapis.com`, `containeranalysis.googleapis.com`
- `gcloud` CLI autenticado con un principal que tenga `roles/run.admin` y `roles/vpcaccess.admin` sobre el proyecto destino
- Si vas a completar la sección de Binary Authorization, un attestor y una KMS key ya existentes — ver el post de GKE si no los tenés configurados

Habilitá las APIs:

{% highlight bash %}
gcloud services enable \
  run.googleapis.com \
  vpcaccess.googleapis.com \
  binaryauthorization.googleapis.com \
  containeranalysis.googleapis.com \
  --project="${PROJECT_ID}"
{% endhighlight %}

## IAM Invoker Bindings

En Cloud Run, la pregunta de "quién puede llamar a este servicio" se resuelve con el rol `roles/run.invoker`, aplicado sobre el servicio con `google_cloud_run_v2_service_iam_member` (o `_binding` si necesitás el modo autoritativo — la misma distinción `member` vs `binding` que ya vimos para IAM de proyecto aplica acá).

### El patrón que hay que evitar: `allUsers` vía IAM binding

Históricamente, la forma de hacer público un servicio de Cloud Run era otorgar el invoker a `allUsers`:

{% highlight hcl %}
resource "google_cloud_run_v2_service_iam_member" "public_invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.api.name

  role   = "roles/run.invoker"
  member = "allUsers"
}
{% endhighlight %}

Esto funciona, pero tiene un problema de intención: un binding de IAM que otorga un rol a `allUsers` se ve idéntico en el Terraform plan a cualquier otro binding, y es fácil que pase desapercibido en un review — nada en el diff grita "este servicio ahora es público en Internet".

### El patrón recomendado: `invoker_iam_disabled`

La alternativa actual, y la que Google recomienda cuando el objetivo es realmente hacer público un servicio, es un campo booleano directo en el recurso del servicio:

{% highlight hcl %}
resource "google_cloud_run_v2_service" "public_api" {
  name     = "public-api"
  location = var.region
  project  = var.project_id

  template {
    containers {
      image = "us-docker.pkg.dev/${var.project_id}/app-repo/public-api:latest"
    }
  }

  # Deshabilita la verificación de IAM para run.routes.invoke.
  # Cualquier caller sin necesidad de credenciales puede invocar el servicio.
  invoker_iam_disabled = true
}
{% endhighlight %}

La ventaja no es funcional — el resultado neto de acceso público es el mismo que con `allUsers` — sino de legibilidad e intención explícita: un revisor que ve `invoker_iam_disabled = true` en el bloque del servicio entiende de inmediato que es público, sin cruzar referencias con un recurso IAM en otro archivo. Preferí este campo sobre `allUsers` para cualquier servicio nuevo que deba ser público.

### El patrón por defecto: invoker service-to-service con least privilege

La gran mayoría de los servicios de Cloud Run en una arquitectura de microservicios no deberían ser públicos. El patrón correcto es: el servicio invocado otorga `roles/run.invoker` únicamente a la service account del servicio que lo llama, y el llamador se autentica con un ID token OIDC cuya audiencia es la URL del callee.

{% highlight hcl %}
# Service account dedicada para el servicio que hace la llamada
resource "google_service_account" "caller_sa" {
  account_id   = "orders-service-sa"
  display_name = "Orders service — caller identity"
  project      = var.project_id
}

# Servicio callee: recibe llamadas del servicio de orders
resource "google_cloud_run_v2_service" "inventory" {
  name     = "inventory-service"
  location = var.region
  project  = var.project_id

  template {
    service_account = google_service_account.inventory_sa.email

    containers {
      image = "us-docker.pkg.dev/${var.project_id}/app-repo/inventory:latest"
    }
  }
  # Sin invoker_iam_disabled: el servicio requiere IAM para cualquier invocación
}

# Invoker binding scoped a UNA SOLA service account, no allUsers
resource "google_cloud_run_v2_service_iam_member" "inventory_invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.inventory.name

  role   = "roles/run.invoker"
  member = google_service_account.caller_sa.member
}

# Servicio caller: corre con la SA que tiene el invoker en inventory
resource "google_cloud_run_v2_service" "orders" {
  name     = "orders-service"
  location = var.region
  project  = var.project_id

  template {
    service_account = google_service_account.caller_sa.email

    containers {
      image = "us-docker.pkg.dev/${var.project_id}/app-repo/orders:latest"

      env {
        name  = "INVENTORY_SERVICE_URL"
        value = google_cloud_run_v2_service.inventory.uri
      }
    }
  }
}
{% endhighlight %}

Con esta configuración, `inventory-service` solo acepta invocaciones autenticadas con un ID token cuyo `sub` corresponde a `orders-service-sa`. En el código del servicio `orders`, la obtención del ID token con la audiencia correcta se hace con la librería de metadata server de GCP — por ejemplo, en Python:

{% highlight python %}
import google.auth.transport.requests
import google.oauth2.id_token

def get_id_token(audience: str) -> str:
    auth_req = google.auth.transport.requests.Request()
    return google.oauth2.id_token.fetch_id_token(auth_req, audience)

# audience debe ser exactamente la URL del servicio callee
token = get_id_token("https://inventory-service-xyz.a.run.app")
headers = {"Authorization": f"Bearer {token}"}
{% endhighlight %}

Nótese que `audience` tiene que coincidir exactamente con la URL del servicio, no con un dominio custom ni una URL parcial. Si usás dominios custom, fetch el token con la URL `*.a.run.app` igual.

Este es el mismo principio de identidad federada sin claves estáticas que cubrí en [Workload Identity Federation con GitHub Actions](/gcp-workload-identity-federation-github-actions/), aplicado ahora entre dos servicios de Cloud Run en lugar de entre GitHub Actions y GCP.

Un detalle operativo para jobs batch o workers de larga duración: el ID token expira aproximadamente una hora después de emitido. Cachearlo para toda la vida del job es un error común que se manifiesta como 401 intermitentes horas después de que el proceso arrancó — refrescalo proactivamente antes de cada llamada en vez de asumir que el token inicial sigue siendo válido.

Este es el patrón por defecto para toda comunicación service-to-service. `allUsers` y `invoker_iam_disabled` son la excepción reservada para endpoints que genuinamente necesitan ser públicos.

### Nota sobre IAP como alternativa

Para acceso humano — no service-to-service — a un servicio que necesita autenticación pero no es parte de tu malla de microservicios interna (un panel de administración, por ejemplo), Identity-Aware Proxy es más apropiado que un invoker binding manual. IAP se coloca delante del servicio y valida la identidad del usuario contra Google Workspace o Cloud Identity antes de que la request llegue a Cloud Run, con soporte para condiciones de contexto. El invoker binding con SA dedicada resuelve bien el caso service-to-service; para usuarios humanos con SSO corporativo, IAP resuelve un problema distinto.

Un detalle que ahorra tiempo de debugging: IAP inyecta su propio header `X-Serverless-Authorization` con el token que ya validó. Si la request llega con ambos headers presentes — el `Authorization: Bearer` propio y el `X-Serverless-Authorization` de IAP — Cloud Run solo evalúa este último. Un caller que arma su `Authorization` header sin saber que hay IAP de por medio se va a encontrar con 403 sin relación aparente con el token que mandó.

## Egress Privado a VPC

Un servicio de Cloud Run, por defecto, no tiene ninguna conexión a tu VPC — todo el tráfico saliente va directo a Internet. Si necesita hablar con una instancia de Cloud SQL con IP privada, un servicio interno en GKE, o cualquier recurso sin IP pública, hace falta uno de dos mecanismos. Adelanto la conclusión porque suele simplificarse de más: no es que uno sea "el bueno" y el otro "el legacy a migrar apenas se pueda" — es un tradeoff real entre costo/throughput y latencia de cold start, y cuál gana depende del servicio.

En `vpc_access`, los campos `connector` y `network_interfaces` son mutuamente excluyentes — uno u otro, nunca ambos. Vale decirlo explícitamente porque algunas versiones del provider no validan esta restricción en el `plan` (issue [#26469](https://github.com/hashicorp/terraform-provider-google/issues/26469)), así que no asumas que Terraform te va a frenar si mezclás los dos bloques por error.

### Serverless VPC Access Connector (el mecanismo legacy)

Este fue durante años el único camino. Requiere desplegar un recurso `google_vpc_access_connector` que corre como su propia infraestructura administrada — con throughput e instancias propias que facturan aparte — y que necesita una subred `/28` dedicada:

{% highlight hcl %}
resource "google_vpc_access_connector" "connector" {
  name          = "run-connector"
  project       = var.project_id
  region        = var.region
  ip_cidr_range = "10.8.0.0/28"
  network       = google_compute_network.main.name

  min_instances = 2
  max_instances = 3
  machine_type  = "e2-micro"
}

resource "google_cloud_run_v2_service" "legacy_egress" {
  name     = "legacy-egress-service"
  location = var.region
  project  = var.project_id

  template {
    vpc_access {
      connector = google_vpc_access_connector.connector.id
      egress    = "PRIVATE_RANGES_ONLY"
    }

    containers {
      image = "us-docker.pkg.dev/${var.project_id}/app-repo/legacy:latest"
    }
  }
}
{% endhighlight %}

El connector sigue siendo válido y soportado, pero tiene dos costos que Direct VPC egress elimina: el costo de las instancias del connector en sí (independiente del costo de tu servicio de Cloud Run), y un techo de throughput más bajo que el que podés obtener con una interfaz de red directa.

### Direct VPC Egress (GA desde 2024, sin connector)

Direct VPC egress conecta el servicio directamente a tu VPC sin un connector intermedio. Se configura con el bloque `network_interfaces` dentro de `vpc_access`, directamente sobre `google_cloud_run_v2_service`:

{% highlight hcl %}
resource "google_cloud_run_v2_service" "direct_egress" {
  name     = "internal-api"
  location = var.region
  project  = var.project_id

  template {
    vpc_access {
      network_interfaces {
        network    = google_compute_network.main.id
        subnetwork = google_compute_subnetwork.private.id
        tags       = ["cloud-run-egress"]
      }

      egress = "PRIVATE_RANGES_ONLY"
    }

    containers {
      image = "us-docker.pkg.dev/${var.project_id}/app-repo/internal-api:latest"

      env {
        name  = "CLOUDSQL_PRIVATE_IP"
        value = google_sql_database_instance.main.private_ip_address
      }
    }
  }
}
{% endhighlight %}

Sin connector, sin subred `/28` dedicada, menor costo y un techo de throughput más alto. La limitación real es el dimensionamiento de la subred: Cloud Run reserva un bloque de 16 IPs por instancia (no una IP suelta) dentro de la subred indicada, así que una subred subdimensionada se agota rápido apenas el servicio escala. La subred para `network_interfaces` tiene que ser `/26` o más grande, dimensionada pensando en el máximo de instancias concurrentes en un pico, no en el promedio.

Ahora la parte que sí es un tradeoff real: la combinación de Direct VPC egress con Cloud NAT tiene una regresión de latencia de cold start documentada por Google — más de 30 segundos adicionales en esa combinación específica. Si el servicio escala a cero entre requests y la latencia del primer request importa (una API sincrónica invocada por un usuario), esos 30 segundos pueden ser inaceptables aunque el resto del argumento a favor de Direct VPC egress siga siendo válido. En ese escenario, el connector de Serverless VPC Access combinado con Cloud NAT puede seguir siendo la opción correcta, precisamente porque no sufre esa regresión.

La recomendación práctica no es "usá Direct VPC egress siempre": es evaluar cold-start sensitivity antes de elegir. Para servicios con `min_instances > 0` o workers asincrónicos donde el cold start no es visible para un usuario esperando respuesta, Direct VPC egress sigue siendo razonable por defecto. Para servicios sincrónicos que escalan a cero y donde la latencia del primer request es parte del SLA, medí el impacto antes de descartar el connector.

### El campo `egress`: `PRIVATE_RANGES_ONLY` vs `ALL_TRAFFIC`

En ambos mecanismos, el campo `egress` decide qué tráfico efectivamente pasa por la VPC:

- **`PRIVATE_RANGES_ONLY`** (default) — solo el tráfico con destino a rangos RFC1918 (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16) se enruta por la VPC. Todo lo demás — llamadas a APIs de Google, a terceros en Internet — sigue saliendo directo, sin pasar por tu VPC.
- **`ALL_TRAFFIC`** — absolutamente todo el tráfico saliente del servicio se enruta por la VPC, incluyendo destinos públicos de Internet.

Si tu objetivo es solo alcanzar Cloud SQL o un servicio interno con IP privada, `PRIVATE_RANGES_ONLY` es lo que necesitás y no hay razón para forzar más tráfico del necesario por la VPC. Pero si tu objetivo es un lockdown completo — por ejemplo, que el servicio no tenga salida directa a Internet bajo ninguna circunstancia, y que todo el tráfico de egress pase por una inspección centralizada — necesitás `ALL_TRAFFIC`. Si además ese lockdown tiene que incluir un perímetro de datos a nivel de proyecto (no solo egress de red), es el mismo caso de uso que cubrí en [VPC Service Controls con Terraform](/gcp-vpc-service-controls-terraform/): `ALL_TRAFFIC` controla por dónde sale el tráfico, VPC-SC controla qué APIs y datos son alcanzables una vez que sale — son controles complementarios, no alternativos.

El detalle que se pasa por alto con frecuencia: si usás `ALL_TRAFFIC`, Cloud Run ya no tiene ninguna ruta directa a Internet — todo el tráfico, incluyendo llamadas legítimas a APIs externas, pasa por la VPC. Sin un Cloud NAT configurado en esa VPC/subred, esas llamadas van a fallar porque no hay forma de traducir las IPs privadas a una IP pública de salida. Si vas a usar `ALL_TRAFFIC`, el Cloud NAT no es opcional:

{% highlight hcl %}
resource "google_compute_router" "nat_router" {
  name    = "cloud-run-nat-router"
  region  = var.region
  network = google_compute_network.main.id
  project = var.project_id
}

resource "google_compute_router_nat" "nat" {
  name                               = "cloud-run-nat"
  router                             = google_compute_router.nat_router.name
  region                             = var.region
  project                            = var.project_id
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

resource "google_cloud_run_v2_service" "locked_down" {
  name     = "locked-down-service"
  location = var.region
  project  = var.project_id

  template {
    vpc_access {
      network_interfaces {
        network    = google_compute_network.main.id
        subnetwork = google_compute_subnetwork.private.id
      }

      egress = "ALL_TRAFFIC"
    }

    containers {
      image = "us-docker.pkg.dev/${var.project_id}/app-repo/locked-down:latest"
    }
  }

  depends_on = [google_compute_router_nat.nat]
}
{% endhighlight %}

## Binary Authorization para Cloud Run

En el post de GKE, Binary Authorization se configuraba con un `google_binary_authorization_policy` singleton de proyecto, con `cluster_admission_rules` diferenciadas por cluster. Cloud Run no tiene ese concepto — no hay cluster, no hay admission webhook de Kubernetes. En su lugar, la enforcement se configura directamente en el bloque `binary_authorization` dentro de `google_cloud_run_v2_service`, servicio por servicio.

{% highlight hcl %}
# La platform policy "cloud-run-strict" se crea fuera de Terraform (ver nota
# más abajo sobre el gap de recursos) y se referencia acá por su path completo.
resource "google_cloud_run_v2_service" "attested_service" {
  name     = "attested-service"
  location = var.region
  project  = var.project_id

  template {
    containers {
      image = "us-docker.pkg.dev/${var.project_id}/app-repo/attested-service@sha256:abc123..."
    }
  }

  binary_authorization {
    policy = "projects/${var.project_id}/platforms/cloudRun/cloud-run-strict"
  }
}
{% endhighlight %}

El campo `policy` no apunta al `google_binary_authorization_policy` clásico de GKE — apunta a una *platform policy*, un tipo de recurso distinto con su propio path: `projects/{project}/platforms/cloudRun/{policy_name}`. Esa es la diferencia estructural más importante: en GKE hay una política de proyecto con reglas por cluster; en Cloud Run cada servicio referencia su propia platform policy, y no existe equivalente de `cluster_admission_rules` porque no hay cluster que admita nada — la verificación ocurre en el deploy del servicio, no en un admission webhook continuo.

Un gap concreto si gestionás todo desde Terraform: al día de hoy el provider `google` no tiene un recurso dedicado para *crear* una platform policy no-default — solo el campo de referencia (`policy`) que consume un path ya existente. Si necesitás una policy custom, hoy la creás fuera de Terraform (con `gcloud` o la API) y la referenciás como recurso externo. Vale vigilar el changelog del provider; es el tipo de gap que suele cerrarse en una versión posterior.

### Usar la política default del proyecto

Si preferís no gestionar platform policies individuales por servicio, el campo `use_default` reutiliza la política de Binary Authorization del proyecto (la misma que configurarías para GKE con `google_binary_authorization_policy`, evaluada acá contra Cloud Run):

{% highlight hcl %}
resource "google_cloud_run_v2_service" "default_policy_service" {
  name     = "default-policy-service"
  location = var.region
  project  = var.project_id

  template {
    containers {
      image = "us-docker.pkg.dev/${var.project_id}/app-repo/svc@sha256:def456..."
    }
  }

  binary_authorization {
    use_default = true
  }
}
{% endhighlight %}

Este es el punto de partida razonable cuando ya tenés un attestor y una política de proyecto funcionando para GKE y querés extender esa misma cobertura a Cloud Run sin duplicar la infraestructura de attestation.

Un error de configuración común y silencioso: habilitar la API `binaryauthorization.googleapis.com` no hace nada por sí sola. Sin un bloque `binary_authorization` que referencie `use_default` o una `policy` explícita no hay enforcement — y si la política de proyecto está en modo default (`ALWAYS_ALLOW`, sin `require_attestations_by`), tampoco hay nada que bloquear aunque el bloque esté presente. Verificá siempre las dos cosas: que el servicio referencia la policy, y que esa policy efectivamente exige attestation.

### Breakglass en Cloud Run: auditado, no un bypass silencioso

Igual que en GKE, existe una vía de emergencia — pero acá se expresa como un campo de string, no como un label de pod:

{% highlight hcl %}
resource "google_cloud_run_v2_service" "emergency_deploy" {
  name     = "payment-processor"
  location = var.region
  project  = var.project_id

  template {
    containers {
      image = "us-docker.pkg.dev/${var.project_id}/app-repo/payment-processor@sha256:unattested..."
    }
  }

  binary_authorization {
    use_default              = true
    breakglass_justification = "INC-4821: hotfix crítico de billing, revisión post-incidente programada para el 2026-07-14"
  }
}
{% endhighlight %}

Configurar `breakglass_justification` con cualquier valor no vacío hace que el deploy proceda aunque la imagen no cumpla la política. La justificación queda registrada en Cloud Audit Logs junto con el deploy, sin excepción — es un mecanismo auditado para emergencias reales, no un interruptor que se deja prendido.

Hay un footgun específico de IaC que no existe cuando el breakglass se usa como flag puntual de `gcloud`: un `gcloud run services update --breakglass=...` a mano es un bypass de una sola vez, pero si `breakglass_justification` queda seteado dentro del recurso de Terraform mismo — copiado de otro módulo durante un incidente y nunca limpiado — cada `terraform apply` subsiguiente vuelve a saltarse Binary Authorization, indefinidamente. Es la diferencia entre abrir la puerta una vez y dejarla trabada abierta. Tratá cualquier `breakglass_justification` en un `.tf` como bandera roja en code review — `grep -r breakglass_justification` al revisar diffs de módulos de Cloud Run.

### Backstop a nivel de organización

Un problema práctico de este modelo por-servicio es que alcanza con que un equipo se olvide de adjuntar el bloque `binary_authorization` a un servicio nuevo para que ese servicio quede completamente fuera de la enforcement — a diferencia de GKE, donde el cluster entero enforce la política del proyecto de una sola vez. Para cerrar ese gap, existe una constraint de org policy que puede exigir que Binary Authorization esté habilitado en todos los despliegues de Cloud Run de la organización o carpeta:

{% highlight hcl %}
resource "google_organization_policy" "require_binauthz_cloud_run" {
  org_id     = var.org_id
  constraint = "constraints/run.requireBinaryAuthorization"

  boolean_policy {
    enforced = true
  }
}
{% endhighlight %}

Con esta constraint activa, un servicio sin bloque `binary_authorization` simplemente no se despliega — el olvido de un equipo pasa de agujero silencioso a error de deploy explícito.

## Testing y Validación

### Invoker binding

{% highlight bash %}
# Principals con roles/run.invoker
gcloud run services get-iam-policy inventory-service \
  --region="${REGION}" --project="${PROJECT_ID}" \
  --format="table(bindings.role, bindings.members)"

# Sin token: esperado 403
curl -s -o /dev/null -w "%{http_code}\n" \
  "$(gcloud run services describe inventory-service --region="${REGION}" --format='value(status.url)')"

# Con ID token de la SA autorizada: esperado 200
TOKEN=$(gcloud auth print-identity-token \
  --impersonate-service-account=orders-service-sa@${PROJECT_ID}.iam.gserviceaccount.com \
  --audiences="$(gcloud run services describe inventory-service --region="${REGION}" --format='value(status.url)')")
curl -s -o /dev/null -w "%{http_code}\n" \
  -H "Authorization: Bearer ${TOKEN}" \
  "$(gcloud run services describe inventory-service --region="${REGION}" --format='value(status.url)')"
{% endhighlight %}

### Egress

{% highlight bash %}
# Confirmá el vpc_access activo (networkInterfaces o connector) y el modo de egress
gcloud run services describe internal-api \
  --region="${REGION}" --project="${PROJECT_ID}" \
  --format="yaml(spec.template.spec.vpcAccess)"

# Con ALL_TRAFFIC, confirmá que el Cloud NAT está capturando tráfico
gcloud compute routers get-nat-mapping-info cloud-run-nat-router \
  --router="cloud-run-nat-router" --region="${REGION}" --project="${PROJECT_ID}"
{% endhighlight %}

### Binary Authorization

{% highlight bash %}
# Imagen sin attestation contra una platform policy en modo enforce: debería fallar el deploy
gcloud run deploy attested-service \
  --image="us-docker.pkg.dev/${PROJECT_ID}/app-repo/attested-service:unattested-tag" \
  --region="${REGION}" --project="${PROJECT_ID}"

# Repetí con una imagen atestada (mismo pipeline de Cloud Build del post de GKE): debería avanzar

# Auditá uso de breakglass periódicamente
gcloud logging read \
  'resource.type="cloud_run_revision" AND protoPayload.request.breakglassJustification!=""' \
  --freshness=30d --project="${PROJECT_ID}"
{% endhighlight %}

## Buenas Prácticas

**Nunca compartas una service account entre el caller y el callee.** Cada servicio debería tener su propia SA, con el invoker otorgado explícitamente a la SA del servicio que realmente necesita llamarlo — extensión directa del least privilege por workload al nivel de invocación entre servicios.

**Elegí entre Direct VPC egress y el connector según sensibilidad a cold start, no por costo únicamente.** Direct VPC egress gana en costo y throughput, pero sumado a Cloud NAT agrega más de 30 segundos de cold start. Para servicios sincrónicos que escalan a cero, medí antes de asumir que Direct VPC egress es la opción correcta.

**Dimensioná la subred de Direct VPC egress en `/26` o más, pensando en instancias concurrentes máximas.** Cloud Run reserva un bloque de 16 IPs por instancia; una subred subdimensionada se agota rápido y falla justo en los picos de escala.

**Usá `ALL_TRAFFIC` solo con Cloud NAT desplegado y verificado.** Sin NAT no es un error sutil — es un servicio que deja de poder llamar a cualquier endpoint público, incluyendo APIs de Google.

**Reforzá el hardening por-servicio con la org policy constraint.** Porque Cloud Run no tiene un mecanismo equivalente a "todo el cluster enforcea la policy del proyecto", `constraints/run.requireBinaryAuthorization` es la única forma de garantizar que ningún servicio nuevo se despliegue sin pasar por Binary Authorization, sin depender de que cada equipo se acuerde de agregarlo manualmente.

**Auditá `breakglass_justification` con la misma disciplina que el label de breakglass en GKE.** Es texto libre, no un mecanismo con aprobación — cualquiera con permisos de deploy puede escribirlo. El control real está en la revisión posterior de los audit logs, y en buscarlo (`grep -r breakglass_justification`) en cada review de un módulo de Cloud Run.

## Conclusión

Cloud Run comparte los mismos tres pilares de seguridad que GKE — control de acceso, aislamiento de red y verificación de procedencia de imágenes — pero cada uno se expresa distinto porque no hay cluster de por medio. El invoker binding reemplaza al RBAC de Kubernetes, Direct VPC egress reemplaza a la configuración de red del cluster, y la platform policy reemplaza a `cluster_admission_rules`. Ninguno requiere gestionar un plano de control adicional — todo vive en `google_cloud_run_v2_service` o en un recurso IAM adjunto, lo que hace este hardening más liviano de mantener que su equivalente en GKE, a cambio de algo menos de granularidad por-workload.

Si ya tenés el attestor y la infraestructura de KMS de [Binary Authorization para GKE](/gcp-binary-authorization-gke-terraform/) funcionando, extenderla a Cloud Run es prácticamente gratis — la platform policy es el único recurso nuevo. Y si todavía no revisaste los fundamentos de IAM de proyecto, [ese post](/gcp-iam-fundamentals-terraform/) sigue siendo la base sobre la que se apoya todo lo que mostré acá, incluyendo el `google_service_account.member` que usé para scopear cada invoker binding.

Happy scripting!
