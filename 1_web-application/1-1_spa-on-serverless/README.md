# 1-1	Nuxt.js で SPA をサーバーレス環境にデプロイしたい

## Azure 構成

- Azure Static Web Apps
- Azure Functions


## 利用方法

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fquickstart-templates%2FAzure-for-startups%2Fmain%2F1_web-application%2F1-1_spa-on-serverless%2Fazuredeploy.json)


### for dev
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fquickstart-templates%2FAzure-for-startups%2F1-1_spa-on-sreverless%2F1_web-application%2F1-1_spa-on-serverless%2Fazuredeploy.json)


## デバッグ

### Azure CLI によるデプロイ

```bash
IDENTIFIER="{string to identify your resources}"
RESOURCE_GROUP_NAME="rg-${IDENTIFIER}"
az group create --name ${RESOURCE_GROUP_NAME} --location japaneast
az deployment group create --resource-group ${RESOURCE_GROUP_NAME} --template-file bicep/azuredeploy.bicep
```


### Bicep によるARMテンプレート生成

```bash
az bicep build --file bicep/azuredeploy.bicep --outdir .
```


## 参考

- [チュートリアル: ARM テンプレートを使用して Azure 静的 Web アプリを発行する | Microsoft Docs](https://docs.microsoft.com/ja-jp/azure/static-web-apps/publish-azure-resource-manager?tabs=azure-cli)