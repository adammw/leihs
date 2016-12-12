Then(/^I see a list of buildings$/) do
  find('.nav-tabs .active', text: _('Buildings'))
  within '.list-of-lines' do
    Building.limit(5).each do |building|
      find('.row > .col-sm-4', text: building.name)
    end
  end
end

When(/^I create a new building( not)? providing all required values$/) do |arg1|
  find('.btn', text: _('Create %s') % _('Building')).click
  if arg1
    # not providing building[name]
  else
    @name = Faker::Address.street_address
    @code = Faker::Address.building_number
    find("input[name='building[name]']").set @name
    find("input[name='building[code]']").set @code
  end
end

When(/^I see the (new|edited) building$/) do |arg1|
  within '.list-of-lines' do
    find('.row > .col-sm-4', text: @name)
  end
end

Then(/^I see the building form$/) do
  within 'form' do
    find("input[name='building[name]']")
  end
end

When(/^I edit an existing building$/) do
  within '.list-of-lines' do
    all('.row > .col-sm-2 > .btn', text: _('Edit')).sample.click
  end

  @name = Faker::Address.street_address
  @code = Faker::Address.building_number
  find("input[name='building[name]']").set @name
  find("input[name='building[code]']").set @code
end

Given(/^there is a deletable building$/) do
  @building = Building.all.detect {|b| b.can_destroy? }
  @building ||= FactoryGirl.create(:building, name: Faker::Address.street_address, code: Faker::Address.building_number)
  expect(@building).not_to be_nil
  expect(@building.can_destroy?).to be true
end

When(/^I delete a building$/) do
  within '.list-of-lines' do
    within('.row', text: @building.name) do
      find('.dropdown-toggle').click
      find('.dropdown-menu a', text: _('Delete')).click
      step 'I am asked whether I really want to delete'
    end
  end
end

Then(/^I don't see the deleted building$/) do
  within '.list-of-lines' do
    expect(has_no_selector?('.row > .col-sm-4', text: @building.name)).to be true
  end
end

