module Availability2
  class Change < ActiveRecord::Base
    set_table_name "availability_changes"

    belongs_to :inventory_pool
    belongs_to :model, :class_name => "::Model"
    has_many :availability_quantities, :dependent => :destroy,
                                       :class_name => "Availability2::Quantity",
                                       :foreign_key => "availability_change_id" do
                                         def general
                                           scoped_by_group_id(Group::GENERAL_GROUP_ID).first
                                         end
                                       end
  
    validates_presence_of :inventory_pool_id
    validates_presence_of :model_id
    validates_presence_of :date
  
    validates_uniqueness_of :date, :scope => [:inventory_pool_id, :model_id]
  
  #############################################
  
    default_scope :order => "date ASC, created_at ASC"
  
    named_scope :between,
                lambda { |start_date, end_date|
                         # start from most recent entry we have, which is the last before start_date
                         start_date = maximum(:date, :conditions => [ "date <= ?", start_date ]) || start_date.to_date
  
                         end_date = end_date.to_date
                         tmp_end_date = minimum(:date, :conditions => [ "date >= ?", start_date ])
                         end_date = [tmp_end_date, end_date].max if tmp_end_date
  
                         { :conditions => ["availability_changes.date BETWEEN ? AND ?", start_date, end_date] }
                }

    named_scope :overbooking,
                lambda { |inventory_pool, model|
                  conditions = ["availability_quantities.group_id IS NULL AND availability_quantities.in_quantity < 0"]
                  if inventory_pool
                    conditions[0] += " AND inventory_pool_id = ?"
                    conditions << inventory_pool
                  end
                  if model
                    conditions[0] += " AND model_id = ?"
                    conditions << model
                  end
                  { :select => "*, in_quantity",
                    :joins => :availability_quantities,
                    :conditions => conditions
                  }
                }
                             
  #############################################
  
    def self.new_partition(model, inventory_pool, group_partitioning)
      initial_change = model.availability_changes.reset_for_inventory_pool(inventory_pool)
      general_quantity = initial_change.availability_quantities.general

      group_partitioning.delete(Group::GENERAL_GROUP_ID) # the general group is computed on the fly, then we ignore it
      
      # TODO update future records (or prevent completely if it's breaking future availabilities) 
      group_partitioning.each_pair do |group_id, quantity|
        quantity = quantity.to_i
        # TODO get out_quantity and store only if sum > 0
        initial_change.availability_quantities.create(:group_id => group_id, :in_quantity => quantity) if quantity > 0
        general_quantity.in_quantity -= quantity
      end if group_partitioning
      general_quantity.save

      # TODO
      Availability2::Change.recompute(model, inventory_pool, false)
    end
  
    def self.recompute_all
      transaction do
        InventoryPool.all.each do |inventory_pool|
          inventory_pool.models.each do |model|
            recompute(model, inventory_pool)
          end
        end
      end
    end
  
    def self.recompute(model, inventory_pool, with_reset = true)
      model.availability_changes.reset_for_inventory_pool(inventory_pool) if with_reset
     
      reservations = model.running_reservations(inventory_pool)
      reservations.each do |document_line|
        recompute_reservation(document_line)
      end
      
      model.availability_changes.scoped_by_inventory_pool_id(inventory_pool)
    end
  
    def self.recompute_reservation(document_line)
      # OPTIMIZE
      model = document_line.model
      inventory_pool = document_line.inventory_pool
  
  
      start_change = clone_change(model, inventory_pool, document_line.start_date)
      end_change = clone_change(model, inventory_pool, document_line.end_date.tomorrow + model.maintenance_period.day)
  
      # TODO user maximum_available_in_period_for_user instead ??
      groups = document_line.document.user.groups.scoped_by_inventory_pool_id(inventory_pool) #tmp#
      maximum = maximum_available_in_period_for_groups(model, inventory_pool, groups, document_line.start_date, document_line.end_date)
      
      group_found = false
      # TODO sort groups by quantity desc
      groups.each do |group|
        if maximum[group.name] >= document_line.quantity
          update_changes(model, inventory_pool, group, document_line, start_change, end_change)
          group_found = true
          break
        end
      end

      #tmp#1
      update_changes(model, inventory_pool, Group::GENERAL_GROUP_ID, document_line, start_change, end_change) unless group_found
    end

    def self.update_changes(model, inventory_pool, group, document_line, start_change, end_change)
      inner_changes = model.availability_changes.scoped_by_inventory_pool_id(inventory_pool).all(:conditions => {:date => (start_change.date..end_change.date)})
      inner_changes.each do |ic|
        ic.availability_quantities.scoped_by_group_id(group).first.decrement(:in_quantity, document_line.quantity).increment(:out_quantity, document_line.quantity).add_document(document_line).save
      end
      
      end_change.availability_quantities.scoped_by_group_id(group).first.increment(:in_quantity, document_line.quantity).decrement(:out_quantity, document_line.quantity).remove_document(document_line).save
    end
    
    def self.clone_change(model, inventory_pool, date)
      # OPTIMIZE
      c = model.availability_changes.scoped_by_inventory_pool_id(inventory_pool).last(:conditions => ["date <= ?", date])
      c ||= model.availability_changes.current_for_inventory_pool(inventory_pool)
   
      if c.date != date
        g = c.clone
        g.date = date
        c.availability_quantities.each {|q| g.availability_quantities << q.clone }
        g.save
        c = g
      end
      c
    end
  
  #############################################
  
    def next_change
      model.availability_changes.scoped_by_inventory_pool_id(inventory_pool).first(:conditions => ["date > ?", date])
    end
  
    def start_date
      date
    end
  
    def end_date
      next_change.try(:date).try(:yesterday) || Availability2::ETERNITY
    end
  
  #############################################
  
    def in_quantity_in_group(group)
      q = availability_quantities.scoped_by_group_id(group).first
      q.try(:in_quantity).to_i
    end

    def out_quantity_in_group(group)
      q = availability_quantities.scoped_by_group_id(group).first
      q.try(:out_quantity).to_i
    end
    
    def total_in_group(group)
      in_quantity_in_group(group) + out_quantity_in_group(group)
    end
  
  #############################################
  
    def self.maximum_available_in_period_for_user(model, inventory_pool, user, start_date, end_date)
      groups = user.groups.scoped_by_inventory_pool_id(inventory_pool)
      maximum = maximum_available_in_period_for_groups(model, inventory_pool, groups, start_date, end_date)
      
      changes = model.availability_changes.scoped_by_inventory_pool_id(inventory_pool).between(start_date, end_date)
      changes << model.availability_changes.reset_for_inventory_pool(inventory_pool) if changes.blank?
      maximum_general = changes.collect do |c|
        c.in_quantity_in_group(Group::GENERAL_GROUP_ID)
      end
      (maximum.values << maximum_general.min.to_i).max
    end

    # can return nil!
    def self.most_recent_available_change(model, inventory_pool, at_or_before_date = Date.today)
       return model.availability_changes.scoped_by_inventory_pool_id(inventory_pool).last(
                    :conditions => [ "date <= ?", at_or_before_date ] )
    end

    # how many items of #Model in a 'state' are there at most over the given period?
    #
    # returns a hash à la: { 'CAST' => 2, 'Video' => 1, ... }
    #
    def self.maximum_available_in_period_for_groups(model, inventory_pool, group_or_groups, start_date = Date.today, end_date = Availability2::ETERNITY)
      start_date =  self.most_recent_available_change(model, inventory_pool, start_date).try(:date) || start_date.to_date
      
      end_date = end_date.to_date
      tmp_end_date = model.availability_changes.scoped_by_inventory_pool_id(inventory_pool).minimum(:date, :conditions => [ "date >= ?", start_date ])
      end_date = [tmp_end_date, end_date].max if tmp_end_date
  
      max_per_group = Hash.new
      Array(group_or_groups).each do |group|
        # we don't save AvailableQuantities for Groups that have zero vailable Models for space efficiency
        # reasons thus when there's an AvailabilityChange and there's no associates AvailabilityQuantity
        # then we know it's zero. So if there are more AvailabilityChanges than associated
        # AvailableQuantities then we know there are some that are null
        # TODO: move join up into has_many association
        r = minimum("ifnull(in_quantity,0)",
                    :joins => "LEFT JOIN availability_quantities " \
                              "ON availability_changes.id = availability_quantities.availability_change_id " \
                              "AND availability_quantities.group_id = #{group.id}",
                    :conditions => [ "inventory_pool_id = ? " \
                                     "AND model_id = ? " \
                                     "AND availability_changes.date BETWEEN ? AND ?",
                                     inventory_pool.id, model.id, start_date, end_date ] )
  
        max_per_group[group.name] = r.to_i
      end
  
  
      return max_per_group
    end

    # how is a model distributed in the various groups?
    #
    # returns a hash à la: { general_group_id => 4, cast_group_id => 2, video_group_id => 1, ... }
    #
    # only used in a test for now...
    #
    def self.partitions(model, inventory_pool)
      current_state =  self.most_recent_available_change(model, inventory_pool)

      partitioning = Hash.new
      current_state.availability_quantities.map do |q|
        partitioning[q.group_id] = q.in_quantity + q.out_quantity
      end
      
      partitioning
    end
  
  end

end
