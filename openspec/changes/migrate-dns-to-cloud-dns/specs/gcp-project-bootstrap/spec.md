## ADDED Requirements

### Requirement: 専用GCPプロジェクトの初期化
システムは、このリポジトリ専用のGCPプロジェクトをTerraform bootstrapでプロビジョニングし、少なくともCloud DNS・IAM・IAM Credentials・Cloud Resource Manager・Storage・STSの各APIを有効化しなければならない(SHALL)。

#### Scenario: bootstrapのterraform applyでAPIが有効化される
- **WHEN** `terraform/bootstrap`で`terraform apply`を実行する
- **THEN** 対象GCPプロジェクトでCloud DNS APIを含む必要なAPIが有効化される

### Requirement: 鍵レスなGitHub Actions認証
システムは、GitHub ActionsからGCPへの認証をこのリポジトリに限定したWorkload Identity Federation経由で行い、長期有効なサービスアカウントキーを発行してはならない(SHALL NOT)。

#### Scenario: このリポジトリのGitHub ActionsのみがCI用サービスアカウントを利用できる
- **WHEN** 別のGitHubリポジトリがこのWorkload Identity Federationプロバイダ経由でCI用サービスアカウントの権限借用を試みる
- **THEN** `attribute_condition`によりリポジトリ名が一致しないため拒否される

### Requirement: Terraform state用の専用GCSバケット
システムは、`terraform/main`のTerraform stateを、このプロジェクト専用のバージョニング有効かつ非公開のGCSバケットに保存しなければならない(SHALL)。

#### Scenario: tfstateバケットが非公開かつバージョニング有効
- **WHEN** tfstate用GCSバケットの設定を確認する
- **THEN** `public_access_prevention`が`enforced`であり、バージョニングが有効になっている

### Requirement: DNS管理に絞ったCI権限
システムは、Terraform CI用サービスアカウントに対し、Cloud DNSリソースとstateバケットの管理に必要な権限のみを付与しなければならない(SHALL)。プロジェクト全体に対する広範なオーナー権限を付与してはならない(SHALL NOT)。

#### Scenario: CI用サービスアカウントの権限を確認する
- **WHEN** Terraform CI用サービスアカウントに付与されたIAMロールを確認する
- **THEN** Cloud DNS管理に必要なロールとstateバケットへの`storage.objectAdmin`のみが付与されており、それ以外の広範な権限は付与されていない
