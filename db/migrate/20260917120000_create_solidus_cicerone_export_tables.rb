# frozen_string_literal: true

class CreateSolidusCiceroneExportTables < ActiveRecord::Migration[6.1]
  def change
    create_table :solidus_cicerone_events do |t|
      t.string :user_id, null: false
      t.string :item_id, null: false
      t.string :event_type, null: false
      t.integer :quantity, null: false, default: 1
      t.datetime :occurred_at, null: false
      t.string :event_id, null: false
      t.timestamps
    end
    add_index :solidus_cicerone_events, :event_id, unique: true
    add_index :solidus_cicerone_events, :event_type
    add_index :solidus_cicerone_events, :user_id

    create_table :solidus_cicerone_users do |t|
      t.string :user_id, null: false
      t.string :country
      t.timestamps
    end
    add_index :solidus_cicerone_users, :user_id, unique: true

    create_table :solidus_cicerone_items do |t|
      t.string :item_id, null: false
      t.string :category
      t.boolean :published, null: false, default: false
      t.boolean :in_stock, null: false, default: false
      t.timestamps
    end
    add_index :solidus_cicerone_items, :item_id, unique: true
  end
end
