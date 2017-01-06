# -*- encoding : utf-8 -*-

When /^a purpose is saved, it is independent of its orders$/ do
  purpose = FactoryGirl.create :purpose
  expect { purpose.contract }.to raise_error(NoMethodError)
end

When /^each entry of a submitted order refers to a purpose$/ do
  reservations = rand(3..6).times.map { FactoryGirl.create :reservation, status: :submitted }
  reservations.each do |line|
    expect(line.purpose.is_a?(Purpose)).to be true
  end
end

When /^each entry of an order can refer to a purpose$/ do
  reservations = rand(3..6).times.map { FactoryGirl.create :reservation }
  reservations.each do |line|
    line.purpose = FactoryGirl.create :purpose
    expect(line.purpose.is_a?(Purpose)).to be true
  end
end


Then /^I see the purpose$/ do
  if @contract.reservations.first.purpose
    expect(has_content?(@contract.reservations.first.purpose.description)).to be true
  end
end

Then /^I see the assigned purpose on each line$/ do
  @customer.reservations_bundles.approved.find_by(inventory_pool_id: @current_inventory_pool).reservations.each do |line|
    target = find(".line[data-id='#{line.id}'] [data-tooltip-template*='purpose']")
    hover_for_tooltip target
    find('.tooltipster-default .tooltipster-content', text: line.purpose.description)
  end
end

Then /^I can edit the purpose$/ do
  find('.button', text: _('Edit Purpose')).click
  @new_purpose_description = 'Benötigt für die Sommer-Austellung'
  within '.modal' do
    find("textarea[name='purpose']").set @new_purpose_description
    find('button[type=submit]').click
  end
  find('#purpose', text: @new_purpose_description)
  expect(@contract.reload.reservations.first.purpose.description).to eq @new_purpose_description
end

When /^none of the selected items have an assigned purpose$/ do
  step 'I add an item to the hand over by providing an inventory code'
  step 'I add an option to the hand over by providing an inventory code'
  step 'I edit the timerange of the selection'
  step "I set the start date in the calendar to '#{I18n.l(Date.today)}'"
  step 'I save the booking calendar'
  step 'the booking calendar is closed'
end

Then /^I am told during hand over to assign a purpose$/ do
  find('.multibutton .button[data-hand-over-selection]').click
  within '.modal' do
    find('#purpose-input', text: _("Please provide a purpose...")).find('#purpose')
  end
end

Then /^only when I assign a purpose$/ do
  within '.modal' do
    find('.button.green[data-hand-over]', text: _('Hand Over')).click
    find('#error')
    find('#purpose').set 'The purpose for this hand over'
  end
end

Given(/^the current inventory pool (requires|doesn't require) purpose$/) do |arg1|
  b = case arg1
        when "requires"
          true
        else
          false
      end
  @current_inventory_pool.update_attributes(required_purpose: b)
end

Then /^I do not assign a purpose$/ do
  within '.modal' do
    expect(find('#purpose').text).to be_empty
  end
end

Then /^I can finish the hand over$/ do
  signed_contracts_size = @customer.reservations_bundles.signed.to_a.size # NOTE count returns a Hash because the group() in default scope
  step 'I click hand over inside the dialog'
  expect(@customer.reservations_bundles.signed.to_a.size).to be > signed_contracts_size # NOTE count returns a Hash because the group() in default scope
end

Then /^I don't have to assign a purpose in order to finish the hand over$/ do
  step 'I edit the timerange of the selection'
  step "I set the start date in the calendar to '#{I18n.l(Date.today)}'"
  step 'I save the booking calendar'
  step 'the booking calendar is closed'
  find('.multibutton .button[data-hand-over-selection]').click
  find('.modal.ui-shown')
  step 'I can finish the hand over'
end

When /^I define a purpose$/ do
  step 'I edit the timerange of the selection'
  step "I set the start date in the calendar to '#{I18n.l(Date.today)}'"
  step 'I save the booking calendar'
  step 'the booking calendar is closed'
  find('.multibutton .button[data-hand-over-selection]').click
  find('#add-purpose').click
  @added_purpose = 'Another Purpose'
  find('#purpose').set @added_purpose
  @approved_lines = @customer.reservations_bundles.approved.find_by(inventory_pool_id: @current_inventory_pool).reservations
  step 'I can finish the hand over'
end

Then /^only items without purpose are assigned that purpose$/ do
  @approved_lines.select{|l| l.purpose.blank?}.each do |line|
    expect(line.purpose.description).to eq @added_purpose
  end
end

When /^all selected items have an assigned purpose$/ do
  @contract = @customer.reservations_bundles.approved.find_by(inventory_pool_id: @current_inventory_pool)
  reservations = @contract.reservations
  reservations.each do |line|
    @item_line = line
    begin
      step 'I select one of those'
    rescue
      # if we ran out of available items, and an Capybara::Element not found exception was raised, just ensure that all the selected and assigned contract reservations so far, have a purpose
      expect(reservations.reload.select(&:item).all?(&:purpose)).to be true
      break
    end
  end

  # select all reservations if no one is selected yet
  if all("input[type='checkbox']:checked").empty?
    step 'I select all reservations selecting all linegroups'
  end
  # ensure that only reservations with assigned items are selected before continuing with the test
  reservations.reload.select{|l| !l.item}.each do |l|
    cb = find(".line[data-id='#{l.id}'] input[type='checkbox']")
    cb.click if cb.checked?
  end

  step 'I edit the timerange of the selection'
  step "I set the start date in the calendar to '#{I18n.l(Date.today)}'"
  step 'I save the booking calendar'
  step 'the booking calendar is closed'

  within '#lines' do
    reservations = reservations.select {|line| line.item and find(".line[data-id='#{line.id}'] input[type='checkbox'][data-select-line]").checked? }
  end

  find('.multibutton .button[data-hand-over-selection]').click
  within('.modal') do
    reservations.each do |line|
      find('.row', match: :first, text: line.purpose.to_s)
    end
  end
end

Then /^I cannot assign any more purposes$/ do
  expect(has_no_selector?('.modal .purpose button', visible: true)).to be true
end
