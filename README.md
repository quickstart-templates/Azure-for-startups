# 目的別 Azure 構成サンプル

## 構成一覧

### 1 Web アプリケーション

- [1-1 Nuxt.js で SPA をサーバーレス環境にデプロイしたい](./1_web-application/1-1_spa-on-serverless/)
- [1-3 プライベート通信のみのシステムを Full PaaS で実現したい](./1_web-application/1-3_full-paas-via-private-communication/)
- [1-4 患者情報を入力できる簡易的な電子カルテサービスを実装したい](./1_web-application/1-4_simple-electronic-medical-record/)
- [1-6 D2C ブランドの企画・生産・EC 販売を提供するサービスを作りたい](./1_web-application/1-6_integrated-platform-for-d2c-brand/)
- [1-7 Flutter を使用して Web アプリを作りたい](./1_web-application/1-7_hosting-flutter-web-app/)
- [1-8 Firebase で作ったシステムを Azure に移行したい](./1_web-application/1-8_transfer-system-from-firebase/)


### 3 データ分析・可視化

- [3-1 社内データを統合して分析・可視化したい](./3_data-analysis-visialization/3-1_analyze-visualize-internal-data/)

### 7 バックアップ

- [7-2 リージョン障害時も運用継続したい（Webアプリケーション編）](./7_backup/7-2_disaster-recorvery-webapp/)


### 8 その他

- [8-1 外部向けに API を公開したい](./8_other/8-1_publish-api/)


## 本リポジトリの利用について

各構成のディレクトリに、デプロイ用のリンクボタンを用意しています。各ディレクトリの README を参考にデプロイおよび構成を行ってください。

また、ARMテンプレートは、Bicep を用いて作成しています。

Bicep については、[Azure リソースをデプロイするための Bicep 言語 - Azure Resource Manager | Microsoft Docs](https://docs.microsoft.com/ja-jp/azure/azure-resource-manager/bicep/overview?tabs=bicep) を参照して下さい。
