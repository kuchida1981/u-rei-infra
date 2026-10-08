## Why

Tailscale の `tailscale_acl` は tailnet 全体のポリシーを1リソースで丸ごと上書きする。現状この所有者は vaultwarden-ops だが、ACL は vaultwarden-ops・n8n-ops に加え、claude-wrapper-server や ci-blog-daily-post など別プロジェクトのタグ/ルールも含んでおり、所有リポジトリと実際の利用者が乖離している。その結果、コンソールでの手編集とのドリフトが発生し(vaultwarden-ops `8f65a4a` で事後的に取り込み)、放置すれば次の apply で手編集が消え `tag:ci-blog-daily-post` の隔離が破れる状況だった。tailnet は DNS と同じくサービスに属さないアカウント単位の共有基盤なので、すでに共有基盤を担うこのリポジトリで所有するのが自然である。

## What Changes

- このリポジトリを DNS 専用名(`u-rei.com-dns`)から共通基盤リポジトリ名(例: `u-rei-infra`)へリネームする
- `terraform/` 配下に Tailscale 用の構成を追加し、`tailscale_acl` をこのリポジトリが唯一のオーナーとして管理する(`tests` ブロックによる `ci-blog-daily-post` の隔離検証を含む)
- 既存 ACL は vaultwarden-ops の state から **destroy せずに** このリポジトリの state へ移す(先にここで import して plan 差分なしを確認し、その後 vaultwarden-ops 側を `removed { lifecycle { destroy = false } }` で state から外す)
- Tailscale OAuth クライアントを分離する: Policy File(write) はこのリポジトリ専用、vaultwarden-ops / n8n-ops は Auth Keys(write) のみとする
- WIF の `attribute_condition` と `github_repo` 変数、GitHub Secrets をリネーム後のリポジトリ名に合わせて更新する
- **BREAKING**: リネームにより、更新するまでこのリポジトリの GitHub Actions は WIF 認証に失敗する(`assertion.repository` が新名称になるため)

## Capabilities

### New Capabilities
- `tailscale-acl-ownership`: tailnet ACL の単一所有、state の移行手順(destroy を伴わない)、OAuth クライアントの権限分離、コンソール手編集の禁止と `tests` による検証を定める

### Modified Capabilities
- `gcp-project-bootstrap`: 「鍵レスなGitHub Actions認証」は、WIF の許可対象がリネーム後のリポジトリ名になる。「Terraform state用の専用GCSバケット」は、DNS に加えて Tailscale の state(別 prefix)も保持する前提に変わる

## Impact

- このリポジトリ: `terraform/bootstrap`(`github_repo` 既定値、WIF プール表示名)、`terraform/main`(Tailscale 構成の追加)、`.github/workflows/`(Tailscale 用 Secrets の追加)、`README.md`
- vaultwarden-ops: `terraform/modules/tailscale/main.tf` から `tailscale_acl` を除去(`removed` ブロック)。README のタグ/OAuth 手順の更新。OAuth スコープを Auth Keys のみへ縮小
- n8n-ops: OAuth クライアントを Auth Keys のみへ切り替え
- 外部: Tailscale 管理コンソールの OAuth クライアント再発行、GitHub のリポジトリリネーム(旧 URL はリダイレクトされるが、WIF の OIDC claim は新名称になる)、ローカルのクローンパスと git remote の更新
- リスク: 移行手順を誤ると ACL がデフォルトに戻り、全サービスの tailnet 疎通が切れる。import 後の plan 差分なしの確認を必須ゲートとする
