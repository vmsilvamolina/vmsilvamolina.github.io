---
title: 'OCI Vault: Secrets Management con Terraform'
author: Victor Silva
date: 2026-04-06T09:00:00+00:00
layout: post
permalink: /oci-vault-secrets-management-terraform/
excerpt: "Aprende a gestionar secretos en OCI Vault con Terraform: vault, keys, políticas IAM y el patrón correcto para evitar que tus secretos terminen en el state file."
categories:
  - Oracle
  - Terraform
tags:
  - OCI
  - vault
  - terraform
  - secrets-management
  - iam
  - security
---

Si alguna vez abriste un repositorio de Terraform y encontraste algo como `db_password = "Sup3rS3cr3t!"` hardcodeado en un `.tfvars`, o peor aún, en el propio `main.tf`, sabés exactamente de qué problema estamos hablando. Las credenciales hardcodeadas son una de las vulnerabilidades más comunes en proyectos de infraestructura como código, y el riesgo no termina ahí: incluso cuando se pasan correctamente como variables, ciertos data sources de Terraform escriben el valor del secreto directamente en el state file, que muchas veces vive en un bucket S3 o en un backend remoto sin cifrado adicional.

OCI Vault resuelve este problema de raíz. Es el servicio gestionado de Oracle Cloud para almacenamiento de claves y secretos, respaldado por HSM, con control de acceso granular vía IAM y soporte nativo en el provider de Terraform para OCI. En este post vamos a construir desde cero la infraestructura completa: vault, master encryption key, secretos con reglas de expiración y rotación, políticas IAM para equipos y para workloads mediante Instance Principal, y los comandos de verificación para confirmar que todo funciona antes de confiar en el sistema en producción.

También vamos a ser explícitos sobre el problema del state file y cómo evitarlo, porque es el gotcha más peligroso de trabajar con secretos en Terraform.

## Arquitectura y conceptos clave

OCI Vault tiene una arquitectura de dos planos separados:

- **Management Endpoint (control plane):** se usa para operaciones administrativas — crear vaults, crear keys, crear secretos, rotar versiones. Las llamadas de Terraform van todas aquí.
- **Cryptographic Endpoint (data plane):** se usa para operaciones criptográficas reales — cifrar, descifrar, firmar. Las aplicaciones que necesitan cifrado directo apuntan aquí.

Esta separación no es cosmética. Significa que podés restringir el acceso al data plane de forma independiente al control plane, lo que es relevante para el diseño de políticas IAM.

