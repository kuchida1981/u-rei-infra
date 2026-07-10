## Context

u-rei.comは以下4つの独立したリポジトリ・サービスに使われる共有ドメインである。

- **n8n-ops**: `n8n.u-rei.com` → GCE VM(n8nワークフロー自動化、静的External IP)
- **vaultwarden-hosting**: `vaultwarden.u-rei.com` → GCE VM(Vaultwarden、静的External IP)
- **kuchida1981.github.io**: apex(`u-rei.com`)・`www.u-rei.com` → GitHub Pages(個人ブログ、User site)
- **web-skk**: `skk.u-rei.com` → GitHub Pages(Project Pages。CNAME先はUser siteと同じ`kuchida1981.github.io`だが、GitHub側がHostヘッダーでweb-skkリポジトリのPagesへ振り分ける)
- メール送信認証: Brevo経由のDKIM(`brevo1/2._domainkey`)・DMARC(`_dmarc`)・ドメイン所有確認TXTは、n8nのワークフローからのメール送信に対応する

現状はお名前.comのWeb UIで全レコードを手動管理しており、変更履歴・レビュー・差分確認の手段がない。n8n-opsとvaultwarden-hostingはそれぞれ専用GCPプロジェクトを持ち、`terraform/bootstrap`(GCPプロジェクト初期化・WIF・tfstateバケット)と`terraform/main`(実リソース)という2段構成のTerraformパターンを既に確立している。このリポジトリもそのパターンを踏襲する。

## Goals / Non-Goals

**Goals:**
- u-rei.comの全DNSレコードをTerraformで宣言的に管理し、変更をレビュー可能にする。
- 権威DNSサーバーの委任先をGoogle Cloud DNSへ切り替える。
- DNSレコードの所有権をこのリポジトリに一元化し、他リポジトリのTerraform/CIをDNSから完全に切り離す。

**Non-Goals:**
- ドメインレジストラ自体の移管(お名前.comから他社への移管)は行わない。
- DNSSECの有効化は行わない(現状維持)。
- n8n-ops・vaultwarden-hosting・web-skk・kuchida1981.github.ioのTerraform/CIへの変更は行わない。
- レコード値の自動同期(cross-repo Terraform remote state参照など)の仕組みは作らない。

## Decisions

### 1. DNSゾーン・レコードは既存の共有GCPプロジェクトに置き、分離はWIF/SA/tfstateバケット単位で行う
実際に確認したところ、n8n-opsとvaultwarden-hostingは「1リポジトリ=1専用GCPプロジェクト」ではなく、**同じ既存プロジェクト`kuchida-devel`を共有**していた(n8n・vaultwarden両VMとも同一プロジェクト内で稼働、`dns.googleapis.com`も既に有効化済み)。`variables.tf`の`project_id`が変数化されているのは環境ポータビリティのためであり、プロジェクトの一意性を意味するものではなかった。

実際の分離単位は、リポジトリごとに作成される
- Workload Identity Pool(`github-actions-pool-n8n`など、`attribute_condition`でリポジトリ名を限定)
- Terraform CI用サービスアカウント(`terraform-ci-n8n`など、必要最小限のロールのみ付与)
- tfstate用GCSバケット(`kuchida-devel-n8n-tfstate`など)

の3点であり、GCPプロジェクトそのものではない。このリポジトリもこの実際の慣習に合わせ、新規GCPプロジェクトは作らず、`kuchida-devel`上に専用のWIFプール・専用サービスアカウント・専用tfstateバケットを作成する。

### 2. ゾーンと全レコードをこのリポジトリが一元所有する
Cloud DNSの`google_dns_managed_zone`は1つのGCPプロジェクトにしか属せない。他リポジトリからレコードを追加する方式(cross-project `data "google_dns_managed_zone"` + 各リポジトリのCIにDNS権限を付与)も検討したが、以下の理由で採用しない。
- 各リポジトリのCIサービスアカウントにDNS管理者権限を配ることになり、権限のスコープが不必要に広がる。
- 姉妹リポジトリの既存パターン(Tailscale OAuth認証情報などの共有値をremote state参照ではなく手動コピーで扱う)と一貫性がない。
- レコード値(IPアドレス)は静的IP永続化により変更頻度が低く、一元管理のコストは小さい。

レコード値の変更が必要な場合は、変更元リポジトリからこのリポジトリへ手動でtfvars更新のPRを立てる運用とする。

### 3. カットオーバーは一括切替、段階切替はしない
NS委任はドメイン単位でしか設定できず、一部レコードだけを新ゾーンに向けることはできない。したがって、Cloud DNS側で全レコードを事前に構築し`dig`で検証したうえで、お名前.com側のネームサーバー設定を一括で切り替える。

## Risks / Trade-offs

- [お名前.com側のネームサーバー設定変更はTerraform管理外の手動作業] → 切替前にCloud DNS側の全レコードをdigで検証し、切替後も主要レコードを再確認する手順をtasksに含める。
- [切替の瞬間、u-rei.comを使う4サービス全てに同時に影響しうる] → 事前検証を徹底し、切替は影響の小さい時間帯に実施する。ロールバックはお名前.com側のネームサーバー設定を元(01-04.dnsv.jp)に戻すことで即座に可能。
- [`kuchida-devel`は個人用の汎用プロジェクトであり、BigQuery・Firebase・Gmail APIなどDNSと無関係な多数のサービスも同居している] → このリポジトリのTerraform CI用サービスアカウントにはCloud DNS管理に必要なロールのみを付与し、プロジェクト全体への広範な権限は付与しない(gcp-project-bootstrap capability要件)。
- [他リポジトリのIPアドレス変更がこのリポジトリへの手動同期漏れを招く可能性] → n8n-ops/vaultwarden-hostingは静的External IPを要件化しており、変更頻度は低い。将来的に頻度が上がる場合は同期の自動化を再検討する。

## Migration Plan

1. `terraform/bootstrap`で既存の共有プロジェクト`kuchida-devel`上に、このリポジトリ専用のWIFプール・Terraform CI用サービスアカウント・tfstateバケットをセットアップする(プロジェクト作成・Cloud DNS API有効化は既に完了済みのため不要)。
2. `terraform/main`でu-rei.comの`google_dns_managed_zone`と全レコード(`google_dns_record_set`)を、現行お名前.comゾーンの内容に基づき宣言する。
3. `terraform apply`でCloud DNS側にゾーンを構築し、Googleが払い出すネームサーバーを控える。
4. Googleのネームサーバーに対して`dig`で全レコード(apex A、www/skk CNAME、n8n/vaultwarden A、brevo DKIM CNAME、TXT、DMARC TXT)を直接問い合わせ、期待値と一致することを検証する。
5. お名前.com管理画面でネームサーバー設定をGoogleの4つのネームサーバーに変更する。
6. 一般のリゾルバ経由で全レコードの解決を確認し、各サービス(n8n、vaultwarden、ブログ、web-skk、メール送信)が正常に動作することを確認する。
7. 問題があればお名前.com側のネームサーバー設定を元(01-04.dnsv.jp)に戻してロールバックする。

## Open Questions

- なし(DNSSECは今回スコープ外とすることで合意済み)
