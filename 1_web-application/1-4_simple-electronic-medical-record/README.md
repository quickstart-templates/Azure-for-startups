# 1-4 患者情報を入力できる簡易的な電子カルテサービスを実装したい

患者情報を入力できる簡易的な電子カルテサービスを実装したい際の構成例です。Web サーバーからデータベースまでフルマネージドなサービスの活用で実装できます。

Azure App Service はコンテナのデプロイにも対応しています。コンテナ化されたアプリを PaaS 環境でスケーラブルに実行することができます。


## 構成

<img src="./docs/images/1-4_simple-electronic-medical-record.png" width="80%" alt="構成図">


### Azure リソース構成


## 利用方法

### 事前準備

- ユーザーの object ID の取得

```
az ad user list --output table
az ad user show --id {UserPrincipalName}
```

### リソースのデプロイ

下記の「Deploy to Azure」ボタンから開くと、Azure ポータルのデプロイ用のパラメータ入力画面に遷移します。

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fquickstart-templates%2FAzure-for-startups%2Fmain%2F1_web-application%2F1-4_simple-electronic-medical-record%2Fazuredeploy.json)

各入力欄に適宜入力し、「Review + create」ボタンを選択します。パラメータの検証が正常に完了したら、「Create」ボタンを選択してデプロイを実行します。

<img src="./docs/images/deploy_001.png" width="80%" alt="デプロイのパラメータ入力画面">

| 項目 | 説明 |
|----|----|
| Project details | |
| Subscription | 利用するサブスクリプションを選択 |
| Resource Group | 利用する既存のグループを選択、または「Create new」から新規作成 |
| Instance details | |
| Region | 利用するリージョンを選択 |
| Workload Name | リソース名に付与する識別用の文字列（プロジェクト名など）を入力 |



key vault は、ネットワーク制限をしているため、ポータルからシークレットなどの変更ができません。アクセスする場合は IP許可するなどの疎通を行ってください。


## デバッグ

本テンプレートをデバッグする場合は、ご参考ください。


### Azure CLI によるデプロイ

```bash
WORKLOAD_NAME="{string to identify your resources}"
RESOURCE_GROUP_NAME="rg-${WORKLOAD_NAME}"
LOCATION="{location that resources are deploy}"
az group create --name ${RESOURCE_GROUP_NAME} --location ${LOCATION}
az deployment group create --resource-group ${RESOURCE_GROUP_NAME} --template-file bicep/azuredeploy.bicep
```


### Bicep によるARMテンプレート生成

```bash
az bicep build --file bicep/azuredeploy.bicep --outdir .
```
