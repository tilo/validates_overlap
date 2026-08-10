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
  end

  def self.down
    drop_table :number_ranges
    drop_table :name_ranges
  end
end
