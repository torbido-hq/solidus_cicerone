# solidus_cicerone

Solidus host for [Cicerone](https://github.com/torbido-hq/cicerone). This gem interprets Solidus (ActiveRecord) and speaks Cicerone’s public contract. It does not train, rank, or edit Cicerone TOML.

[Beerware](LICENSE) — same notice as Cicerone.

Home: [torbido-hq/solidus_cicerone](https://github.com/torbido-hq/solidus_cicerone). Later transfer to `solidusio-contrib` via Solidus Slack.

IDs: `user_id` = Solidus user id (text). `item_id` = variant id (text). Guests with nil `user_id` are dropped.

## Call pattern

1. **Nightly train = exported tables.** `ExportJob` writes `solidus_cicerone_events` / `_users` / `_items`. Point Cicerone `[input] kind=db` at those tables (see below). Cicerone config stays on the Cicerone deploy.
2. **Storefront read = `GET /recommendations/{user_id}`** (Bearer). Short cache. Filter live `variant.in_stock?` in Rails. Guests use `__cold_start__`.
3. **Same-day events = upsert export + `POST /events`.** Purchases (`:order_finalized`) and cart adds (`Spree::LineItem` create) go through `SolidusCicerone.record_event`. Checkout does not wait.
4. **CTR = `POST /track` after render.** Call `cicerone_record_impressions(recs)` once the widget is on the page. Clicks use `cicerone_track_path` with the recs experiment fields. Never training.
5. **Retrain = cron / admin button.** `POST /trigger/retrain` after the first export, a catalog import, or a deploy — not per order.

## Install

Add to the store Gemfile:

```ruby
gem "solidus_cicerone", github: "torbido-hq/solidus_cicerone"
```

```sh
bin/rails generate solidus_cicerone:install
bin/rails db:migrate
```

The generator copies `config/initializers/solidus_cicerone.rb` and the export-table migrations. Then configure Rails and Cicerone as below.

## Configure

Two processes, two configs. Rails talks HTTP to Cicerone and writes export tables. Cicerone reads those tables and serves rankings. Do not put Cicerone TOML in the Solidus app.

### Rails environment

Set these on the Solidus host (initializer reads them; you can also assign the same keys in `SolidusCicerone.configure`).

| Key | ENV | Default | Used for |
| --- | --- | --- | --- |
| `serve_url` | `CICERONE_SERVE_URL` | — | `GET /recommendations/{user_id}`, `POST /events`, `POST /track` |
| `serve_token` | `CICERONE_SERVE_TOKEN` | — | Bearer for serve and track |
| `events_token` | `CICERONE_EVENTS_TOKEN` | `serve_token` | Bearer for `POST /events` |
| `trigger_url` | `CICERONE_TRIGGER_URL` | — | `POST /trigger/retrain` on the **scheduler**, not serve |
| `trigger_token` | `CICERONE_TRIGGER_TOKEN` | — | Bearer for retrain |
| `dashboard_url` | `CICERONE_DASHBOARD_URL` | — | Admin “Open dashboard” link only |
| `cache_ttl` | `CICERONE_CACHE_TTL` | `45` | `Rails.cache` TTL for rec fetches (seconds) |
| `default_limit` | `CICERONE_DEFAULT_LIMIT` | `10` | Storefront limit when the helper omits `limit:` |
| `enabled` | `CICERONE_ENABLED` | on (`false` / `0` disables) | Kill switch for recs, export, retrain |

Minimum to fetch recs: `CICERONE_SERVE_URL` and `CICERONE_SERVE_TOKEN`. Same-day events use `events_token` (or the serve token). Retrain needs `trigger_url` (and usually `trigger_token`).

```ruby
# config/initializers/solidus_cicerone.rb
SolidusCicerone.configure do |config|
  config.serve_url = ENV.fetch("CICERONE_SERVE_URL", nil)
  config.serve_token = ENV.fetch("CICERONE_SERVE_TOKEN", nil)
  config.events_token = ENV.fetch("CICERONE_EVENTS_TOKEN", nil)
  config.trigger_url = ENV.fetch("CICERONE_TRIGGER_URL", nil)
  config.trigger_token = ENV.fetch("CICERONE_TRIGGER_TOKEN", nil)
  config.dashboard_url = ENV.fetch("CICERONE_DASHBOARD_URL", nil)
end
```

`cache_ttl`, `default_limit`, and `enabled` stay on their ENV defaults unless you assign them in this block. Do not hard-code `45` / `10` / `true` here if you want `CICERONE_CACHE_TTL`, `CICERONE_DEFAULT_LIMIT`, or `CICERONE_ENABLED` to apply.

`enabled` stops recommendation fetches, `ExportJob`, `RetrainJob`, and the HTTP event/track jobs. `record_event` still writes the local export row so a later export is not missing history.

### Event store

After `db:migrate`, Rails uses the ActiveRecord backend when `solidus_cicerone_events` exists. Until then it is `Null` (in-process no-op). Same-day `record_event` upserts into `solidus_cicerone_events`; `ExportJob` rebuilds users, items, and purchase/review/saved rows.

### Background jobs

Jobs use ActiveJob queue `default`. Run a worker.

| Job | When |
| --- | --- |
| `ExportJob` | Nightly (and first deploy / catalog import) |
| `RetrainJob` | After a successful export |
| `PostEventsJob` | Purchase, cart add, view, review, wishlist |
| `PostTrackJob` | Impressions after render, clicks on `POST /cicerone/track` |

Schedule export, then retrain. Not per order.

```sh
bin/rails runner 'SolidusCicerone.enqueue_export'
bin/rails runner 'SolidusCicerone.enqueue_retrain'
```

Admin **Queue export** / **Queue retrain** at `/admin/cicerone` do the same.

### Admin vs ENV

`/admin/cicerone` can override URLs and tokens. Those values are stored as Solidus preferences (`solidus_cicerone/…`) when `Spree::Preferences::Store` is available, and they win over the initializer at request time.

`cache_ttl`, `default_limit`, and `enabled` are read from the initializer / ENV on boot. Saving them in admin updates the current process; set them in ENV or the initializer so they survive restart.

Admin does not clone Cicerone Quality or Experiments. It does not edit Cicerone TOML.

### Cicerone (the other process)

On the Cicerone deploy, not in Rails:

1. Point `[input] kind=db` at the **Solidus** database (read-only role, three tables). See [Cicerone input](#cicerone-input).
2. Match tokens:
   - serve `auth_token` = `CICERONE_SERVE_TOKEN`
   - events `auth_token` = `CICERONE_EVENTS_TOKEN` (or the serve token)
   - scheduler trigger token = `CICERONE_TRIGGER_TOKEN`
3. Leave `[serve].log_impressions` off. Fetch is not a view; this gem reports CTR after render.
4. Models, blending, AutoML, eligibility, and `features.toml` stay in Cicerone.

### First deploy

1. Migrate, set ENV, start a worker.
2. Queue export, wait until `solidus_cicerone_items` has rows.
3. Queue retrain.
4. Render recs on the storefront (below).

## Cicerone input

On the Cicerone host, point `[input]` at the Solidus database. Do not copy a full TOML from this gem.

```toml
[input]
kind = "db"

[input.options]
database_url = "${SOLIDUS_DATABASE_URL}"
events_query = "SELECT user_id, item_id, event_type, quantity, occurred_at FROM solidus_cicerone_events"
users_query = "SELECT user_id, country FROM solidus_cicerone_users"
items_query = "SELECT item_id, category, published, in_stock FROM solidus_cicerone_items"
```

Give that role read-only access to those three tables. Extra columns such as `country` are there if you map them; this gem does not write `features.toml`.

## Storefront

```erb
<% recs = cicerone_recommendations(limit: 8) %>
<% recs.items.each do |row| %>
  <%= link_to row.variant.product.name, row.variant.product,
        data: { method: :post, url: cicerone_track_path(
          item_id: row.item_id,
          rank: row.rank,
          experiment_id: recs.experiment_id,
          variant: recs.variant,
          generated_at: recs.generated_at
        ) } %>
<% end %>
<% cicerone_record_impressions(recs) %>
```

`cicerone_recommendations` takes `user:` (default `spree_current_user`), `limit:`, `category:`, and `exclude_unavailable:` (default `true`). Guests are requested as `__cold_start__`. Do not pass `track: true` if you call `cicerone_record_impressions` after render — that would double-count.

Product views (signed-in only): `cicerone_record_view(variant)` on the product page. Reviews and wishlist `saved` events are recorded when those Solidus extensions are already loaded (`Spree::Review`, `Spree::WishedItem` / `Spree::WishlistItem`). This gem does not add those gems.

## Do not

- HTTP from checkout, or Python/CLI inside Puma
- Treat payment or stock machines as training events
- Use guest session ids as durable `user_id`
- Expect today’s new SKU in personalized lists
- Replace inventory, promotions, or merchandiser-curated related products
- Edit Cicerone TOML from Rails

## License

[Beerware](LICENSE) (Revision 42), same text as Cicerone.
