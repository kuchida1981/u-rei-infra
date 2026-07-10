## Why

u-rei.comのDNSレコードは現在お名前.comのWeb UI上で手動管理されており、変更履歴もレビューもなくIaC化できていない。n8n.u-rei.com(n8n-ops)、vaultwarden.u-rei.com(vaultwarden-hosting)、apex/www/skk(kuchida1981.github.io・web-skk向けGitHub Pages)、Brevo経由メール送信用のDKIM/DMARCレコードなど、4つの独立したプロジェクトがこの1ドメインを共有しており、手動管理では変更ミスやレビュー不在のリスクが大きい。ドメインの登録(レジストラ)自体はお名前.comに残しつつ、権威DNSサーバーの委任先をGoogle Cloud DNSへ切り替え、Terraformで全レコードを一元管理できるようにする。

## What Changes

- u-rei.com-dns専用の新規GCPプロジェクトをTerraform(`terraform/bootstrap`)で構築する。姉妹リポジトリ(n8n-ops, vaultwarden-hosting)と同じパターンで、必要API有効化・GitHub Actions用Workload Identity Federation・Terraform CI用サービスアカウント・tfstate用GCSバケットを用意する。
- `terraform/main`でCloud DNSの管理ゾーン(`google_dns_managed_zone`)を作成し、現行お名前.comゾーンの全レコード(apex A×4, www/skk CNAME, n8n/vaultwarden A, brevo DKIM CNAME×2, TXT, DMARC TXT)を`google_dns_record_set`として宣言する。
- このリポジトリがu-rei.comゾーンと全レコードを一元所有する。n8n-ops・vaultwarden-hosting・web-skk・kuchida1981.github.ioのTerraform/CIはDNSに一切関与しない。レコード値(IPアドレス等)の変更が必要な場合は、当該サービス側から本リポジトリへ手動でtfvars更新のPRを立てる運用とする。
- Cloud DNS側で全レコードを構築し、Googleが払い出すネームサーバーに対して`dig`等で全レコードの解決を検証したうえで、お名前.com側のネームサーバー設定を一括で切り替える(部分的な段階切替は行わない)。
- DNSSECは今回のスコープでは有効化しない(現状維持)。

## Capabilities

### New Capabilities
- `gcp-project-bootstrap`: このリポジトリ専用のGCPプロジェクトの初期化(API有効化、GitHub Actions用WIF、Terraform CI用サービスアカウント、tfstate用GCSバケット)を扱う。
- `dns-zone-management`: u-rei.comのCloud DNS管理ゾーンと配下の全レコードをTerraformで宣言的に管理し、このリポジトリが一元所有する仕組みを扱う。

### Modified Capabilities
(既存specなし。新規リポジトリのため該当なし)

## Impact

- 新規GCPプロジェクト1つが増える(課金対象、Cloud DNSのゾーン費用+クエリ課金が少額発生)。
- お名前.com側のネームサーバー設定変更が必要(手動作業、Terraform管理外)。切替の瞬間はu-rei.comを使う全サービス(n8n, vaultwarden, ブログ, web-skk, メール認証)に影響しうる。
- n8n-ops, vaultwarden-hosting, web-skk, kuchida1981.github.ioの各リポジトリ自体にはコード変更は発生しない。
