## ADDED Requirements

### Requirement: 既存の共有GCPプロジェクトの再利用
システムは、n8n-ops・vaultwarden-hostingと共有の既存GCPプロジェクト(`kuchida-devel`)上にリソースをプロビジョニングしなければならない(SHALL)。このリポジトリのために新規GCPプロジェクトを作成してはならない(SHALL NOT)。Terraform bootstrapは、少なくともCloud DNS・IAM・IAM Credentials・Cloud Resource Manager・Storage・STSの各APIが有効であることを保証しなければならない(SHALL)。

#### Scenario: bootstrapのterraform applyで既存プロジェクトにリソースが作成される
- **WHEN** `terraform/bootstrap`で`terraform apply`を実行する
- **THEN** 新規プロジェクトは作成されず、既存の`kuchida-devel`プロジェクト内にこのリポジトリ専用のリソースが作成され、Cloud DNS APIを含む必要なAPIが有効な状態になる

### Requirement: 鍵レスなGitHub Actions認証
システムは、GitHub ActionsからGCPへの認証をこのリポジトリに限定したWorkload Identity Federation経由で行い、長期有効なサービスアカウントキーを発行してはならない(SHALL NOT)。

#### Scenario: このリポジトリのGitHub ActionsのみがCI用サービスアカウントを利用できる
- **WHEN** 別のGitHubリポジトリがこのWorkload Identity Federationプロバイダ経由でCI用サービスアカウントの権限借用を試みる
- **THEN** `attribute_condition`によりリポジトリ名が一致しないため拒否される

### Requirement: Terraform state用の専用GCSバケット
システムは、`terraform/main`のTerraform stateを、このリポジトリ専用のバージョニング有効かつ非公開のGCSバケットに保存しなければならない(SHALL)。他リポジトリのtfstateバケット(`kuchida-devel-n8n-tfstate`等)と共用してはならない(SHALL NOT)。

#### Scenario: tfstateバケットが非公開かつバージョニング有効
- **WHEN** tfstate用GCSバケットの設定を確認する
- **THEN** `public_access_prevention`が`enforced`であり、バージョニングが有効になっている

### Requirement: DNS管理に絞ったCI権限
システムは、Terraform CI用サービスアカウントに対し、Cloud DNSリソースとstateバケットの管理に必要な権限のみを付与しなければならない(SHALL)。プロジェクト全体に対する広範なオーナー権限を付与してはならない(SHALL NOT)。

#### Scenario: CI用サービスアカウントの権限を確認する
- **WHEN** Terraform CI用サービスアカウントに付与されたIAMロールを確認する
- **THEN** Cloud DNS管理に必要なロールとstateバケットへの`storage.objectAdmin`のみが付与されており、それ以外の広範な権限は付与されていない
