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

Set `CICERONE_SERVE_URL`, `CICERONE_SERVE_TOKEN`, and optionally `CICERONE_EVENTS_TOKEN`, `CICERONE_TRIGGER_URL`, `CICERONE_TRIGGER_TOKEN`, `CICERONE_DASHBOARD_URL`.

Admin: `/admin/cicerone` stores those URLs/tokens (Solidus preferences when available), queues an export, and queues a retrain. It does not clone Cicerone Quality / Experiments. Open the Cicerone dashboard from the link if you set `CICERONE_DASHBOARD_URL`.

First deploy: queue export, then queue retrain.

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

Give that role read-only access to those three tables. Models, blending, AutoML, eligibility, and `features.toml` stay in Cicerone. Extra columns such as `country` are there if you map them; this gem does not write `features.toml`.

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

Guests are requested as `__cold_start__`. Leave Cicerone `[serve].log_impressions` off (fetch ≠ view). Fetching recs does not record impressions.

Product views (signed-in only): `cicerone_record_view(variant)` on the product page. Reviews and wishlist `saved` events are recorded when those Solidus extensions are already loaded.

## Do not

- HTTP from checkout, or Python/CLI inside Puma
- Treat payment or stock machines as training events
- Use guest session ids as durable `user_id`
- Expect today’s new SKU in personalized lists
- Replace inventory, promotions, or merchandiser-curated related products
- Edit Cicerone TOML from Rails

## License

[Beerware](LICENSE) (Revision 42), same text as Cicerone.
