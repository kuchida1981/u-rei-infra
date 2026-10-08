## 1. 事前確認

- [x] 1.1 新リポジトリ名を確定する(既定案 `u-rei-infra`)。ユーザーの承認を得たことを会話で確認する
- [x] 1.2 `terraform/bootstrap/terraform.tfstate` が最新であることを `terraform -chdir=terraform/bootstrap plan` で確認する(差分なし、または既知の差分のみ)
- [x] 1.3 vaultwarden-ops の保留中の apply を洗い出し、移行完了までは承認しないことを確認する(GitHub Actions の待機中ジョブ一覧)
- [x] 1.4 現行の ACL を Tailscale 管理コンソールまたは API から JSON で取得し、vaultwarden-ops の `tailscale_acl` の内容と一致することを確認する(差分なし)

## 2. WIF の二重許可とリポジトリのリネーム

- [x] 2.1 `terraform/bootstrap` の `attribute_condition` と `principalSet` を新旧両名を許可する形に変更し、`terraform apply` が成功することを確認する
- [x] 2.2 GitHub 上でリポジトリをリネームする。旧 URL が新 URL へリダイレクトされることを `git ls-remote` で確認する
- [x] 2.3 ローカルのクローンの remote とディレクトリ名を更新し、`git fetch` が成功することを確認する
- [x] 2.4 `terraform-plan.yml` を手動実行(またはダミー PR)し、WIF 認証が通ることを確認する
- [x] 2.5 `github_repo` の既定値を新名称にし、旧名を外して bootstrap を再 apply する。旧名では認証できなくなったことを確認する
- [x] 2.6 README と `openspec/specs/*` の Purpose 内の旧リポジトリ名の記述を更新し、`grep -r "u-rei.com-dns"` で残りが意図したものだけであることを確認する

## 3. Tailscale 構成の追加(import 先行)

- [x] 3.1 Tailscale 管理コンソールで Policy File(write) のみの OAuth クライアントを新規発行し、このリポジトリの GitHub Secrets(`TAILSCALE_OAUTH_CLIENT_ID` / `TAILSCALE_OAUTH_CLIENT_SECRET` / `TAILSCALE_TAILNET`)に登録する。Secrets が一覧に表示されることを確認する
- [x] 3.2 `terraform/tailscale` を追加する(provider、GCS バックエンド prefix `tailscale/main`、vaultwarden-ops の現行 ACL をそのままコピーした `tailscale_acl`、`import` ブロック)。`terraform validate` が通ることを確認する
- [x] 3.3 `terraform-plan.yml` と `terraform-apply.yml` を `terraform/tailscale` に対応させ(paths、Tailscale 用の環境変数)、承認ゲート付きであることを確認する
- [x] 3.4 ローカルまたは CI で `terraform plan` を実行し、"1 to import, 0 to add, 0 to change, 0 to destroy" となることを確認する(差分があれば apply せず 1.4 に戻る)
- [x] 3.5 PR を merge して apply を承認し、完了後に再度 `terraform plan` が差分なしであること、管理コンソールの ACL が変化していないことを確認する

## 4. vaultwarden-ops 側の除去

- [x] 4.1 vaultwarden-ops の `terraform/main` は既に `required_version = ">= 1.7.0"` だったため、引き上げは不要。`terraform validate` が通ることを確認した
- [x] 4.2 `terraform/modules/tailscale/main.tf` から `tailscale_acl` を削除し、同ファイル内に `removed { from = tailscale_acl.this  lifecycle { destroy = false } }` を置いた(モジュール内に置く形が使えた)。PR の plan が "will no longer be managed ... will not be destroyed"、`0 to destroy` であることを確認した
- [x] 4.3 PR を merge して apply を承認し、完了後に管理コンソールの ACL が変化していないこと、このリポジトリの `terraform plan` が差分なしであることを確認する
- [x] 4.4 vaultwarden-ops の `tailscale.tf` 内のコメントと README(OAuth スコープ、タグ追加手順)を「ACL は基盤リポジトリが所有する」という内容に更新する

## 5. OAuth クライアントの権限分離

- [x] 5.1 Auth Keys(write) のみ、タグを `tag:vaultwarden-server` に限定した OAuth クライアントを発行し、vaultwarden-ops の Secrets を差し替える。`terraform plan` が認証エラーなく通ることを確認する
- [x] 5.2 同様に `tag:n8n-server` 用のクライアントを発行し、n8n-ops の Secrets を差し替える。`terraform plan` が認証エラーなく通ることを確認する
- [x] 5.3 旧 OAuth クライアント(Policy File スコープ付き)を管理コンソールで失効させ、vaultwarden-ops / n8n-ops の CI が引き続き成功することを確認する

## 6. 仕上げ

- [ ] 6.1 `tests` が隔離を守ることを、**保存せずに**確認する。管理コンソールの ACL エディタで、1つ目の accept ルールの `src` に `tag:ci-blog-daily-post` を足し(保存はしない)、`tag:claude-wrapper-server:22` が到達可能になることで `tests` の検証エラーが表示されることを確認する(`terraform plan` は ACL を API で検証しないため、plan/apply での確認は行わない。apply で試すと、検証が働かなかった場合に本番の ACL が緩むため)
- [x] 6.2 このリポジトリの README に、タグ追加手順(基盤側を先に merge、サービス側は後)とコンソール手編集の禁止を記載する
- [x] 6.3 `openspec validate tailscale-acl-ownership --strict` が通ることを確認する
