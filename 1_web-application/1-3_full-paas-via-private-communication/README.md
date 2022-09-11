# 1-3 プライベート通信のみのシステムを Full PaaS で実現したい

プライベート通信のみしか許可されないセキュリティ要件の高い Web システムをフル PaaS 構成で実現したい際の構成例です。

Azure Private Endpoint を使用することで、PaaS 製品のエンドポイントに Private IP を提供できます。また、Azure App Service の VNET 統合により、アプリのバックエンドを指定したネットワークに集約できます。


## 構成

<img src="./docs/images/1-3_full-paas-via-private-communication_structure.png" width="80%" alt="構成図">


### Azure リソース構成

- Azure VPN Gateway
- Azure App Service (Web apps)
- Azure SQL Database

本構成では、Azure証明書によるポイント対サイト VPN 接続を使用しています。


## 利用方法

### 事前準備

本構成では、証明書認証を利用したポイント対サイト構成を用いているため、ルート証明書およびクライアント証明書が必要です。ルート証明書は、エンタープライズ 証明機関によって発行された証明書（推奨）、または自己署名証明書を利用できます。こちらを参考にご用意ください。

- [ルート証明書を生成する](https://docs.microsoft.com/ja-jp/azure/vpn-gateway/vpn-gateway-howto-point-to-site-resource-manager-portal#getcer)


### リソースのデプロイ

下記の「Deploy to Azure」ボタンから開くと、Azure ポータルのデプロイ用のパラメータ入力画面に遷移します。

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/)

各入力欄に適宜入力し、「Review + create」ボタンを選択します。パラメータの検証が正常に完了したら、「Create」ボタンを選択してデプロイを実行します。

| 項目 | 説明 |
|----|----|
| Project details | |
| Subscription | 利用するサブスクリプションを選択 |
| Resource Group | 利用する既存のグループを選択、または「Create new」から新規作成 |
| Instance details | |
| Region | 利用するリージョンを選択 |
| Workload Name | リソース名に付与する識別用の文字列（プロジェクト名など）を入力 |
| App Service Plan Sku Name | Azure App Service Plan の SKU を選択 |

アドレスプールは、仮想ネットワークのアドレス空間と被ってはいけません。


### 手元のマシンの hosts 書換え


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

## 参考

- [azure-quickstart-templates/quickstarts/microsoft.sql/private-endpoint-sql at master · Azure/azure-quickstart-templates](https://github.com/Azure/azure-quickstart-templates/tree/master/quickstarts/microsoft.sql/private-endpoint-sql)
- [P2S VPN と証明書認証を使用して VNet に接続する: ポータル - Azure VPN Gateway | Microsoft Docs](https://docs.microsoft.com/ja-jp/azure/vpn-gateway/vpn-gateway-howto-point-to-site-resource-manager-portal)
