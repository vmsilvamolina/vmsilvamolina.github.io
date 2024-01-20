---
title: 'MS Graph usando Python'
author: Victor Silva
date: 2023-09-17T15:45:32+00:00
layout: single
permalink: /ms-grap-usando-python/
excerpt: ''
categories:
  - Azure
  - Python
tags:
  - Azure
---


## Crear la app registration en Azure



```powershell
import msal

# Enter the details of your AAD app registration
client_id = '{YOUR CLIENT ID}'
client_secret = '{YOUR CLIENT SECRET}'
authority = 'https://login.microsoftonline.com/{YOUR TENANT ID}'
scope = ['https://graph.microsoft.com/.default']

# Create an MSAL instance providing the client_id, authority and client_credential parameters
client = msal.ConfidentialClientApplication(client_id, authority=authority, client_credential=client_secret)

# First, try to lookup an access token in cache
token_result = client.acquire_token_silent(scope, account=None)

# If the token is available in cache, save it to a variable
if token_result:
  access_token = 'Bearer ' + token_result['access_token']
  print('Access token was loaded from cache')

# If the token is not available in cache, acquire a new one from Azure AD and save it to a variable
if not token_result:
  token_result = client.acquire_token_for_client(scopes=scope)
  access_token = 'Bearer ' + token_result['access_token']
  print('New access token was acquired from Azure AD')

print(access_token)
```


https://medium.com/nerd-for-tech/query-ms-graph-api-in-python-e8e04490b04e