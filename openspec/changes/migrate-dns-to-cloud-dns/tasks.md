## 1. GCPプロジェクトのbootstrap

- [ ] 1.1 新規GCPプロジェクトを作成し、課金アカウントを紐付ける
- [ ] 1.2 `terraform/bootstrap`を作成し、必要API(dns, iam, iamcredentials, cloudresourcemanager, storage, sts)を有効化するリソースを定義する
- [ ] 1.3 GitHub Actions用Workload Identity Pool/Providerを、このリポジトリの`attribute_condition`に限定して定義する
- [ ] 1.4 Terraform CI用サービスアカウントを作成し、Cloud DNS管理ロールとtfstateバケットへの`storage.objectAdmin`のみを付与する
- [ ] 1.5 tfstate用GCSバケット(バージョニング有効・`public_access_prevention: enforced`)を定義する
- [ ] 1.6 `terraform/bootstrap`をapplyし、出力(プロジェクトID、CI用サービスアカウント、tfstateバケット名)を記録する

## 2. Cloud DNSゾーン・レコードの定義(terraform/main)

- [ ] 2.1 `terraform/main`のバックエンド設定(bootstrapで作成したGCSバケット)を構成する
- [ ] 2.2 `google_dns_managed_zone`でu-rei.comゾーンを定義する
- [ ] 2.3 apex(u-rei.com)のAレコード×4(185.199.108.153/.109.153/.110.153/.111.153)を`google_dns_record_set`で定義する
- [ ] 2.4 `www.u-rei.com`・`skk.u-rei.com`のCNAMEレコード(→kuchida1981.github.io)を定義する
- [ ] 2.5 `n8n.u-rei.com`のAレコード(n8n-opsの静的External IP)を定義する
- [ ] 2.6 `vaultwarden.u-rei.com`のAレコード(vaultwarden-hostingの静的External IP)を定義する
- [ ] 2.7 `brevo1._domainkey`・`brevo2._domainkey`のCNAMEレコードを定義する
- [ ] 2.8 apexのTXTレコード(brevo-code)と`_dmarc`のTXTレコードを定義する
- [ ] 2.9 IPアドレス等の値をvariables.tf/tfvarsに切り出し、将来の他リポジトリからの更新PRが差分レビューしやすい形にする

## 3. 検証(切替前)

- [ ] 3.1 `terraform plan`でレコード内容をレビューする
- [ ] 3.2 `terraform apply`でCloud DNS側にゾーンを構築し、払い出されたネームサーバー4つを控える
- [ ] 3.3 `dig @<Googleのネームサーバー>`で全レコード(apex A、www/skk CNAME、n8n/vaultwarden A、brevo DKIM CNAME、TXT、DMARC TXT)を問い合わせ、現行お名前.comゾーンの値と一致することを確認する

## 4. カットオーバー

- [ ] 4.1 お名前.com管理画面でネームサーバー設定をGoogleの4つのネームサーバーに変更する
- [ ] 4.2 一般のパブリックリゾルバ(8.8.8.8等)経由で全レコードの解決を確認する
- [ ] 4.3 n8n(n8n.u-rei.com)・vaultwarden(vaultwarden.u-rei.com)・ブログ(u-rei.com/www.u-rei.com)・web-skk(skk.u-rei.com)が正常にアクセスできることを確認する
- [ ] 4.4 Brevo管理画面でDKIM/DMARC/ドメイン認証のステータスが有効なままであることを確認する
- [ ] 4.5 問題がある場合はお名前.com側のネームサーバー設定を元(01-04.dnsv.jp)に戻してロールバックする

## 5. 後片付け

- [ ] 5.1 `openspec/project.md`に実際に確定したGCPプロジェクトIDなど運用情報を追記する
- [ ] 5.2 README.mdに運用手順(レコード追加方法、他リポジトリからの更新依頼フロー)を記載する
- [ ] 5.3 CIワークフロー(PR時terraform plan、マージ時terraform apply)を姉妹リポジトリ(n8n-ops, vaultwarden-hosting)に合わせて設定する
