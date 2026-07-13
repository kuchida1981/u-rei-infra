# dns-zone-management

## Purpose

u-rei.comのCloud DNS管理ゾーンと配下の全レコードをTerraformで宣言的に管理し、このリポジトリが一元所有する仕組みを扱う。

## Requirements

### Requirement: Terraformによる宣言的レコード管理
システムは、u-rei.comの全DNSレコードをこのリポジトリの`terraform/main`内でTerraformリソースとして宣言的に管理しなければならない(SHALL)。ゾーンが稼働した後は、Terraform経由以外の方法でレコードを作成・変更してはならない(SHALL NOT)。

#### Scenario: 新しいレコードを追加する
- **WHEN** 新しいサブドメインやレコードが必要になる
- **THEN** このリポジトリの`terraform/main`に`google_dns_record_set`リソースとして追加され、`terraform apply`経由で反映される

### Requirement: GitHub Pages向けレコードの維持
システムは、kuchida1981.github.io向けのapex Aレコード(185.199.108.153/.109.153/.110.153/.111.153)と、www・skkサブドメインからkuchida1981.github.ioへのCNAMEレコードを維持しなければならない(SHALL)。

#### Scenario: ブログとweb-skkが正しく解決される
- **WHEN** `u-rei.com`・`www.u-rei.com`・`skk.u-rei.com`をdigで問い合わせる
- **THEN** それぞれ移行前と同じGitHub Pages向けの値が返る

### Requirement: サービスVM向けAレコードの維持
システムは、n8n.u-rei.comとvaultwarden.u-rei.comの各Aレコードを、対応するGCE VMの静的External IPに向けて維持しなければならない(SHALL)。

#### Scenario: n8nとvaultwardenが正しく解決される
- **WHEN** `n8n.u-rei.com`・`vaultwarden.u-rei.com`をdigで問い合わせる
- **THEN** 各サービスの静的External IPが返る

### Requirement: メール送信認証レコードの維持
システムは、n8nのワークフローからの送信メールに必要なBrevoのDKIM CNAMEレコード(brevo1/brevo2._domainkey)、ドメイン所有確認TXTレコード、DMARC TXTレコードを維持しなければならない(SHALL)。

#### Scenario: DKIM/DMARCが検証できる
- **WHEN** `brevo1._domainkey.u-rei.com`・`brevo2._domainkey.u-rei.com`・`_dmarc.u-rei.com`をdigで問い合わせる
- **THEN** 移行前と同じ値が返り、Brevo側のドメイン認証チェックが通る

### Requirement: レコード所有権の一元化
システムは、u-rei.comの管理ゾーンと全レコードの唯一の所有者としてこのリポジトリを扱わなければならない(SHALL)。n8n-ops・vaultwarden-hosting・web-skk・kuchida1981.github.ioの各リポジトリは、DNSレコードを直接プロビジョニング・変更してはならない(SHALL NOT)。

#### Scenario: 他リポジトリでレコード値の変更が必要になる
- **WHEN** 例えばn8nのVM再作成でExternal IPが変わった場合
- **THEN** n8n-ops側のTerraformはDNSに一切関与せず、このリポジトリへ値更新のPull Requestを立てる運用で反映される
