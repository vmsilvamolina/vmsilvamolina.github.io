---
title: 'AWS IAM rol con Terraform'
author: Victor Silva
date: 2022-08-27T01:03:56+00:00
layout: post
permalink: /IAM-rol-AWS-terraform/
excerpt: 'En esta entrada, vamos a ver tres formas de crear una política y un rol de IAM en la nube de AWS utilizando Terraform. También proporciona una forma sencilla de conectar la política seleccionada a un rol de IAM. Supongo que ya conoces un poco de terraform y la nube de AWS, por lo que no explicaré los conceptos básicos.'
categories:
  - AWS
  - IAM
  - Terraform
tags:
  - AWS
  - IAM
  - Terraform
---

En esta entrada, vamos a ver tres formas de crear una política y un rol de IAM en AWS utilizando Terraform. También veremos una forma sencilla de conectar la política seleccionada a un rol de IAM en particular. Supongo que ya conoces un poco de Terraform y la nube de AWS, por lo que no explicaré los conceptos básicos.

## Método 1: `aws_iam_policy_document`

La primera forma es crear un elemento **data** en Terraform `aws_iam_policy_document`. Esta forma de implementación es probablemente la más común en versiones anteriores de TF. A continuación, describiré en qué consiste el archivo completo, que le permite crear una política, un rol y combinar estos dos recursos. A menudo agrupo diferentes tipos de recursos en archivos para que me sea más fácil encontrarlos en el proyecto. En este ejemplo, presento el contenido del archivo **iam.tf**.

### data `aws_iam_policy_document`

De esta forma, creo un elemento de datos y en él especifico cómo aws_iam_policy_documentdebe ser la política de IAM . Este es un elemento clave y vale la pena dedicarle más tiempo. Recomiendo otorgar siempre solo los permisos mínimos necesarios. Desafortunadamente, esto hace que el rol sea menos universal , pero es un precio que, en mi opinión, vale la pena pagar, aumentando así significativamente la seguridad .

Ni siquiera estoy hablando de una acción deliberada aquí, pero si, por ejemplo, damos acceso completo a todos los S3 en lugar de uno y nuestra función no funciona como se esperaba, puede tener consecuencias muy graves.

Buen consejo: no haga que todos los usuarios sean administradores😉

En tal documento, por supuesto, puedo definir varias expresiones . En el siguiente ejemplo, permito:

    GetObject y DeleteObject en la carpeta de origen de S3 Bucket especificada,
    Fuente S3 ListBucket y el contenido de su carpeta única,
    PutObjects en una sola carpeta de destino de S3

### resource `aws_iam_policy`

Luego creo una política aws_iam_policyy agrego la creada previamente aws_iam_policy_document.
recursoaws_iam_role

El siguiente paso es crear un rol de IAM aws_iam_role. Posteriormente, el rol se puede asignar a la máquina EC2, la función Lambda, etc.

### resource `aws_iam_role_policy_attachment`

El último paso es agregar la política al rol de IAM `aws_iam_role_policy_attachment`. Si quisiera agregar más políticas de IAM a un rol, crearía más recursos aws_iam_role_policy_attachment. En ellos doy el mismo nombre de rol y el siguiente nombre de la política que quiero agregar.

{% highlight terraform%}
data "aws_iam_policy_document" "S3_automation_move_objects" {
  statement {
    sid = "allowS3"
    actions = [
      "s3:GetObject",
      "s3:DeleteObject",
    ]
    resources = [
      "arn:aws:s3:::test-ndgegy4364gdu-source-bucket/images/*"
    ]
  }

  statement {
    sid = "allowListBucket"
    actions = [
      "s3:ListBucket",
    ]
    resources = [
      "arn:aws:s3:::test-ndgegy4364gdu-source-bucket",
      "arn:aws:s3:::test-ndgegy4364gdu-source-bucket/images/*"
    ]
  }

  statement {
    sid = "putObject"
    actions = [
      "s3:PutObject",
    ]
    resources = [
      "arn:aws:s3:::test-ndgegy4364gdu-destination-bucket/images/*"
    ]
  }

}

resource "aws_iam_policy" "S3_automation_move_objects" {
  name        = "S3_automation_move_objects"
  description = "test - access to source and destination S3 bucket"
  path        = "/"

  policy = data.aws_iam_policy_document.S3_automation_move_objects.json
}

