## Context

動機は proposal.md の Why を参照。現状の制約は次のとおり。

- `tailscale_acl` は vaultwarden-ops の `terraform/modules/tailscale/main.tf` に1つだけ存在し、`overwrite_existing_content = true` で tailnet の ACL 全体を管理している。n8n-ops は `tailscale_tailnet_key` のみを持つ。
- このリポジトリは `terraform/bootstrap`(ローカル state、手動 apply、1回限り)と `terraform/main`(GCS バックエンド、prefix `dns/main`、GitHub Actions で承認ゲート付き apply)の2段構成。WIF の `attribute_condition` は `github_repo` 変数(既定 `kuchida1981/u-rei.com-dns`)と完全一致で絞っている。
- state バケット(`<project>-dns-tfstate`)とサービスアカウント(`terraform-ci-dns`)、WIF プール(`github-actions-pool-dns`)の名前は DNS 前提だが、リソース名はリネームしても機能上の影響はない。

## Goals / Non-Goals

**Goals:**
- ACL の所有権を無停止で移し、移行中に ACL が1秒もデフォルトに戻らない
- 移行後は ACL の変更経路がこのリポジトリの PR のみになる
- Policy File 権限を持つ認証情報の保管先をこのリポジトリに限定する

**Non-Goals:**
- ACL の内容(タグ、ルール、ssh、tests)そのものの変更。移行では現状の内容を一字一句保つ
- Tailscale の認証キー(`tailscale_tailnet_key`)の移管。各サービスのリポジトリに残す
- 既存リソース名(バケット、SA、WIF プール)のリネーム。`terraform-ci-dns` 等は名前が古いまま残ることを許容する
- tailnet 自体の作成や DNS 設定(MagicDNS 等)の管理

## Decisions

**1. 構成は `terraform/tailscale` を独立したルートモジュール(独立した state)にする。**
`terraform/main` に同居させず、state prefix は `tailscale/main`、ワークフローも別にする。DNS の apply と ACL の apply は影響範囲と失敗時の被害が違い(ACL を誤ると全サービスの疎通が切れる)、承認の単位も分けたいため。代替案の「`terraform/main` に同居」は、DNS 変更の apply が ACL を巻き込むので採らない。

**2. 移行は import 先行、除去後行の順序にする。**
1. このリポジトリで `import` ブロックにより既存 ACL を取り込み、`plan` が差分なしになることを確認してから apply する。
2. 次に vaultwarden-ops で `tailscale_acl` をコードから削除し、`removed { from = ...; lifecycle { destroy = false } }` を置く。

逆順だと、その間に ACL を管理する state が存在しない。また `removed` を置かずにコードを消すと destroy が走り、デフォルト ACL に戻るため必ず `destroy = false` を使う。`removed` ブロックが child module 内のリソースを `from` に取れない場合は、`terraform state rm` を手動で実行する(承認ゲートの外で1回だけ)。`removed` は Terraform 1.7 以上が必要で、vaultwarden-ops は現在 `>= 1.6` なので引き上げが要る。

**3. 移行中は両リポジトリの ACL 管理が同時に存在する。そのため vaultwarden-ops の apply を止める。**
vaultwarden-ops の apply は承認ゲート付きなので、移行期間(手順1の開始から手順2の完了まで)は承認しないことで競合を避ける。dependabot の PR が merge されても apply が承認待ちで止まるだけである。ACL の中身は同一なので、万一両方が apply しても内容は同じになる。

**4. リポジトリ名の変更は、WIF を一時的に新旧両方を許可してから行う。**
`attribute_condition` を新旧両名の `||` にして先に bootstrap を apply し、GitHub 上でリネームし、確認後に旧名を外す。リネーム直後から CI が壊れる期間をなくす。bootstrap は手動・ローカル state なので、手元の `terraform.tfstate` が現行であることを事前に確認する。新名称は `u-rei-infra` を既定とし、確定は実装時に行う。

**5. OAuth クライアントは用途で2つに分ける。**
このリポジトリ用に Policy File(write) のクライアントを新規発行する。vaultwarden-ops・n8n-ops 用は Auth Keys(write) のみのクライアントに差し替える(タグは各サービスのタグに限定)。ACL 変更権限を持つ秘密情報をこのリポジトリの Secrets に閉じ込めるため。

## Risks / Trade-offs

- [import 前に誤って ACL が置換される] → 手順1で plan が差分なしになるまで apply しない。import する構成は vaultwarden-ops の現行内容をそのままコピーし、`overwrite_existing_content` は付けない
- [`removed` が効かず destroy が走る] → vaultwarden-ops で `plan` を実行し、`tailscale_acl` が destroy ではなく "will no longer be managed" と表示されることを確認してから merge する
- [Tailscale の保存時 `tests` が現状の ACL と矛盾して apply が失敗する] → import 時の plan で検出される。`tests` の内容は現状を維持する
- [WIF の切替ミスで CI が認証できなくなる] → 新旧両名を許可する中間状態を挟む(Decision 4)。最悪でもローカルから bootstrap を再 apply できる
- [タグ追加が2リポジトリにまたがる運用になる] → 現状と同じ制約であり、README に手順を明記する(基盤側を先に merge、サービス側は後)
- [バケット・SA 名に `dns` が残る] → 許容する。リネームは state の移し替えを伴い、得るものが少ない

## Migration Plan

1. 基盤側の準備(WIF の二重許可、`terraform/tailscale` と専用 OAuth クライアント)
2. GitHub でリポジトリをリネームし、remote とローカルパスを更新
3. 基盤側で ACL を import(plan 差分なし)して apply
4. vaultwarden-ops で `tailscale_acl` を `removed` に置換して merge
5. OAuth クライアントの差し替え(vaultwarden-ops / n8n-ops を Auth Keys のみへ)と README 更新

ロールバック: 手順3まで終えていれば、基盤側の ACL を vaultwarden-ops に戻す必要はない。手順4で問題が出た場合は vaultwarden-ops の変更を revert すれば、旧 state がそのまま ACL を管理する(ACL の中身は同一)。

## Open Questions

- 新しいリポジトリ名を `u-rei-infra` で確定してよいか(実装前にユーザー確認)
