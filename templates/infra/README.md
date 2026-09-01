# infra テンプレート

Terraform modules の実体を置く。Cloudflare のトポロジと運用に関する判断は
[design.md](design.md) にある。

```
templates/infra/
  modules/<name>/    # プロダクトから参照される module
```

プロダクト側からは参照で使う。

```hcl
source = "git::https://github.com/uyaaaaaa/platform.git//templates/infra/modules/<name>?ref=v1"
```

コピー配布ではないため、他のテンプレートと違い `setup.sh` を持たない。プロダクト側で
実行すべきものが無く、参照先を書くだけで済むためである。ただし `docs/design.md` が
手動作業として残している state 用 R2 バケットとブートストラップ用 API トークンの作成は、
将来ここにスクリプトとして置く余地がある。

module はまだ無い。
