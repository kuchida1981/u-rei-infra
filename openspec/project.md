# Project Context

## Purpose
u-rei.com ドメインのDNSレコードをTerraformで一元管理するリポジトリ。これまでお名前.comのWeb UIで手動管理されていたDNSレコードをGoogle Cloud DNSへ移行し、IaC化する。

ドメインの登録(レジストラ)はお名前.comに残したまま、権威DNSサーバー(ネームサーバー)の委任先だけをGoogle Cloud DNSへ変更する。ドメイン移管そのものは行わない。

## Tech Stack
- **IaC**: Terraform
- **DNS Hosting**: Google Cloud DNS (`google_dns_managed_zone` / `google_dns_record_set`)
- **Cloud Provider**: Google Cloud Platform(n8n-ops・vaultwarden-hostingと共有の既存プロジェクト`kuchida-devel`を使用。新規プロジェクトは作らない)
- **CI/CD**: GitHub Actions (Workload Identity Federationでの鍵レス認証)
- **State Backend**: GCS(このリポジトリ専用のtfstateバケット)

## Project Conventions

### Code Style
- Terraformの記法・命名規則は姉妹リポジトリ(n8n-ops, vaultwarden-hosting)に合わせる。

### Architecture Patterns
- `terraform/bootstrap`: 既存の共有GCPプロジェクト(`kuchida-devel`)上に、このリポジトリ専用のリソース(GitHub Actions用Workload Identity連携、Terraform CI用サービスアカウント、tfstate用GCSバケット)を作成する。プロジェクト自体の作成やAPI有効化は行わない(dns.googleapis.com含め既に有効化済み)。n8n-ops/vaultwarden-hostingのbootstrap構成(リソースの粒度・命名)を踏襲する。
- `terraform/main`: `u-rei.com`のCloud DNS管理ゾーンと、配下の全DNSレコードをTerraformリソースとして宣言する。

### DNSレコード所有のポリシー(重要な設計判断)
- このリポジトリが `u-rei.com` ゾーンと**全レコードを一元所有**する。他リポジトリ(n8n-ops, vaultwarden-hosting, web-skk, kuchida1981.github.io)のTerraform/CIはDNSに一切関与しない。
- レコードの値(IPアドレス等)が変わった場合は、当該サービス側リポジトリからこのリポジトリへ手動でtfvars更新のPRを立てる運用とする。cross-repo Terraform data source等による密結合は行わない(姉妹リポジトリがTailscale認証情報などの共有値を、remote state参照ではなく手動コピーで扱っている既存の慣習に合わせる)。

### GCPプロジェクト方針
- n8n-ops・vaultwarden-hostingと**同じ既存の共有GCPプロジェクト`kuchida-devel`を使う**。新規プロジェクトは作成しない。
- リポジトリ間の分離はプロジェクト単位ではなく、リポジトリ専用のWorkload Identity Pool(例: `github-actions-pool-dns`)・専用のTerraform CI用サービスアカウント(例: `terraform-ci-dns`、Cloud DNS管理権限のみ)・専用のtfstate用GCSバケット(例: `kuchida-devel-dns-tfstate`)で行う。これはn8n-ops(`github-actions-pool-n8n` / `terraform-ci-n8n` / `kuchida-devel-n8n-tfstate`)・vaultwarden-hostingが実際に採用している分離パターンそのものである。

### 切替(カットオーバー)方針
- Cloud DNS側で全レコードを構築し、Googleが払い出すネームサーバーに対して`dig`等で全サービス(n8n, vaultwarden, ブログ, skk, メール認証)が正しく解決されることを確認してから、お名前.com側のネームサーバー設定を一括で切り替える。段階的な部分切替は行わない(NS委任はドメイン単位でしか切り替えられないため)。

### Testing Strategy
- `terraform plan`によるレビューと、切替前の`dig @<google-nameserver>`による全レコードの解決確認を検証手段とする。

## Domain Context
`u-rei.com`は以下4つの独立したリポジトリ・サービスに使われる共有ドメイン:
- **n8n-ops**: `n8n.u-rei.com` → GCE VM (n8nワークフロー自動化)
- **vaultwarden-hosting**: `vaultwarden.u-rei.com` → GCE VM (Vaultwarden)
- **kuchida1981.github.io**: apex(`u-rei.com`)・`www.u-rei.com` → GitHub Pages(個人ブログ)
- **web-skk**: `skk.u-rei.com` → GitHub Pages(Project Pages、CNAME先はkuchida1981.github.io)
- メール送信認証(Brevo経由のDKIM/DMARC)はn8nのワークフローからのメール送信に対応する

## Important Constraints
- ネームサーバー切替は4サービス全てに同時に影響するため、事前検証を徹底してから一括切替する。
- Google Cloud DNSはドメインレジストラ機能を持たない。レジストラ(お名前.com)側の設定は本リポジトリのTerraformでは管理できず、手動作業が必要。

## External Dependencies
- **お名前.com**: ドメインレジストラ。ネームサーバー設定の変更のみ手動で行う。
- **GitHub Pages**: kuchida1981.github.io・web-skkが使用する固定IP(185.199.108-111.153)・CNAME先。
- **Brevo**: n8nのメール送信サービス。DKIM/DMARCレコードで送信ドメイン認証を行う。
