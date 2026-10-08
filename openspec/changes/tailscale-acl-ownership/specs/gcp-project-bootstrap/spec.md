## MODIFIED Requirements

### Requirement: 鍵レスなGitHub Actions認証
システムは、GitHub ActionsからGCPへの認証をこのリポジトリ(リネーム後のリポジトリ名)に限定したWorkload Identity Federation経由で行い、長期有効なサービスアカウントキーを発行してはならない(SHALL NOT)。リポジトリのリネーム後は、`attribute_condition` と `principalSet` の対象を新しいリポジトリ名へ更新しなければならない(SHALL)。

#### Scenario: このリポジトリのGitHub ActionsのみがCI用サービスアカウントを利用できる
- **WHEN** 別のGitHubリポジトリがこのWorkload Identity Federationプロバイダ経由でCI用サービスアカウントの権限借用を試みる
- **THEN** `attribute_condition`によりリポジトリ名が一致しないため拒否される

#### Scenario: リネーム後のリポジトリが認証できる
- **WHEN** リネーム後のリポジトリの GitHub Actions が WIF 経由でCI用サービスアカウントの権限借用を試みる
- **THEN** `attribute_condition` が新しいリポジトリ名を許可しているため認証に成功する

### Requirement: Terraform state用の専用GCSバケット
システムは、`terraform/main`のTerraform state(DNS用と、Tailscale 用の別 prefix の両方)を、このリポジトリ専用のバージョニング有効かつ非公開のGCSバケットに保存しなければならない(SHALL)。他リポジトリのtfstateバケット(`kuchida-devel-n8n-tfstate`等)と共用してはならない(SHALL NOT)。

#### Scenario: tfstateバケットが非公開かつバージョニング有効
- **WHEN** tfstate用GCSバケットの設定を確認する
- **THEN** `public_access_prevention`が`enforced`であり、バージョニングが有効になっている

#### Scenario: DNS と Tailscale の state が分離されている
- **WHEN** tfstate用バケット内のオブジェクトを確認する
- **THEN** DNS 用と Tailscale 用の state が異なる prefix に保存されており、互いのリソースを同一 state に混在させていない