resource "aws_iam_role" "S3_automation_move_objects" {
  name        = "S3_automation_move_objects"
  description = "test - access to source and destination S3 bucket"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "S3_automation_move_objects" {
  role       = aws_iam_role.S3_automation_move_objects.name
  policy_arn = aws_iam_policy.S3_automation_move_objects.arn
}
{% endhighlight %}

# Método 2: función jsonencode

Esta vez, para crear una política de IAM en Terraform, no utilizo elementos adicionales. Los permisos se definen directamente en aws_iam_policy. Estoy usando una función jsonencode especial aquí . Esta función asigna valores de Terraform a valores JSON . En este caso tampoco tomé el camino fácil y definí algunas expresiones. Esto lo hace más como una solución real.

La creación aws_iam_roley adición de una política de IAM a un rol de IAM se realiza de la misma manera que en el primer método, es decir, utilizando aws_iam_role_policy_attachment.

{% highlight terraform%}
resource "aws_iam_policy" "S3_automation_move_objects" {
  name        = "S3_automation_move_objects"
  description = "test - access to source and destination S3 bucket"
  path        = "/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
			"s3:GetObject",
			"s3:DeleteObject",
        ]
        Effect   = "Allow"
        Resource = "arn:aws:s3:::test-ndgegy4364gdu-source-bucket1/images/*"
      },
      {
        Action = [
			"s3:ListBucket",
        ]
        Effect   = "Allow"
        Resource = [
			"arn:aws:s3:::test-ndgegy4364gdu-source-bucket1",
			"arn:aws:s3:::test-ndgegy4364gdu-source-bucket1/images/*"
		]
      },
      {
        Action = [
			"s3:putObject",
        ]
        Effect   = "Allow"
        Resource = "arn:aws:s3:::test-ndgegy4364gdu-destination-bucket1/images/*"
      },
    ]
  })
}

resource "aws_iam_role" "S3_automation_move_objects" {
  name        = "S3_automation_move_objects"
  description = "test - access to source and destination S3 bucket"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "S3_automation_move_objects" {
  role       = aws_iam_role.S3_automation_move_objects.name
  policy_arn = aws_iam_policy.S3_automation_move_objects.arn
}
{% endhighlight %}

# Método 3 - EOF

También puedes usar el tercer método, que es muy similar al del punto 2. De nuevo, no define elementos adicionales. Sin embargo, en lugar de usar la función, pegamos el contenido del archivo JSON .

Si tiene políticas de IAM definidas en formato JSON , puede agregar el contenido de dicha política al recurso sin ningún cambio aws_iam_policy.

Crear un rol de IAM en Terraform es igual que en las dos formas anteriores. Esta vez también combino la política con el rol usando aws_iam_role_policy_attachment.

{% highlight terraform%}
resource "aws_iam_policy" "S3_automation_move_objects" {
  name        = "S3_automation_move_objects"
  description = "test - access to source and destination S3 bucket"
  path        = "/"

  policy = <<EOF
{
	"Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "s3:GetObject",
                "s3:DeleteObject"
            ],
            "Effect": "Allow",
            "Resource": "arn:aws:s3:::test-ndgegy4364gdu-source-bucket1/images/*"
        },
        {
            "Action": [
                "s3:ListBucket"
            ],
            "Effect": "Allow",
            "Resource": [
                "arn:aws:s3:::test-ndgegy4364gdu-source-bucket1",
                "arn:aws:s3:::test-ndgegy4364gdu-source-bucket1/images/*"
            ]
        },
        {
            "Action": [
                "s3:putObject"
            ],
            "Effect": "Allow",
            "Resource": "arn:aws:s3:::test-ndgegy4364gdu-destination-bucket1/images/*"
        }
    ],
    "Version": "2012-10-17"
}
EOF
}

resource "aws_iam_role" "S3_automation_move_objects" {
  name        = "S3_automation_move_objects"
  description = "test - access to source and destination S3 bucket"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "S3_automation_move_objects" {
  role       = aws_iam_role.S3_automation_move_objects.name
  policy_arn = aws_iam_policy.S3_automation_move_objects.arn
}
{% endhighlight %}

# PRUEBA

Al principio, es bueno aprender Terraform en un código que funciona, mejorarlo y adaptarlo a sus necesidades.

Para verificar si los métodos anteriores funcionan correctamente, simplemente reemplace los nombres de los depósitos S3 con los que ha creado usted mismo:

* Test-ndgegy4364gdu-source-bucket: mi depósito de origen desde el que descargo y elimino datos
* Test-ndgegy4364gdu-destination-bucket: mi depósito de destino al que estoy transfiriendo datos

<img>

El código anterior creará:

* Política de IAM denominada 'S3_automation_move_objects',
* Rol de IAM denominado 'S3_automation_move_objects',
* Combinará la política de IAM con el rol de IAM

# Resumen

Se han probado y verificado las tres formas de crear una política de IAM en Terraform. En tu trabajo del día a día, puedes elegir el que más te convenga o uno que alguien más haya usado antes por coherencia.

Si conoce alguna otra forma de crear una política de IAM en Terraform, puede compartirla en el comentario.

Happy scripting!