```
┌─────────────────────────────────────────────────────────────┐
│  OCI Tenancy                                                │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  Compartment: production                              │  │
│  │                                                       │  │
│  │  ┌─────────────────┐    ┌───────────────────────────┐ │  │
│  │  │   OCI Vault     │    │   Compute Instance        │ │  │
│  │  │  ┌───────────┐  │    │   (Instance Principal)    │ │  │
│  │  │  │  MEK Key  │  │    │                           │ │  │
│  │  │  └─────┬─────┘  │    │   oci secrets             │ │  │
│  │  │        │ cifra  │    │   secret-bundle get ───►  │ │  │
│  │  │  ┌─────▼─────┐  │◄───┤                           │ │  │
│  │  │  │  Secrets  │  │    │                           │ │  │
│  │  │  └───────────┘  │    └───────────────────────────┘ │  │
│  │  └─────────────────┘                                  │  │
│  │         ▲                                             │  │
│  │   Management Endpoint   Cryptographic Endpoint        │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### Tipos de vault: una decisión irreversible

Este es el primer punto donde hay que pensar antes de ejecutar `terraform apply`, porque **el tipo de vault no se puede cambiar después de la creación**. Las opciones son:

| Tipo | HSM | Auto-rotación de keys | Costo | Uso recomendado |
|---|---|---|---|---|
| `DEFAULT` | Compartido | No | Menor | Desarrollo, staging |
| `VIRTUAL_PRIVATE` | Dedicado | Sí (GA desde feb 2024) | Mayor | Producción |
| `EXTERNAL` | Externo (BYOK) | No | Variable | Regulaciones estrictas |

Para producción, `VIRTUAL_PRIVATE` es la respuesta correcta: HSM dedicado, soporte para rotación automática de keys, y aislamiento completo. Para entornos de desarrollo y pruebas, `DEFAULT` funciona bien y es considerablemente más económico.

En este post vamos a usar `DEFAULT` para mantener el ejemplo deployable en cualquier tenancy, pero en la sección de best practices vamos a ver cuándo y cómo migrar a `VIRTUAL_PRIVATE`.

### Keys: AES para secretos, RSA/ECDSA para firma

OCI Vault soporta claves simétricas (AES) y asimétricas (RSA, ECDSA). La restricción importante: **solo las keys AES pueden cifrar secretos**. Las keys RSA y ECDSA están para firma y cifrado asimétrico, no para el vault secrets service. Si intentás asociar una key RSA a un secreto, la operación falla.

El gotcha de Terraform que muerde a casi todos la primera vez: **la longitud de la key se especifica en bytes, no en bits**. AES-256 = `length = 32`. Si ponés `length = 256` estás pidiendo una key de 2048 bits, que ni siquiera es un tamaño válido para AES.

## Prerrequisitos

Para seguir este post necesitás:

- OCI CLI instalado y configurado (`oci setup config` o API key en `~/.oci/config`)
- Terraform >= 1.3
- Provider `oracle/oci` >= 8.0
- Un compartment OCID en el que tengas permisos de `manage vaults`, `manage keys` y `manage secret-family`
- El OCID de tu tenancy (para crear Dynamic Groups, que van a nivel de tenancy)

Verificá el acceso antes de empezar:

{% highlight bash %}
# Verificar que el CLI está configurado correctamente
oci iam user get --user-id $(oci iam user list --query 'data[0].id' --raw-output)

# Verificar que tenés acceso al compartment
oci iam compartment get --compartment-id $COMPARTMENT_ID

# Verificar versión del provider en tu proyecto
terraform providers
{% endhighlight %}

## Implementación paso a paso

### Configuración del provider

Empezamos con el bloque de configuración del provider. Nada especial aquí, pero es importante fijar la versión del provider porque el API de OCI Vault cambió entre versiones mayores:

{% highlight hcl %}
terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 8.0"
    }
  }
}

provider "oci" {
  region = var.region
}
{% endhighlight %}

Las variables que vamos a necesitar a lo largo del ejemplo:

{% highlight hcl %}
variable "region" {
  description = "OCI region"
  type        = string
}

variable "compartment_id" {
  description = "OCID del compartment donde se despliegan los recursos"
  type        = string
}

variable "tenancy_ocid" {
  description = "OCID de la tenancy (requerido para Dynamic Groups)"
  type        = string
}

variable "db_password" {
  description = "Database admin password"
  type        = string
  sensitive   = true
}
{% endhighlight %}

### Creando el Vault y la Master Encryption Key

El vault y la key se crean con dos recursos separados. La relación entre ellos es que `oci_kms_key` requiere el `management_endpoint` del vault — no un endpoint hardcodeado, sino la referencia al atributo del recurso del vault. Si no usás `depends_on`, Terraform puede intentar crear la key antes de que el vault esté completamente provisionado, lo que resulta en un error de endpoint no disponible.

{% highlight hcl %}
resource "oci_kms_vault" "app_vault" {
  compartment_id = var.compartment_id
  display_name   = "app-production-vault"
  vault_type     = "DEFAULT"

  freeform_tags = {
    "Environment" = "production"
    "ManagedBy"   = "terraform"
  }
}

resource "oci_kms_key" "app_key" {
  compartment_id      = var.compartment_id
  display_name        = "app-secrets-key"
  management_endpoint = oci_kms_vault.app_vault.management_endpoint

  key_shape {
    algorithm = "AES"
    length    = 32   # 32 bytes = AES-256 (Terraform usa bytes, no bits)
  }

  protection_mode = "HSM"

  depends_on = [oci_kms_vault.app_vault]
}
{% endhighlight %}

Dos decisiones importantes en este bloque:

`protection_mode = "HSM"` significa que el material de la key nunca sale del HSM — OCI no puede exportarla y vos tampoco podés. Si usás `protection_mode = "SOFTWARE"`, la key puede exportarse, lo que amplía la superficie de ataque. Para producción, siempre HSM.

El `depends_on` explícito no es solo buenas prácticas: es necesario. El vault puede tardar algunos segundos en estar operativo después de que la API reporta el recurso como creado, y la key necesita que el management endpoint esté activo para registrarse.

### Creando el secreto con reglas de expiración

Ahora viene el secreto en sí. El content del secreto debe estar en base64 — OCI Vault no acepta texto plano en la API. Terraform tiene la función `base64encode()` que hace exactamente eso:

{% highlight hcl %}
resource "oci_vault_secret" "db_password" {
  compartment_id = var.compartment_id
  vault_id       = oci_kms_vault.app_vault.id
  key_id         = oci_kms_key.app_key.id
  secret_name    = "app-db-password"
  description    = "Database admin password for app-production"

  secret_content {
    content_type = "BASE64"
    content      = base64encode(var.db_password)
    stage        = "CURRENT"
  }

  secret_rules {
    rule_type                                     = "SECRET_EXPIRY_RULE"
    secret_version_expiry_interval                = "P90D"
    is_secret_content_retrieval_blocked_on_expiry = true
  }

  secret_rules {
    rule_type                              = "SECRET_REUSE_RULE"
    is_enforced_on_deleted_secret_versions = true
  }
}
{% endhighlight %}

Los `secret_rules` son el componente que más se pasa por alto en implementaciones básicas y que más diferencia hace en producción:

**SECRET_EXPIRY_RULE** con `P90D` hace que el secreto expire a los 90 días. La parte crítica es `is_secret_content_retrieval_blocked_on_expiry = true`. Por defecto este campo es `false`, lo que significa que aunque el secreto expire, las aplicaciones pueden seguir leyéndolo. Eso hace que la expiración sea decorativa. Con `true`, OCI bloquea el acceso al bundle del secreto una vez expirado, forzando la rotación real.

**SECRET_REUSE_RULE** con `is_enforced_on_deleted_secret_versions = true` impide que se reutilice un valor de secreto previo, incluso en versiones eliminadas. Esto es un control de compliance relevante en entornos regulados.

### Outputs para referencia posterior

Los outputs son importantes tanto para la verificación como para que otros módulos de Terraform puedan referenciar estos recursos:

{% highlight hcl %}
output "vault_id" {
  description = "OCID del vault"
  value       = oci_kms_vault.app_vault.id
}

output "vault_management_endpoint" {
  description = "Management endpoint del vault (requerido para operaciones con keys)"
  value       = oci_kms_vault.app_vault.management_endpoint
}

output "key_id" {
  description = "OCID de la master encryption key"
  value       = oci_kms_key.app_key.id
}

output "db_secret_id" {
  description = "OCID del secreto de base de datos"
  value       = oci_vault_secret.db_password.id
}
{% endhighlight %}

## El problema del state file

Este es el punto donde más proyectos fallan silenciosamente, y vale la pena detenerse.

OCI Vault expone dos data sources para leer secretos en Terraform:

- `oci_vault_secret` — devuelve **solo metadatos** del secreto: OCID, nombre, estado, fechas. El valor del secreto no aparece nunca en el state.
- `oci_secrets_secretbundle` — devuelve el **contenido real** del secreto, decodificado. **Este valor queda almacenado en el state file.**

El state file de Terraform no está cifrado por defecto. Si tu backend es un bucket S3 de AWS o un OCI Object Storage bucket sin cifrado adicional, el secreto está en texto plano en el estado. Cualquier persona con acceso al backend tiene acceso al secreto.

El patrón más seguro es nunca leer el valor de un secreto desde Terraform. Las aplicaciones deben recuperarlo en runtime usando el OCI SDK o la CLI con Instance Principal, no durante el apply. Si necesitás referenciar el OCID del secreto en otro recurso, usá `oci_vault_secret` (metadata only) o referenciá directamente el output del recurso que lo creó.

Si por alguna razón operacional necesitás leer el bundle en Terraform, hay tres mitigaciones:

**1. Backend cifrado con KMS.** Si usás OCI Object Storage como backend de Terraform, podés configurarlo con una clave de OCI Vault para que el state file quede cifrado en reposo. El secreto sigue estando en el state, pero el state está cifrado con una key cuyo acceso controlás con IAM.

**2. Generación automática del secreto.** Algunos tipos de secretos soportan `enable_auto_generation = true` en `oci_vault_secret`. En ese caso, OCI genera el valor internamente y nunca pasa por Terraform — el state solo contiene el OCID, nunca el valor. Esto es ideal para passwords de base de datos que no necesitás conocer tú, solo la aplicación.

**3. Provisioning separado.** El vault y las keys se gestionan con Terraform. Los valores de los secretos se cargan con la CLI o con un pipeline separado con acceso limitado. Terraform gestiona la infraestructura, no los datos sensibles.

La postura recomendada: usá Terraform para crear la infraestructura del vault (vault, key, recurso de secreto con valor placeholder o con auto-generation), y dejá la inyección del valor real para un paso separado fuera del state de Terraform.

## Políticas IAM: control granular de acceso

Este es el componente que más cuesta hacer bien, porque OCI IAM tiene una matriz de verbos que no es obvia.

### La matriz de verbos para secrets

| Verbo | Operación | Quién lo necesita |
|---|---|---|
| `read secret-bundles` | GetSecretBundle — recuperar el valor del secreto | App workloads, instancias de producción |
| `read secrets` | GetSecret — ver metadatos del secreto | Auditoría, pipelines de CI/CD que solo referencian OCIDs |
| `use secrets` | ListSecretVersions y operaciones de rotación | Herramientas de rotación automatizada |
| `manage secret-family` | Control total — crear, eliminar, rotar, modificar | Administradores de seguridad únicamente |

La regla de oro: **nunca concedas `manage secret-family` a una workload de aplicación**. Con ese verbo, la aplicación puede eliminar secretos, crear versiones con valores arbitrarios, y modificar las reglas de expiración. La superficie de compromiso si la aplicación es vulnerada se extiende a todo el vault.

### Políticas para el equipo administrador

{% highlight hcl %}
resource "oci_identity_policy" "vault_admin_policy" {
  compartment_id = var.compartment_id
  name           = "vault-admin-policy"
  description    = "Allow SecurityAdmins group to fully manage vault resources"

  statements = [
    "Allow group SecurityAdmins to manage vaults in compartment id ${var.compartment_id}",
    "Allow group SecurityAdmins to manage keys in compartment id ${var.compartment_id}",
    "Allow group SecurityAdmins to manage secret-family in compartment id ${var.compartment_id}",
  ]
}
{% endhighlight %}

### Dynamic Groups para Instance Principal

Los Dynamic Groups son el mecanismo de OCI para que las instancias de cómputo se autentiquen con IAM sin credenciales estáticas. La instancia asume una identidad basada en su pertenencia al compartment, y esa identidad tiene las políticas que vos le asignás.

Un detalle operativo importante: **los Dynamic Groups se crean a nivel de tenancy, no de compartment**. El `compartment_id` del recurso `oci_identity_dynamic_group` debe ser el OCID de la tenancy, aunque la matching rule filtre instancias de un compartment específico. Si usás el OCID de un compartment hijo, el provider de OCI te va a devolver un error.

{% highlight hcl %}
resource "oci_identity_dynamic_group" "app_instances" {
  compartment_id = var.tenancy_ocid   # Siempre tenancy, no compartment
  name           = "app-compute-instances"
  description    = "Compute instances in the app production compartment"
  matching_rule  = "All {instance.compartment.id = '${var.compartment_id}'}"
}

resource "oci_identity_policy" "instance_secret_policy" {
  compartment_id = var.compartment_id
  name           = "instance-vault-access-policy"
  description    = "Allow app instances to retrieve secrets from vault"

  statements = [
    "Allow dynamic-group app-compute-instances to read secret-bundles in compartment id ${var.compartment_id}",
  ]
}
{% endhighlight %}

Si querés afinar el acceso al nivel de un secreto específico en lugar de todo el compartment, OCI soporta condiciones en los statements de IAM:

{% highlight hcl %}
resource "oci_identity_policy" "instance_specific_secret_policy" {
  compartment_id = var.compartment_id
  name           = "instance-specific-secret-policy"
  description    = "Allow app instances to retrieve only the db password secret"

  statements = [
    "Allow dynamic-group app-compute-instances to read secret-bundles in compartment id ${var.compartment_id} where target.secret.name = 'app-db-password'",
  ]
}
{% endhighlight %}

Esta granularidad es particularmente útil en entornos multi-aplicación donde diferentes servicios necesitan acceder a secretos distintos dentro del mismo compartment.

### Política para el equipo de administración del vault

{% highlight hcl %}
resource "oci_identity_policy" "vault_admin_policy" {
  compartment_id = var.compartment_id
  name           = "vault-admin-policy"
  description    = "Allow SecurityAdmins group to fully manage vault resources"

  statements = [
    "Allow group SecurityAdmins to manage vaults in compartment id ${var.compartment_id}",
    "Allow group SecurityAdmins to manage keys in compartment id ${var.compartment_id}",
    "Allow group SecurityAdmins to manage secret-family in compartment id ${var.compartment_id}",
  ]
}
{% endhighlight %}

## Testing y verificación

Con la infraestructura aplicada, la verificación tiene tres niveles: el estado del vault y la key, la recuperación del secreto desde tu máquina local, y la recuperación desde una instancia usando Instance Principal.

### Verificar estado del vault y la key

{% highlight bash %}
# Verificar que el vault está ACTIVE
oci kms management vault get \
  --vault-id "$(terraform output -raw vault_id)" \
  --query 'data."lifecycle-state"' --raw-output

# Verificar que la key está ENABLED
oci kms management key get \
  --key-id "$(terraform output -raw key_id)" \
  --endpoint "$(terraform output -raw vault_management_endpoint)" \
  --query 'data."lifecycle-state"' --raw-output
{% endhighlight %}

El estado esperado del vault es `ACTIVE`. El estado esperado de la key es `ENABLED`. Si el vault está en `CREATING` o `PROVISIONING`, esperá unos segundos y volvé a consultar.

### Recuperar y verificar el secreto

{% highlight bash %}
# Recuperar el secreto y decodificar el base64
oci secrets secret-bundle get \
  --secret-id "$(terraform output -raw db_secret_id)" \
  --query 'data."secret-bundle-content".content' \
  --raw-output | base64 --decode
{% endhighlight %}

Si el output coincide con el valor que pasaste en `var.db_password`, el ciclo completo funciona: Terraform creó el secreto, OCI lo cifró con la MEK, y la CLI lo recuperó correctamente.

### Verificar el acceso desde una instancia con Instance Principal

Desde una instancia que pertenezca al compartment configurado en la matching rule del Dynamic Group:

{% highlight bash %}
# En la instancia de cómputo — sin credenciales estáticas
oci secrets secret-bundle get \
  --secret-id "ocid1.vaultsecret.oc1.xxx" \
  --auth instance_principal \
  --query 'data."secret-bundle-content".content' --raw-output | base64 --decode
{% endhighlight %}

Si este comando devuelve el valor del secreto sin necesidad de configurar API keys en la instancia, Instance Principal está funcionando correctamente. Si devuelve un error de autorización, verificá que la instancia está en el compartment correcto y que el Dynamic Group tiene la matching rule adecuada.

### Verificar las reglas de expiración

{% highlight bash %}
# Ver metadatos del secreto incluyendo reglas y fecha de expiración
oci vault secret get \
  --secret-id "$(terraform output -raw db_secret_id)" \
  --query 'data.{name:"secret-name", state:"lifecycle-state", rules:"secret-rules"}'
{% endhighlight %}

## Best Practices

**Nunca uses `VIRTUAL_PRIVATE` en la misma apply que los secretos si estás empezando.** El vault `VIRTUAL_PRIVATE` tarda varios minutos en provisionar su HSM dedicado. Si Terraform intenta crear las keys y los secretos antes de que el vault esté completamente operativo, la apply falla. Separar la creación del vault en su propio módulo con un `terraform apply` previo evita este problema.

**Usá `protection_mode = "HSM"` en producción, siempre.** Con `SOFTWARE`, el material de la key puede exportarse. Eso significa que con los permisos adecuados, alguien puede extraer la key del vault. Con `HSM`, el material nunca sale del hardware. El costo adicional de HSM es marginal comparado con el riesgo de una key exportable.

**El tipo de vault es inmutable después de la creación.** Si necesitás migrar de `DEFAULT` a `VIRTUAL_PRIVATE`, el proceso es: crear un nuevo vault `VIRTUAL_PRIVATE`, crear nuevas keys, rotar todos los secretos al nuevo vault, y eliminar el anterior. No hay upgrade in-place. Planificá el tipo de vault antes del primer deploy.

**Activá `is_secret_content_retrieval_blocked_on_expiry = true` en todas las reglas de expiración.** El default es `false`, lo que convierte la expiración en una alerta sin dientes. Con `true`, OCI bloquea el acceso al secreto una vez expirado, forzando la rotación. Sin esto, un secreto "expirado" desde hace seis meses sigue siendo accesible.

**Separar la gestión de claves de la gestión de secretos.** Las keys (MEK) son responsabilidad del equipo de seguridad. Los secretos individuales pueden ser responsabilidad de los equipos de aplicación, con el constraint de que solo pueden usar keys pre-aprobadas. Esto se modela en IAM separando los grupos y las políticas: `SecurityAdmins` tiene `manage keys`, los equipos de aplicación tienen `use keys` y `manage secret-family` en su compartment.

**Usá backends cifrados para el state de Terraform.** Si tu backend de Terraform está en OCI Object Storage, configurá server-side encryption con una key de OCI Vault. Esto no elimina el riesgo de que los secretos estén en el state, pero agrega una capa de protección en reposo con control de acceso auditable.

**Preferí auto-generation o provisioning separado sobre leer secretos en Terraform.** El patrón más seguro es que Terraform no conozca nunca el valor real de los secretos que gestiona. Para passwords de base de datos, habilitá `enable_auto_generation`. Para secretos que necesitás controlar, cargalos con la CLI en un paso separado del pipeline con permisos reducidos.

## Conclusión

Construimos la infraestructura completa de OCI Vault con Terraform: vault con tipo y protection mode correctamente configurados, master encryption key AES-256 en HSM, secretos con reglas de expiración que realmente bloquean el acceso, y las políticas IAM correctas tanto para administradores como para workloads mediante Instance Principal.

El punto más importante no es el código en sí, sino los gotchas que hay que conocer antes de llegar a producción: el tipo de vault es irreversible, la longitud de la key va en bytes, `oci_secrets_secretbundle` escribe el valor en el state, y `is_secret_content_retrieval_blocked_on_expiry` es `false` por defecto. Con eso claro, el resto es configuración.

El próximo paso natural es integrar este vault con pipelines de CI/CD usando OCI DevOps o GitHub Actions con OIDC, para que los pipelines recuperen secretos en runtime sin credenciales estáticas. Eso da para otro post.

Happy scripting!
