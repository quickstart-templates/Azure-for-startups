# 3-2 社内データとオープンデータからインサイトを抽出したい

社内データとオープンデータを統合して分析したい際の構成例です。

Azure Data Factory と Azure Functions を利用することでAzureのみでなく、オンプレや他社クラウドの社内データとオープンデータを統合することが可能です。統合したデータをPower BIで可視化することで、インサイトを見出すことが可能です。


## 構成

<img src="./docs/images/3-2_extract-insights-from-internal-and-opendata.png" width="80%" alt="構成図">

Power BI による分析は、Power BI サービス、Power BI Embedded または Power BI Desktop を利用できます。詳しくはドキュメントをご参照ください。

- [Power BI ドキュメント - Power BI | Microsoft Learn](https://learn.microsoft.com/ja-jp/power-bi/)
- [Power BI Embedded の分析ドキュメント - Power BI | Microsoft Learn](https://learn.microsoft.com/ja-jp/power-bi/developer/embedded/)

Power BI のデータソースとの接続については、こちらをご参照ください。

- [Power BI でデータに接続する ‐ ドキュメント - Power BI | Microsoft Learn](https://learn.microsoft.com/ja-jp/power-bi/connect-data/)

また、Azure Data Factory におけるオンプレ上のリソースとの接続については、セルフホステッド統合ランタイムについてご確認ください。

- [セルフホステッド統合ランタイム](https://learn.microsoft.com/en-us/azure/data-factory/concepts-integration-runtime#self-hosted-integration-runtime)


### Azure リソース構成

- Azure Data Factory
- Azure Synapse Analytics
- Azure Functions
- Storage Account

<img src="./docs/images/generated-structure-by-arm.png" width="80%" alt="構成図">

Azure Data Factory では、Synapse Analytics に対して Linked Service を構成しています。接続には User-assigned Managed Identity を用いています。

また、Azure Functions と Azure Synapse Analytics の接続も User-assigned Managed Identity を用いています。SDK 等を用いた接続の際は、Active Directory を用いた接続で User-assigned Manged Identity のクライアントIDを指定してご利用ください。（本構成では、User-assigned Manged Identity のクライアントIDを、Application Settings の `USER_ASSIGNED_IDENTITY_CLIENT_ID` に設定しています。）


## 利用方法

### リソースのデプロイ

下記の「Deploy to Azure」ボタンから開くと、Azure ポータルのデプロイ用のパラメータ入力画面に遷移します。

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fquickstart-templates%2FAzure-for-startups%2Fmain%2F3_data-analysis-visialization%2F3-2_extract-insights-from-internal-and-opendata%2Fazuredeploy.json)

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
| Storage Account Sku Code | Azure Storage Account の SKU を選択 |
| App Service Plan Sku Code | Azure App Service Plan のプランを選択 |
| Sql Database Collation | Azure SQL Database の照合順序を選択（※1） |

※1 Azure SQL Server の照合順序については、こちらをご参照ください。

- [照合順序と Unicode のサポート - SQL Server | Microsoft Docs](https://docs.microsoft.com/ja-jp/sql/relational-databases/collations/collation-and-unicode-support?view=sql-server-ver16)


## リソース配置後の作業

### Azure Synapse Analytics へのアクセスについて

本構成のデプロイ直後は、Azure Synapse Analytics は外部からのアクセスを受け付けない設定になっています。

SQL pools の Built-in サーバーレス SQL プールの状態を Unreachable から直したい場合や、専用SQLプールへアクセスする場合は、Synapse Analytics のネットワーク設定から、作業環境のIPアドレスを許可するなど、適宜設定を行ってください。


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
