> 担当の目安: **[Claude]** = Terraformコード等の作成、**[ユーザー]** = 個人GCPアカウント/お名前.com/Brevoでの手動操作(実行権限・認証情報がユーザー本人にしかないため)。

## 1. GCPプロジェクトのbootstrap

既存の共有GCPプロジェクト`kuchida-devel`(n8n-ops・vaultwarden-hostingと同一)を使用する。新規プロジェクト作成は不要。`dns.googleapis.com`は確認済みで既に有効。

- [x] 1.1 [Claude] `terraform/bootstrap`を作成し、`kuchida-devel`上で必要API(dns, iam, iamcredentials, cloudresourcemanager, storage, sts)が有効であることを保証するリソースを定義する(新規プロジェクト作成リソースは含めない)
- [x] 1.2 [Claude] GitHub Actions用Workload Identity Pool/Provider(`github-actions-pool-dns`等)を、このリポジトリの`attribute_condition`に限定して定義する
- [x] 1.3 [Claude] Terraform CI用サービスアカウント(`terraform-ci-dns`等)を作成し、Cloud DNS管理ロールとtfstateバケットへの`storage.objectAdmin`のみを付与する
- [x] 1.4 [Claude] tfstate用GCSバケット(`kuchida-devel-dns-tfstate`等、バージョニング有効・`public_access_prevention: enforced`)を定義する
- [x] 1.5 [ユーザー] `terraform/bootstrap`をローカルで`terraform apply`し、出力(CI用サービスアカウント、WIFプロバイダ、tfstateバケット名)を記録する。姉妹リポジトリと同じく、プロジェクト権限が必要なbootstrapのみ手動apply、`terraform/main`はCI経由にする方針(実施メモ: 初回applyは`gcloud auth application-default login`未実施でADCの認証が古い/不足しており403エラーで失敗。ログイン後に再applyして成功)

## 2. Cloud DNSゾーン・レコードの定義(terraform/main、[Claude]がコード作成)

- [x] 2.1 `terraform/main`のバックエンド設定(bootstrapで作成したGCSバケット)を構成する
- [x] 2.2 `google_dns_managed_zone`でu-rei.comゾーンを定義する
- [x] 2.3 apex(u-rei.com)のAレコード×4(185.199.108.153/.109.153/.110.153/.111.153)を`google_dns_record_set`で定義する
- [x] 2.4 `www.u-rei.com`・`skk.u-rei.com`のCNAMEレコード(→kuchida1981.github.io)を定義する
- [x] 2.5 `n8n.u-rei.com`のAレコード(n8n-opsの静的External IP)を定義する
- [x] 2.6 `vaultwarden.u-rei.com`のAレコード(vaultwarden-hostingの静的External IP)を定義する
- [x] 2.7 `brevo1._domainkey`・`brevo2._domainkey`のCNAMEレコードを定義する
- [x] 2.8 apexのTXTレコード(brevo-code)と`_dmarc`のTXTレコードを定義する
- [x] 2.9 IPアドレス等の値をvariables.tf/tfvarsに切り出し、将来の他リポジトリからの更新PRが差分レビューしやすい形にする

## 3. 検証(切替前)

- [x] 3.1 [Claude/ユーザー] PRを立てCI(`terraform-plan.yml`)でレコード内容をレビューする(姉妹リポジトリと同じくPRコメントでplanを確認)(実施メモ: PR #1作成、CI planは10 to add・0 to change・0 to destroy。9レコード+ゾーン1件の値をお名前.comエクスポート原本と突合し完全一致を確認)
- [ ] 3.2 [ユーザー] PRをmainにマージし、CI(`terraform-apply.yml`、production環境の手動承認ゲート付き)でCloud DNS側にゾーンを構築、払い出されたネームサーバー4つを控える
- [ ] 3.3 [Claude] `dig @<Googleのネームサーバー>`で全レコード(apex A、www/skk CNAME、n8n/vaultwarden A、brevo DKIM CNAME、TXT、DMARC TXT)を問い合わせ、現行お名前.comゾーンの値と一致することを確認する

## 4. カットオーバー

- [ ] 4.1 [ユーザー] お名前.com管理画面でネームサーバー設定をGoogleの4つのネームサーバーに変更する
- [ ] 4.2 [Claude] 一般のパブリックリゾルバ(8.8.8.8等)経由で全レコードの解決を確認する
- [ ] 4.3 [Claude] n8n(n8n.u-rei.com)・vaultwarden(vaultwarden.u-rei.com)・ブログ(u-rei.com/www.u-rei.com)・web-skk(skk.u-rei.com)が正常にアクセスできることを確認する
- [ ] 4.4 [ユーザー] Brevo管理画面でDKIM/DMARC/ドメイン認証のステータスが有効なままであることを確認する
- [ ] 4.5 [ユーザー] 問題がある場合はお名前.com側のネームサーバー設定を元(01-04.dnsv.jp)に戻してロールバックする

## 5. 後片付け

- [x] 5.1 [Claude] `openspec/project.md`に確定したWIFプール名・サービスアカウント名・tfstateバケット名など運用情報を追記する
- [x] 5.2 [Claude] README.mdに運用手順(レコード追加方法、他リポジトリからの更新依頼フロー)を記載する
- [x] 5.3 [Claude] CIワークフロー(PR時terraform plan、マージ時terraform apply)を姉妹リポジトリ(n8n-ops, vaultwarden-hosting)に合わせて作成する
- [x] 5.4 [ユーザー] GitHubリポジトリのSecrets(`GCP_WORKLOAD_IDENTITY_PROVIDER`, `GCP_SERVICE_ACCOUNT_EMAIL`, `TF_STATE_BUCKET`, `GCP_PROJECT_ID`)とproduction環境の必須レビュアー設定をリポジトリ管理画面で登録する(`gh secret set`とSettings > Environmentsで実施。`gh api repos/kuchida1981/u-rei.com-dns/environments`で`production`環境・`required_reviewers`(kuchida1981)を確認済み)
