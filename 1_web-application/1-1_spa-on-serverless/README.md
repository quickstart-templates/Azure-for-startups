# 1-1	Nuxt.js で SPA をサーバーレス環境にデプロイしたい

## 構成

- Azure Static Web Apps
- Azure Functions

![構成図](./docs/images/1-1_spa-on-serverless_structure.png)

## 利用方法

下記の「Deploy to Azure」ボタンをクリックすると、デプロイ用のパラメータ入力画面に遷移します。

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fquickstart-templates%2FAzure-for-startups%2Fmain%2F1_web-application%2F1-1_spa-on-serverless%2Fazuredeploy.json)

![デプロイのパラメータ入力画面](./docs/images/deploy_001.png)

下記の情報を入力して「Review + create」ボタンを選択し、パラメータの検証が正常に完了したら、「Create」ボタンを選択してデプロイを実行します。

| 項目 | 説明 |
|----|----|
| Project details | |
| Subscription | 利用するサブスクリプションを選択 |
| Resource Group | 利用する既存のグループを選択、または「Create new」から新規作成 |
| Instance details | |
| Region | 利用するリージョンを選択 |
| workloadName | リソース名に付与する識別用の文字列（プロジェクト名など）を入力 |
| Plan Sku Name | Azure App Service Plann の SKU を選択 |
| Storage Sku Name | Azure Functions に利用する Azure Storage Account の SKU を選択 |
| Static App Location | Azure Static Web App の API におけるリージョン（※）を選択 |
| App Location | |
| App Artifact Location | |
| App Build Command | |
| Skip GitHub Action Workflow Generation | |
| GitHub Repository Branch | |
| GitHub Repository Url | |
| GitHub Access Token | |

### Azure Static Web App の設定値について

ビルド構成については、こちらをご参照ください。

- [Azure Static Web Apps のビルド構成 | Microsoft Docs](https://docs.microsoft.com/ja-jp/azure/static-web-apps/build-configuration)

※ Azure Static Web App の API におけるリージョンは、内蔵型の API を利用する際に展開する先です。本テンプレートの校正では、外部 API を利用するのでリージョンの指定は向こうとなりますが、必須項目のため設定します。

### 備考

- 命名規則については、[名前付け規則を定義する - Cloud Adoption Framework | Microsoft Docs](https://docs.microsoft.com/ja-jp/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming) も併せてご参考ください。

## デバッグ

### Azure CLI によるデプロイ

```bash
WORKLOAD_NAME="{string to identify your resources}"
RESOURCE_GROUP_NAME="rg-${WORKLOAD_NAME}"
LOCATION="{Location}"
az group create --name ${RESOURCE_GROUP_NAME} --location ${LOCATION}
az deployment group create --resource-group ${RESOURCE_GROUP_NAME} --template-file bicep/azuredeploy.bicep
```


### Bicep によるARMテンプレート生成

```bash
az bicep build --file bicep/azuredeploy.bicep --outdir .
```


## 参考

- [チュートリアル: ARM テンプレートを使用して Azure 静的 Web アプリを発行する | Microsoft Docs](https://docs.microsoft.com/ja-jp/azure/static-web-apps/publish-azure-resource-manager?tabs=azure-cli)