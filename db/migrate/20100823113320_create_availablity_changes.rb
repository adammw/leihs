class CreateAvailablityChanges < ActiveRecord::Migration
  def self.up
    create_table :availability_changes do |t|
      t.date       :date
      t.belongs_to :inventory_pool
      t.belongs_to :model

      t.timestamps
    end

    change_table :availability_changes do |t|
      t.index [:date, :inventory_pool_id, :model_id], :unique => true, :name => "index_on_date_and_inventory_pool_and_model"
      t.index [:inventory_pool_id, :model_id], :name => "index_on_inventory_pool_and_model"
    end


    create_table :availability_quantities do |t|
      t.belongs_to :availability_change
      t.belongs_to :group
      t.integer    :in_quantity, :default => 0
      t.integer    :out_quantity, :default => 0
      t.text       :documents # serialize
    end

    change_table :availability_quantities do |t|
      t.index [:availability_change_id, :group_id, :in_quantity], :name => "index_on_availability_chang_and_group_and_in_quantity"
    end


    Availability2::Change.recompute_all
    
  end

  def self.down
    drop_table :availability_changes
    drop_table :availability_quantities
  end
end

