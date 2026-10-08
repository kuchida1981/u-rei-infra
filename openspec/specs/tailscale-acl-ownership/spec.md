# tailscale-acl-ownership Specification

## Purpose
tailnet 全体の ACL ポリシーを単一のリポジトリが唯一のオーナーとして Terraform で管理し、複数リポジトリからの上書き競合やコンソール手編集によるドリフトを防ぐ。

## Requirements

### Requirement: tailnet ACL の単一所有
システムは、tailnet の ACL ポリシー(`tailscale_acl`)を、このリポジトリの Terraform のみで管理しなければならない(SHALL)。他のリポジトリ(vaultwarden-ops、n8n-ops 等)は `tailscale_acl` リソースを宣言してはならない(SHALL NOT)。

#### Scenario: 他リポジトリが ACL を宣言していない
- **WHEN** vaultwarden-ops と n8n-ops の Terraform 構成を確認する
- **THEN** どちらにも `tailscale_acl` リソースは存在せず、tailnet キー(`tailscale_tailnet_key`)のみが宣言されている

#### Scenario: 新しいサービスのタグを追加する
- **WHEN** 新しい tailnet 接続サービスがタグを必要とする
- **THEN** このリポジトリの ACL に `tagOwners` とルールを追加する変更が先にマージされ、その後にサービス側が当該タグの認証キーを発行する

### Requirement: 既存ポリシーの無停止な所有権移行
システムは、所有権の移行時に既存の ACL ポリシーを destroy またはデフォルトへ戻してはならない(SHALL NOT)。新リポジトリで既存ポリシーを import し、plan が差分なしになったことを確認した後でのみ、旧リポジトリの state から外さなければならない(SHALL)。

#### Scenario: import 後の plan が差分なし
- **WHEN** 新リポジトリで既存の ACL を import して `terraform plan` を実行する
- **THEN** 変更なしと報告され、旧リポジトリの state からの除去に進める

#### Scenario: 旧リポジトリで state から外す
- **WHEN** 旧リポジトリの構成から `tailscale_acl` を削除して apply する
- **THEN** リソースは `destroy = false` で state から外されるのみで、tailnet 上の ACL ポリシーは変更されない

### Requirement: ポリシー編集の経路とテスト検証
システムは、ACL の変更を Terraform の変更としてのみ行わなければならない(SHALL)。ACL には `tests` を含め、`tag:ci-blog-daily-post` が `tag:claude-wrapper-server:18789` のみに到達でき、それ以外には到達できないことを Tailscale の保存時検証で保証しなければならない(SHALL)。

#### Scenario: 隔離を破る変更が拒否される
- **WHEN** `tag:ci-blog-daily-post` を広い送信元として許可する変更を apply しようとする
- **THEN** `tests` の検証に失敗し、ポリシーは更新されない

#### Scenario: コンソールでの手編集
- **WHEN** 誰かが管理コンソールで ACL を直接編集する
- **THEN** 次回の `terraform plan` が差分として検出し、apply でこのリポジトリの定義へ戻る

### Requirement: OAuth クライアントの権限分離
システムは、Policy File(write) スコープを持つ Tailscale OAuth クライアントをこのリポジトリ専用としなければならない(SHALL)。vaultwarden-ops と n8n-ops が使う OAuth クライアントは Auth Keys(write) スコープのみとし、Policy File スコープを持ってはならない(SHALL NOT)。

#### Scenario: サービス側リポジトリの権限
- **WHEN** vaultwarden-ops または n8n-ops の CI が使う OAuth クライアントのスコープを確認する
- **THEN** Auth Keys(write) のみが付与されており、Policy File スコープは付与されていない
