When(/^I visit "(.*)"$/) do |path|
  visit path
end

Then(/^all is correct$/) do
  expect(has_content? _('All correct')).to be true
  expect(has_selector?('.fa.fa-check-square-o')).to be true
end

When(/^a database admin deletes some (referenced|visit related access right) records directly on the database$/) do |arg1|
  @connection = ActiveRecord::Base.connection

  @query = case arg1
             when 'visit related access right'
               %Q(DELETE access_rights.* FROM reservations AS cl LEFT JOIN access_rights ON cl.user_id = access_rights.user_id AND cl.inventory_pool_id = access_rights.inventory_pool_id)

             when 'referenced'
               only_tables_no_views = ActiveRecord::Base.connection.tables
               begin
                 reference = ActiveRecord::Base.descendants.flat_map do |klass|
                   next if klass.name =~ /^HABTM_/
                   klass.reflect_on_all_associations(:belongs_to).map do |ref|
                     if ref.polymorphic?
                       # NOTE we cannot define foreign keys on multiple parent tables
                     elsif not only_tables_no_views.include?(klass.table_name) or not only_tables_no_views.include?(ref.table_name)
                       # NOTE we skip references on sql-views
                     else
                       next if klass == ModelGroupLink # we cannot define the inverse_of for acts_as_dag_links
                       next if klass == ReservationsBundle # this is based on Reservation
                       dependent = if ref.inverse_of and ref.inverse_of.options[:dependent]
                                     ref.inverse_of.options[:dependent]
                                   else
                                     nil
                                   end
                       unless [:delete, :delete_all, :destroy, :nullify].include?(dependent)
                         # NOTE we get an association which delete should be prevented by the database
                         {klass: klass, other_table: ref.table_name, this_column: ref.foreign_key, other_column: ref.active_record_primary_key}
                       end
                     end
                   end
                 end.compact.sample
                 referenced_id = reference[:klass].pluck(reference[:this_column]).sample
               end while referenced_id.nil?
               %Q(DELETE FROM %s WHERE %s = %d) % [reference[:other_table], reference[:other_column], referenced_id]
             else
               raise
           end
end

Then(/^the delete is( not)? prevented$/) do |arg1|
  if arg1
    expect { @connection.execute @query }.not_to raise_error
  else
    expect { @connection.execute @query }.to raise_error ActiveRecord::StatementInvalid
  end
end

Then(/^there are missing customer access rights for upcoming actions$/) do
  expect(has_content? _('Missing customer access rights for upcoming actions')).to be true
end

When(/^I restore the customer access rights$/) do
  accept_alert do
    find('.btn', text: _('Restore customer access rights')).click
  end
end
