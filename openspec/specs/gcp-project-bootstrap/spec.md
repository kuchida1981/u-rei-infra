# gcp-project-bootstrap

## Purpose

このリポジトリ専用のGCPリソース(既存の共有プロジェクト上でのWorkload Identity連携、Terraform CI用サービスアカウント、tfstate用GCSバケット)の初期化を扱う。

## Requirements

### Requirement: 既存の共有GCPプロジェクトの再利用
システムは、n8n-ops・vaultwarden-hostingと共有の既存GCPプロジェクト(`kuchida-devel`)上にリソースをプロビジョニングしなければならない(SHALL)。このリポジトリのために新規GCPプロジェクトを作成してはならない(SHALL NOT)。Terraform bootstrapは、少なくともCloud DNS・IAM・IAM Credentials・Cloud Resource Manager・Storage・STSの各APIが有効であることを保証しなければならない(SHALL)。

#### Scenario: bootstrapのterraform applyで既存プロジェクトにリソースが作成される
- **WHEN** `terraform/bootstrap`で`terraform apply`を実行する
- **THEN** 新規プロジェクトは作成されず、既存の`kuchida-devel`プロジェクト内にこのリポジトリ専用のリソースが作成され、Cloud DNS APIを含む必要なAPIが有効な状態になる

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

### Requirement: DNS管理に絞ったCI権限
システムは、Terraform CI用サービスアカウントに対し、Cloud DNSリソースとstateバケットの管理に必要な権限のみを付与しなければならない(SHALL)。プロジェクト全体に対する広範なオーナー権限を付与してはならない(SHALL NOT)。

#### Scenario: CI用サービスアカウントの権限を確認する
- **WHEN** Terraform CI用サービスアカウントに付与されたIAMロールを確認する
- **THEN** Cloud DNS管理に必要なロールとstateバケットへの`storage.objectAdmin`のみが付与されており、それ以外の広範な権限は付与されていない
