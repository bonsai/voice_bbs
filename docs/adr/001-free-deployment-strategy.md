# ADR-001: bubble-voice 無料運用デプロイ戦略

- **Status:** Proposed
- **Date:** 2026-07-18
- **Deciders:** onsen.bonsai

## Context

bubble-voice (voice_bbs) は Elixir 1.17 + Phoenix 1.7.14 + LiveView の音声掲示板アプリ。
PostgreSQL (Ecto) + ファイルシステム (PNG音声) を使用。
WebSocket (LiveView) が必須。常時稼働が望ましい。

既存のデプロイ:
- Railway: `bubblevoice.up.railway.app` — Trial期限切れ、認証不要
- Fly.io: `bubble-voice` — Trial終了（クレジットカード未登録）
- Render: render.yaml設定済み — 未デプロイ

## 候補プラットフォーム比較

### 1. GCP Cloud Run (推奨)

| 項目 | 内容 |
|------|------|
| **無料枠** | 月2Mリクエスト、240,000 vCPU-sec、450,000 GiB-sec |
| **WebSocket** | 対応（最大60分タイムアウト） |
| **PostgreSQL** | Cloud SQL（有料） or 外部DB |
| **Docker** | ネイティブ対応（既存Dockerfileそのまま） |
| **拡張性** | オートスケール、scale-to-zero対応 |
| **DB以外の費用** | 無料枠内で完結（低トラフィックなら） |

**見積もり（低トラフィック運用）:**
- vCPU: 1 vCPU × 30日 × 24h = 2,592,000 sec → 240,000 free → 2,352,000 sec 超過
- ただし always-on CPU を使わず request-only にすれば、リクエスト時のみ課金
- 月間リクエスト数次第だが、低トラフィックなら無料枠内に収まる可能性あり
- **Cloud SQL（最小構成db-f1-micro）: 月$7.67** ← これが最大のコスト

**メリット:**
- WebSocket対応済み（公式ドキュメントあり）
- Dockerfileそのままデプロイ可能
- オートスケール、レプリカ拡張
- Cloud Logging, Cloud Monitoring統合
- HTTPS自動提供

**デメリット:**
- Cloud SQLは無料枠なし（外部PostgreSQL serviceを使えば回避可能）
- Cloud Run自体は無料枠があるが、DBがネック

### 2. Cloudflare Containers

| 項目 | 内容 |
|------|------|
| **無料枠** | Workers Paid必須（$5/月）、Containers無料枠付き |
| **WebSocket** | Durable Objects経由で対応 |
| **PostgreSQL** | D1 (SQLite) or 外部DB |
| **Docker** | 対応（wrangler deploy） |
| **エッジ** | 300+都市にグローバル配信 |

**見積もり:**
- Workers Paid: $5/月
- Container: lite (256MiB) で常時稼働 → CPU/Memory課金
  - 月間: ~$1.94（低利用時）
- **合計: $5 + $1.94 = $6.94/月**

**メリット:**
- エッジ配信（低レイテンシ）
- Scale-to-zero対応
- D1による分散SQLite

**デメリット:**
- Workers Paid $5/月が必須（無料ではない）
- Elixir/PhoenixをCF Containersで動かす実績が少ない
- D1はSQLite（PostgreSQL直接使用不可）
- アーキテクチャ変更が必要

### 3. Railway (Free Plan)

| 項目 | 内容 |
|------|------|
| **無料枠** | $1/月クレジット（非ロールオーバー） |
| **リソース** | 1 vCPU, 0.5 GB RAM, 1プロジェクト |
| **PostgreSQL** | 有料（クレジット内に収まらない） |
| **WebSocket** | 対応 |

**見積もり:**
- アプリ: ~$0.80-1.00/月（最小構成）
- DB: クレジット超過 → 停止

**メリット:**
- シンプル、GitHub連携
- Dockerfile対応

**デメリット:**
- **$1/月クレジットではDB+アプリ同時運用不可**
- アプリのみならギリギリ

### 4. Render (Free Tier)

| 項目 | 内容 |
|------|------|
| **無料枠** | Web Service無料、PostgreSQL無料（30日期限） |
| **スピンダウン** | 15分無通信で停止、30-60秒コールドスタート |
| **PostgreSQL** | 30日で自動削除 |
| **WebSocket** | 無料プランでは不安定 |

**メリット:**
- 完全無料（短期間）
- Dockerfile対応

**デメリット:**
- **15分でスピンダウン → WebSocket切断**
- **PostgreSQL 30日で削除**
- コールドスタート30-60秒
- 永続運用には不適切

### 5. Fly.io

| 項目 | 内容 |
|------|------|
| **無料枠** | 新規ユーザー: トライアル2時間のみ |
| **既存ユーザー** | 祖父規定で旧無料枠あり（当該なし） |
| **PostgreSQL** | 有料（$14+/月） |

**デメリット:**
- **トライアル終了済み**
- クレジットカード必須
- 実質$15-25/月

## 比較表

| プラットフォーム | 月額 | DB含む | WebSocket | 永続運用 | 難易度 |
|-----------------|------|--------|-----------|----------|--------|
| **GCP Cloud Run** | $0-7.67 | Cloud SQL有料 | ○ | ○ | 中 |
| **CF Containers** | $6.94 | D1のみ | ○ | ○ | 高 |
| **Railway Free** | $0-1 | △ | ○ | × | 低 |
| **Render Free** | $0 | 30日削除 | × | × | 低 |
| **Fly.io** | $15-25 | 有料 | ○ | ○ | 中 |

## Decision

**GCP Cloud Run + 外部PostgreSQL** を推奨。

理由:
1. Cloud Run自体は無料体は無料枠が豊富（低トラフィックなら$0）
2. PostgreSQLは外部サービスで回避可能:
   - **Neon** (serverless PostgreSQL): 無料枠 0.5 GB, 24/7接続
   - **Supabase** (PostgreSQL): 無料枠 500 MB
   - **Aiven** (PostgreSQL): 無料枠 1ヶ月トライアル
3. 既存Dockerfileがそのまま使える
4. WebSocket公式対応
5. オートスケール、レプリカ対応
6. セキュリティ: IAM, VPC接続

**替代案:** Railway Hobby ($5/月) ならDB込みで運用可能。
月$5でPostgreSQL + アプリ同時運用が安定するなら、手軽さ重視でこちら也可。

## Consequences

### 正面
- 安定した永続運用が可能
- WebSocket切断問題なし（Cloud Run）
- スケーラビリティ（将来的に拡張可能）
- GCPエコシステム活用（Logging, Monitoring）

### 負面
- GCPコンソール設定が必要（初回）
- Cloud SQL使う場合は月$7.67追加
- Dockerfileの微調整が必要な場合あり（PORT, DATABASE_URL）
- Neon/Supabaseを使う場合は外部DB管理が必要

## 実装ステップ

1. GCPプロジェクト作成 + Cloud Run API有効化
2. Neon で PostgreSQL データベース作成（無料枠）
3. `config/runtime.exs` で DATABASE_URL 環境変数対応確認
4. Dockerfile確認・ビルド
5. `gcloud run deploy` でデプロイ
6. 璯境変数設定 (DATABASE_URL, SECRET_KEY_BASE, PHX_HOST)
7. `/api/migrate` でDBマイグレーション実行
8. 動作確認

## 参照

- [Cloud Run Pricing](https://cloud.google.com/run/pricing)
- [Cloud Run WebSocket](https://docs.cloud.google.com/run/docs/triggering/websockets)
- [Neon Free Tier](https://neon.tech/docs/introduction/plans)
- [Supabase Free Tier](https://supabase.com/pricing)
