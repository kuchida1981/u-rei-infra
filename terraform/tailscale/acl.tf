# WARNING: `tailscale_acl` manages the tailnet's *entire* ACL policy file as a
# single resource - the Tailscale API has no partial-update endpoint, so
# whichever Terraform state applies this resource last wins and overwrites the
# whole file. This repository is the sole owner of this resource for the
# tailnet; vaultwarden-ops and n8n-ops only manage their own
# `tailscale_tailnet_key`, whose tag must already exist in `tagOwners` below
# before that key can be requested.
#
# Adding a new tailnet-connected service therefore means a PR to *this* file
# first, and only then to the service repository. Do not edit the ACL in the
# Tailscale console: the next apply would revert it.
#
# Notable points: (1) the first accept rule is scoped to tailnet members and
# the server tags rather than `*`, so tag:ci-blog-daily-post is deliberately
# NOT a source there and can only reach tag:claude-wrapper-server:18789 via
# the second rule; (2) `ssh` blocks restrict `tailscale ssh` into the
# vaultwarden/n8n tags to the tailnet admin only; (3) `tests` are validated by
# Tailscale on every save, guarding the ci-blog-daily-post isolation.
resource "tailscale_acl" "this" {
  acl = jsonencode({
    tagOwners = {
      "tag:vaultwarden-server"    = ["autogroup:admin"]
      "tag:n8n-server"            = ["autogroup:admin"]
      "tag:claude-wrapper-server" = ["autogroup:admin"]
      "tag:ci-blog-daily-post"    = ["autogroup:admin"]
    }
    acls = [
      {
        action = "accept"
        src = [
          "autogroup:member",
          "tag:n8n-server",
          "tag:vaultwarden-server",
          "tag:claude-wrapper-server",
        ]
        dst = ["*:*"]
      },
      {
        action = "accept"
        src    = ["tag:ci-blog-daily-post"]
        dst    = ["tag:claude-wrapper-server:18789"]
      }
    ]
    ssh = [
      {
        action = "check"
        src    = ["autogroup:admin"]
        dst    = ["tag:vaultwarden-server"]
        users  = ["autogroup:nonroot", "root"]
      },
      {
        action = "check"
        src    = ["autogroup:admin"]
        dst    = ["tag:n8n-server"]
        users  = ["autogroup:nonroot", "root"]
      }
    ]
    tests = [
      {
        src    = "tag:ci-blog-daily-post"
        accept = ["tag:claude-wrapper-server:18789"]
        deny = [
          "tag:claude-wrapper-server:22",
          "tag:vaultwarden-server:80",
          "100.65.90.127:5000",
        ]
      }
    ]
  })
}
