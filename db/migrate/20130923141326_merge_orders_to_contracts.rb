class MergeOrdersToContracts < ActiveRecord::Migration

  class Order < ActiveRecord::Base
    belongs_to :inventory_pool
    belongs_to :user
    has_many :order_lines, :order => 'start_date ASC, end_date ASC, created_at ASC'
  end

  class OrderLine < ActiveRecord::Base
    belongs_to :inventory_pool
    belongs_to :model
    belongs_to :purpose
  end

  def change

    status_map = {
        Order => {
            1 => :unsubmitted,
            2 => :submitted,
            4 => :rejected
        },
        Contract => {
            1 => :approved,
            2 => :signed,
            3 => :closed
        }
    }

    execute "ALTER TABLE contracts ADD COLUMN status ENUM('#{:unsubmitted}', '#{:submitted}', '#{:rejected}', '#{:approved}', '#{:signed}', '#{:closed}')"

    status_map[Contract].each_pair do |key, value|
      Contract.where(status_const: key).update_all(status: value)
    end

    change_table :contracts do |t|
      t.remove :status_const
      t.index :status
    end
    Contract.reset_column_information

    def order_lines_to_contract(lines, contract)
      lines.each do |ol|
        ol.quantity.times do
          contract.item_lines.create( model: ol.model,
                                      quantity: 1,
                                      start_date: ol.start_date,
                                      end_date: ol.end_date,
                                      purpose: ol.purpose,
                                      created_at: ol.created_at,
                                      updated_at: ol.updated_at )
        end
      end
    end

    status_map[Order].each_pair do |key, value|
      Order.where(status_const: key).each do |order|
        next if order.order_lines.empty?

        if value == :unsubmitted
          # TODO discuss these filters: ignore unsubmitted orders older than 1 month # with less than 20 lines
          next if order.order_lines.all? {|l| l.end_date < (Date.today - 1.month) } # and order.order_lines.count < 20

          order.order_lines.group_by {|ol| ol.inventory_pool }.each_pair do |inventory_pool, lines|
            contract = order.user.contracts.create( status: value,
                                                    inventory_pool: inventory_pool,
                                                    created_at: order.created_at,
                                                    updated_at: order.updated_at )
            order_lines_to_contract(lines, contract)
            History.where(target_type: "Order", target_id: order.id).update_all(target_type: "Contract", target_id: contract.id)
          end
        else
          # TODO discuss these filters: InventoryPool 44 is missing
          next unless order.inventory_pool

          contract = order.user.contracts.create( status: value,
                                                  inventory_pool: order.inventory_pool,
                                                  created_at: order.created_at,
                                                  updated_at: order.updated_at )
          order_lines_to_contract(order.order_lines, contract)
          History.where(target_type: "Order", target_id: order.id).update_all(target_type: "Contract", target_id: contract.id)
        end
      end
    end

    History.where(target_type: "Order").delete_all

    drop_table :order_lines
    drop_table :orders

  end
end