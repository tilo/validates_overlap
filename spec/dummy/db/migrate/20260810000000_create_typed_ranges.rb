class CreateTypedRanges < ActiveRecord::Migration[6.0]
  def self.up
    # integer ranges (e.g. ticket number blocks)
    create_table :number_ranges do |t|
      t.integer :range_start
      t.integer :range_end
      t.timestamps
    end

    # string ranges (e.g. alphabetical name partitions)
    create_table :name_ranges do |t|
      t.string :range_start
      t.string :range_end
      t.timestamps
    end

    # datetime ranges (time-of-day precision, e.g. appointments)
    create_table :appointments do |t|
      t.datetime :starts_at
      t.datetime :ends_at
      t.timestamps
    end

    # timestamp ranges (t.timestamp maps to the adapter's TIMESTAMP type)
    create_table :maintenance_windows do |t|
      t.timestamp :starts_at
      t.timestamp :ends_at
      t.timestamps
    end

    # decimal ranges (e.g. price bands)
    create_table :price_bands do |t|
      t.decimal :range_start, precision: 10, scale: 2
      t.decimal :range_end, precision: 10, scale: 2
      t.timestamps
    end
  end

  def self.down
    drop_table :number_ranges
    drop_table :name_ranges
    drop_table :appointments
    drop_table :maintenance_windows
    drop_table :price_bands
  end
end
