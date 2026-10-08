# u-rei-infra

`u-rei.com`まわりの共有基盤をTerraformで一元管理するリポジトリ。

- **DNS**: `u-rei.com`のレコードを管理する。ドメインの登録(レジストラ)はお名前.comに残したまま、権威DNSサーバー(ネームサーバー)の委任先をGoogle Cloud DNSに変更し、レコード管理をIaC化した。
- **Tailscale ACL**: tailnet全体のACLポリシーを、このリポジトリが唯一のオーナーとして管理する(下記「Tailscale ACL」参照)。

旧名は`u-rei.com-dns`。DNSに加えてtailnetのACLも持つようになったためリネームした。

設計の背景・判断は`openspec/project.md`と`openspec/changes/migrate-dns-to-cloud-dns/design.md`を参照。

## 構成

```
terraform/bootstrap/  既存の共有GCPプロジェクト(kuchida-devel)上に、このリポジトリ専用の
                       WIFプール・Terraform CI用サービスアカウント・tfstateバケットを作成する。
                       プロジェクト権限が必要なため、ローカルから手動で一度だけapplyする。
terraform/main/        u-rei.comのCloud DNS管理ゾーンと全レコードを宣言する。
                       CI経由(PRでplan、masterマージでproduction環境の承認を経てapply)で運用する。
terraform/tailscale/   tailnetのACLポリシー(tailscale_acl)を宣言する。stateはDNSと分離(prefix: tailscale/main)。
                       CI経由で運用し、applyは専用ワークフロー(terraform-apply-tailscale.yml)で行う。
```

## レコード所有のポリシー

このリポジトリが`u-rei.com`ゾーンと**全レコードを一元所有**する。`u-rei.com`を使う他リポジトリ(n8n-ops, vaultwarden-hosting, web-skk, kuchida1981.github.io)のTerraform/CIはDNSに一切関与しない。

## Tailscale ACL

`tailscale_acl`はポリシーファイル全体を1つのリソースとして上書きするため、所有者は1つでなければならない。このリポジトリ(`terraform/tailscale/acl.tf`)が唯一のオーナーで、vaultwarden-opsとn8n-opsは`tailscale_acl`を持たず、各自の認証キー(`tailscale_tailnet_key`)だけを管理する。

- **ACLを変更するとき**: `terraform/tailscale/acl.tf`をPRで変更する。**Tailscale管理コンソールでの手編集は禁止**。次回applyで元に戻る。ACLに含まれる`tests`はTailscaleが保存時に検証し、`tag:ci-blog-daily-post`の隔離(`tag:claude-wrapper-server:18789`のみ到達可)を守る。
- **tailnetに接続する新しいサービスを追加するとき**: 先にこのリポジトリの`acl.tf`に`tagOwners`(必要ならルール)を追加してmerge・applyし、その後でサービス側のリポジトリが該当タグの認証キーを発行する。順序が逆だと認証キーの発行が400で失敗する。
- **OAuthクライアントの分離**: Policy File (write)スコープのクライアントはこのリポジトリ専用。vaultwarden-opsとn8n-opsのクライアントはAuth Keys (write)のみで、各サービスのタグに限定する。
- **applyの注意**: applyは`production`環境の承認を経る。ACLを誤ると全サービスがtailnetから切り離されるため、承認前にPRのplan本文(`Plan:`の行)を確認する。同時実行は`concurrency`で禁止している。

## 他リポジトリからレコード値の更新を依頼する場合

n8n-opsやvaultwarden-hostingのVM再作成でExternal IPが変わった場合など、レコード値の変更が必要になったら:

1. このリポジトリで`terraform/main/variables.tf`の該当する変数(`n8n_ip`, `vaultwarden_ip`など)を新しい値に更新するPRを立てる
2. PR上のTerraform Plan結果を確認する
3. `master`にマージすると、production環境の承認を経てCIが自動的に`terraform apply`する

cross-repo Terraform state参照などの密結合は行わない。値の変更は必ずこのリポジトリへの手動PRで行う。

## 新しいレコードを追加する場合

`terraform/main/dns.tf`に`google_dns_record_set`リソースを追加し、値が繰り返し使われる場合は`variables.tf`に変数として切り出す。

## セットアップ手順(初回のみ)

### 0. 前提

- `kuchida-devel`プロジェクトへのGCP権限があること(n8n-ops・vaultwarden-hostingと共有)
- ローカルに`gcloud` CLIと`terraform`(>=1.6)がインストール済みで、対象アカウントで認証済みであること

### 1. Bootstrap(手動・最初の1回だけ)

`terraform/main`はGCSのリモートバックエンドとWorkload Identity Federation経由のGitHub Actions認証を前提にしているが、そのバケットとWIF Pool自体は「これから作る側」なので、ローカルから一度だけ手動で作成する。

```bash
cd terraform/bootstrap
terraform init
terraform apply \
  -var="project_id=kuchida-devel" \
  -var="github_repo=kuchida1981/u-rei-infra"
```

apply完了後、以下のoutputを控える(次のGitHub Secrets登録で使う):

```bash
terraform output
# state_bucket
# workload_identity_provider
# terraform_ci_service_account_email
```

### 2. GitHub Secrets登録

`terraform/bootstrap`の出力を、GitHubリポジトリのSecretsに登録する:

- `GCP_WORKLOAD_IDENTITY_PROVIDER` ← `workload_identity_provider`
- `GCP_SERVICE_ACCOUNT_EMAIL` ← `terraform_ci_service_account_email`
- `TF_STATE_BUCKET` ← `state_bucket`
- `GCP_PROJECT_ID` ← `kuchida-devel`
- `TAILSCALE_TAILNET` ← tailnet名
- `TAILSCALE_OAUTH_CLIENT_ID` / `TAILSCALE_OAUTH_CLIENT_SECRET` ← Tailscale管理コンソールで発行した、**Policy File (write)のみ**のOAuthクライアント(`terraform/tailscale`用)

### 3. Production環境の承認ゲート設定

リポジトリのSettings > Environmentsで`production`環境を作成し、必須レビュアーを設定する(`terraform-apply.yml`の手動承認ゲート)。

### 4. terraform/mainの初回apply

`terraform/main`の変更をPRで出し、Terraform Planを確認してからマージする。マージ後、`production`環境の承認を経てCIが自動的に`terraform apply`する。

## カットオーバー手順

`openspec/changes/migrate-dns-to-cloud-dns/tasks.md`のセクション3・4を参照。Cloud DNS側で全レコードを構築・検証してから、お名前.com側のネームサーバー設定を一括で切り替える。
