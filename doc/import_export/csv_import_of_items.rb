# encoding: utf-8
# This is to be run from the Rails console using require:
# rails c
# require 'doc/other/csv_import_of_items'

import_file = '/tmp/items.csv'

@failures = 0
@successes = 0

@errorlog = File.open('/tmp/import_errors.txt', 'w+')

items_to_import = CSV.open(import_file, col_sep: "\t", headers: true)

def log_error(error, item)
  @errorlog.puts "ERROR: #{error}. --- Item: #{item}"
end

def validate_item(item)
  errors = false

  begin
    Model.exists?(item['Modell-ID'].to_i)
  rescue
    errors = true
    log_error "Model '#{item['Modell-ID']}' not found.", item
  end

  if item['Verantwortliche Abteilung'].blank?
    errors = true
    log_error 'Responsible department is blank', item
  else
    responsible_ip = InventoryPool.where(name: item['Verantwortliche Abteilung']).first
    if responsible_ip.nil?
      errors = true
      log_error "Responsible inventory pool '#{item["Verantwortliche Abteilung"]}' does not exist", item
    end
  end

  if item['Besitzer'].blank?
    errors = true
    log_error 'Owner is blank', item
  else
    owner_ip = InventoryPool.where(name: item['Besitzer']).first
    if owner_ip.nil?
      errors = true
      log_error "Owner '#{item["Besitzer"]}' does not exist", item
    end
  end


  if errors
    @failures += 1
    return false
  else
    return true
  end
end

items_to_import.each do |item|
  next if not validate_item(item)
  i = Item.new
  i.model = Model.find item['Produkt']
  #i.inventory_code = item['Inventarcode']
  i.serial_number = item['Seriennummer']
  #i.note = item["Notiz"]

  i.is_inventory_relevant = true
  i.is_borrowable = true

  # Ownership
  owner_ip = InventoryPool.where(name: item['Besitzer']).first
  i.owner = owner_ip

  # Responsible department
  unless item['Verantwortliche Abteilung'] == 'frei'
    responsible_ip = InventoryPool.where(name: item['Verantwortliche Abteilung']).first
    i.inventory_pool = responsible_ip
  end

  # Building and room
  b = Building.where(code: 'TONI').first

  room = nil
  room = item['Raum'] unless item['Raum'].blank?
  location = Location.find_or_create({'building_id' => b.id, 'room' => room})
  i.location = location

  # Invoice
  i.invoice_number = item['Rechnungsnummer']
  i.invoice_date = Date.strptime(item['Rechnungsdatum'], '%d.%m.%Y') unless item['Rechnungdatum'].blank?

  i.price = item['Preis'] unless item['Preis'].blank?

  i.last_check = Date.strptime(item['Letzte Inventur'], '%d.%m.%Y') unless item['Letzte Inventur'].blank?

  # Supplier
  i.supplier = Supplier.where(name: item['Lieferant']).first
  if i.supplier.nil?
    i.supplier = Supplier.create(name: item['Lieferant'])
  end

  # Properties
  #i.properties[:anschaffungskategorie] = item['Anschaffungskategorie']
  #i.properties[:reference] = "invoice" if item["Bezug"] == "laufende Rechnung"
  #i.properties[:reference] = "investment" if item["Bezug"] == "Investition"

  if i.save
  #  puts "Item imported correctly:"
    @successes += 1
  #  puts i.inspect
  else
    @failures += 1
    @errorlog.puts "Could not import item #{i.inventory_code}. Errors: #{i.errors.full_messages}"
  end

end

puts '-----------------------------------------'
puts 'DONE'
puts "#{@successes} successes, #{@failures} failures"
puts '-----------------------------------------'


@errorlog.close
