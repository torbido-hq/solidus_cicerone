# solidus_cicerone

Solidus host for [Cicerone](https://github.com/torbido-hq/cicerone). This gem interprets Solidus (ActiveRecord). HTTP goes through the [`cicerone`](https://github.com/torbido-hq/cicerone.rb) gem. It does not train, rank, or edit Cicerone TOML.

[Beerware](LICENSE) — same notice as Cicerone.

Home: [torbido-hq/solidus_cicerone](https://github.com/torbido-hq/solidus_cicerone). Later transfer to `solidusio-contrib` via Solidus Slack.

IDs: `user_id` = Solidus user id (text). `item_id` = variant id (text). Guests with nil `user_id` are dropped.

## Call pattern

1. **Nightly train = exported tables.** `ExportJob` writes `solidus_cicerone_events` / `_users` / `_items`. Author Cicerone’s three `[input] kind=db` SELECTs from those tables with ActiveRecord (see below). Cicerone config stays on the Cicerone deploy.
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

1. Point `[input] kind=db` at the **Solidus** database (read-only role). Paste the three SELECTs this gem authors — see [Cicerone input](#cicerone-input).
2. Match tokens:
   - serve `auth_token` = `CICERONE_SERVE_TOKEN`
   - events `auth_token` = `CICERONE_EVENTS_TOKEN` (or the serve token)
   - scheduler trigger token = `CICERONE_TRIGGER_TOKEN`
3. Leave `[serve].log_impressions` off. Fetch is not a view; this gem reports CTR after render.
4. Models, blending, AutoML, eligibility, and `features.toml` stay in Cicerone.

### First deploy

1. Migrate, set ENV, start a worker.
2. Queue export, wait until `solidus_cicerone_items` has rows.
3. Print `bin/rails solidus_cicerone:input` and paste `[input]` on the Cicerone deploy.
4. Queue retrain.
5. Render recs on the storefront (below).

## Cicerone input

Cicerone `[input]` kinds are `dataset` and `db`. It does not load ERb, ActiveRecord, or Rails. Author the three SELECTs in this Solidus app (AR `to_sql`, or ERb that prints SQL), then paste them into Cicerone TOML on the Cicerone deploy. Do not copy a full TOML from this gem.

The default contract is the export tables `ExportJob` writes. `SolidusCicerone::Input` compiles that SQL. After migrate, the export models also expose `cicerone_input` scopes, so adapter quoting comes from AR:

```ruby
SolidusCicerone::Input.events
# SELECT user_id, item_id, event_type, quantity, occurred_at FROM solidus_cicerone_events

SolidusCicerone::Event.cicerone_input.to_sql
SolidusCicerone::Input.events(SolidusCicerone::Event.cicerone_input)
```

Print a paste-ready `[input]` fragment (also shown at `/admin/cicerone`):

```sh
bin/rails solidus_cicerone:input
```

Or from ERb / `rails runner`:

```erb
<%= SolidusCicerone::Input.toml_fragment %>
```

Pass your own relation or SQL string when the default full-table SELECT is not what you want. The relation must project the contract columns (`user_id`, `item_id`, `event_type`, `quantity`, `occurred_at` / `user_id`, `country` / `item_id`, `category`, `published`, `in_stock`). `Input` compiles AR relations with `unprepared_statement` so `?` binds are inlined; Cicerone runs the finished `SELECT` as-is.

```ruby
scope = SolidusCicerone::Event.cicerone_input.where("occurred_at >= ?", 2.years.ago)
puts SolidusCicerone::Input.toml_fragment(events: scope)
```

Category, `published`, and `in_stock` are computed in Ruby during export (`Catalog`). Pointing Cicerone at live `spree_*` tables skips that denormalization; only do that if your own AR relation already projects the same contract.

Give the Cicerone role read-only access to those three tables. Extra columns such as `country` are there if you map them; this gem does not write `features.toml`.

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
