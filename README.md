# solidus_cicerone

Thin Rails sidecar for [Cicerone](https://github.com/torbido-hq/cicerone). Cicerone stays a Docker job + serve process. This gem maps Solidus IDs onto Cicerone HTTP/SQL. It does not train or rank.

Intended home: [solidusio-contrib/solidus_cicerone](https://github.com/solidusio-contrib/solidus_cicerone).

IDs: `user_id` = Solidus user id (text). `item_id` = variant id (text). Guests with nil `user_id` are dropped.

## Call pattern

1. **Nightly train = SQL.** Cicerone `[input] kind=db` over completed `spree_line_items` (complete orders, signed-in users). See `examples/cicerone.solidus.toml`.
2. **Storefront read = `GET /recommendations/{user_id}`** (Bearer). Short cache. Filter live `variant.in_stock?` in Rails. Guests use `__cold_start__`.
3. **Same-day purchases = enqueue `POST /events`.** `Spree::Bus` `:order_finalized` → ActiveJob. Checkout does not wait. `event_id` = `#{order.number}:#{line_item.id}`.
4. **CTR = enqueue `POST /track`.** Impressions (after render) and clicks only — never training.
5. **Retrain = cron / admin button.** `POST /trigger/retrain` after catalog import or first deploy, not per order.

## Install

Add to the store Gemfile (path or git until the contrib repo exists):

```ruby
gem "solidus_cicerone", github: "solidusio-contrib/solidus_cicerone"
```

```sh
bin/rails generate solidus_cicerone:install
```

Set `CICERONE_SERVE_URL`, `CICERONE_SERVE_TOKEN`, and optionally `CICERONE_EVENTS_TOKEN`, `CICERONE_TRIGGER_URL`, `CICERONE_TRIGGER_TOKEN`, `CICERONE_DASHBOARD_URL`.

Admin: `/admin/cicerone` stores those URLs/tokens (Solidus preferences when available) and can queue a retrain. It does not clone Cicerone Quality / Experiments.

## Storefront

```erb
<% recs = cicerone_recommendations(limit: 8) %>
<% recs.items.each do |row| %>
  <%= link_to row.variant.product.name, row.variant.product,
        data: { method: :post, url: cicerone_track_path(item_id: row.item_id, rank: row.rank) } %>
<% end %>
```

Guests are requested as `__cold_start__`. Leave Cicerone `[serve].log_impressions` off (fetch ≠ view).

Optional `cart_add` / `view` / reviews / wishlist events: build with `SolidusCicerone::EventPayload.interaction` and `SolidusCicerone.enqueue_track` is wrong for training — use `PostEventsJob` / `client.post_events` for those. Do not POST `/track` as training.

## Do not

- HTTP from checkout, or Python/CLI inside Puma
- Treat payment or stock machines as training events
- Use guest session ids as durable `user_id`
- Expect today’s new SKU in personalized lists
- Replace inventory, promotions, or merchandiser-curated related products
