describe "Merging multiple lines availability in total and for partitions", ->

  beforeEach ->
    @inventory_pool = {id: 1, closed_days: [0,6], name: "AV-Ausleihe"}
    @lines = []
    @lines[0] = 
      type: "item_line"
      quantity: 1
      model: {id: 5, type: "model"}
      availability_for_inventory_pool:
        inventory_pool: @inventory_pool
        partitions: [{group_id: null, quantity: 4}, {group_id: 1, quantity: 2}, {group_id: 2, quantity: 2}]
        changes: 
          [["2012-01-01", 0, [{group_id: null, in_quantity: 0}, {group_id: 1, in_quantity: 0}, {group_id: 2, in_quantity: 0}]],
           ["2012-01-02", 0, [{group_id: null, in_quantity: 0}, {group_id: 1, in_quantity: 0}, {group_id: 2, in_quantity: 0}]],
           ["2012-01-03", 0, [{group_id: null, in_quantity: 0}, {group_id: 1, in_quantity: 0}, {group_id: 2, in_quantity: 0}]],
           ["2012-01-12", 2, [{group_id: null, in_quantity: 0}, {group_id: 1, in_quantity: 2}, {group_id: 2, in_quantity: 0}]],
           ["2012-01-15", 4, [{group_id: null, in_quantity: 2}, {group_id: 1, in_quantity: 0}, {group_id: 2, in_quantity: 2}]]
          ]
    @lines[1] = 
      type: "item_line"
      quantity: 1
      model: {id: 6, type: "model"}
      availability_for_inventory_pool:
        inventory_pool: @inventory_pool   
        partitions: [{group_id: null, quantity: 4}, {group_id: 1, quantity: 2}, {group_id: 2, quantity: 2}]
        changes: 
          [["2012-01-01", 0, [{group_id: null, in_quantity: 0}, {group_id: 1, in_quantity: 0}, {group_id: 2, in_quantity: 0}]],
           ["2012-01-02", 2, [{group_id: null, in_quantity: 2}, {group_id: 1, in_quantity: 0}, {group_id: 2, in_quantity: 0}]],
           ["2012-01-04", 1, [{group_id: null, in_quantity: 1}, {group_id: 1, in_quantity: 0}, {group_id: 2, in_quantity: 0}]],
           ["2012-01-12", 2, [{group_id: null, in_quantity: 0}, {group_id: 1, in_quantity: 2}, {group_id: 2, in_quantity: 0}]],
           ["2012-01-15", 4, [{group_id: null, in_quantity: 2}, {group_id: 1, in_quantity: 0}, {group_id: 2, in_quantity: 2}]]
          ]
    @lines[2] = 
      type: "item_line"
      quantity: 1
      model: {id: 7, type: "model"}
      availability_for_inventory_pool:
        inventory_pool: @inventory_pool   
        partitions: [{group_id: null, quantity: 4}, {group_id: 1, quantity: 2}, {group_id: 2, quantity: 2}]
        changes: 
          [["2012-01-01", 0, [{group_id: null, in_quantity: 0}, {group_id: 1, in_quantity: 0}, {group_id: 2, in_quantity: 0}]],
           ["2012-01-02", 3, [{group_id: null, in_quantity: 3}, {group_id: 1, in_quantity: 0}, {group_id: 2, in_quantity: 0}]],
           ["2012-01-12", 2, [{group_id: null, in_quantity: 0}, {group_id: 1, in_quantity: 2}, {group_id: 2, in_quantity: 0}]],
           ["2012-01-15", 2, [{group_id: null, in_quantity: 2}, {group_id: 1, in_quantity: 0}, {group_id: 2, in_quantity: 2}]]
          ]
    @lines[3] = 
      type: "item_line"
      quantity: 1
      model: {id: 8, type: "model"}
      availability_for_inventory_pool:
        inventory_pool: @inventory_pool   
        partitions: [{group_id: null, quantity: 4}, {group_id: 1, quantity: 2}, {group_id: 2, quantity: 2}]
        changes:
          [["2012-01-01", 0, [{group_id: null, in_quantity: 0}, {group_id: 1, in_quantity: 0}, {group_id: 2, in_quantity: 0}]],
           ["2012-01-02", 1, [{group_id: null, in_quantity: 1}, {group_id: 1, in_quantity: 0}, {group_id: 2, in_quantity: 0}]],
           ["2012-01-12", 2, [{group_id: null, in_quantity: 0}, {group_id: 1, in_quantity: 2}, {group_id: 2, in_quantity: 0}]],
           ["2012-01-15", 4, [{group_id: null, in_quantity: 2}, {group_id: 1, in_quantity: 0}, {group_id: 2, in_quantity: 2}]]
          ]
    @lines[4] = 
      type: "item_line"
      quantity: 1
      model: {id: 9, type: "model"}
      availability_for_inventory_pool:
        inventory_pool: @inventory_pool   
        partitions: [{group_id: null, quantity: 4}, {group_id: 1, quantity: 2}, {group_id: 2, quantity: 2}]
        changes: 
          [["2012-01-01", 0, [{group_id: null, in_quantity: 0}, {group_id: 1, in_quantity: 0}, {group_id: 2, in_quantity: 0}]],
           ["2012-01-02", 4, [{group_id: null, in_quantity: 4}, {group_id: 1, in_quantity: 0}, {group_id: 2, in_quantity: 0}]],
           ["2012-01-12", 2, [{group_id: null, in_quantity: 0}, {group_id: 1, in_quantity: 2}, {group_id: 2, in_quantity: 0}]],
           ["2012-01-15", 4, [{group_id: null, in_quantity: 2}, {group_id: 1, in_quantity: 0}, {group_id: 2, in_quantity: 2}]]
          ]
    @lines[5] = 
      type: "item_line"
      quantity: 1
      model: {id: 10, type: "model"}
      availability_for_inventory_pool:
        inventory_pool: @inventory_pool   
        partitions: [{group_id: null, quantity: 4}, {group_id: 1, quantity: 2}]
        changes: 
          [["2012-01-01", 0, [{group_id: null, in_quantity: 0}, {group_id: 1, in_quantity: 0}]],
           ["2012-01-02", 2, [{group_id: null, in_quantity: 2}, {group_id: 1, in_quantity: 0}]],
           ["2012-01-12", 2, [{group_id: null, in_quantity: 0}, {group_id: 1, in_quantity: 2}]],
           ["2012-01-15", 2, [{group_id: null, in_quantity: 2}, {group_id: 1, in_quantity: 0}]]
          ]
       
    @merged_lines_availabilities = new MultipleMergedLinesAvailabilities @lines
    
#-###################### merging total quantities

  it "is merging multiple lines total quantity so it has more then 0 elements", ->
    expect(@merged_lines_availabilities.changes.length > 0).toBeTruthy("Merge failed! No entry found")

  it "after merging lines total quantity the availability entries have to be unique", ->
    already_existing = {}
    for av_date in @merged_lines_availabilities.changes
      expect(already_existing[av_date[0]]).not.toBeDefined("Entry already existing"); 
      already_existing[av_date[0]] = av_date      
        
  it "still contains at least one entry for all dates that where already existing in the lines before they were merged", ->
    for line in @lines
      for line_av_date in line
        av_date_found = false
        for merged_av_date in @merged_lines_availabilities
          av_date_found = true if av_date[0] == merged_av_date[0]
        expect(av_date_found).toBeTruthy("Record not found") 
             
  it "is merging one specific availability entry (in this case: 2012-01-01) to 0 (unavailable) if all lines have this entry as well set as 0 (unavailable)", ->
    for av_date in @merged_lines_availabilities.changes
      expect(av_date[1] == 0).toBeTruthy("Summed total quantity for the 2012-01-01 is not correct") if av_date[0] == "2012-01-01"

  it "is merging one specific availability entry (in this case: 2012-01-02) to 0 (unavailable) if all lines have this entry set greater then 0 but one has 0 (unavailable)", ->
    for av_date in @merged_lines_availabilities.changes
      expect(av_date[1] == 0).toBeTruthy("Summed total quantity for the 2012-01-02 is not correct") if av_date[0] == "2012-01-02"
        
  it "is merging one specific availability entry (in this case: 2012-01-12) to 1 (available) if all lines have this entry set greater then 0 (available)", ->
    for av_date in @merged_lines_availabilities.changes
      expect(av_date[1] == 1).toBeTruthy("Summed total quantity for the 2012-01-12 is not correct") if av_date[0] == "2012-01-12"
        
  it "is merging one specific availability entry (in this case: 2012-01-04) to 0 (unavailable) if only one line has a entry for this date explicitly set to greater then 0 (available) but one other's line latest entry is 0 (unavailable)", ->
    for av_date in @merged_lines_availabilities.changes
      expect(av_date[1] == 0).toBeTruthy("Summed total quantity for the 2012-01-04 is not correct") if av_date[0] == "2012-01-04"
      
#-###################### making a union of all possible partitions

   it "is making a union of the possible partitions", ->
    expect(@merged_lines_availabilities.partitions.length>0).toBeTruthy("Partitions not unified")
    
   it "after merging partitions they have to be unique", ->
    for partition in @merged_lines_availabilities.partitions
      existing_partitions = (existing_partition for existing_partition in @merged_lines_availabilities.partitions when partition.group_id is existing_partition.group_id)
      expect(existing_partitions.length == 1).toBeTruthy("Parition is existing twice after merge")
    
#-###################### merging nested av_entry partitions
    
  it "is merging multiple lines availability entrie's partitions as well", ->
    for av_date in @merged_lines_availabilities.changes
      expect(av_date[2].length > 0).toBeTruthy("Partition not merged correctly - no partition found for this line")
      for partition in av_date[2]
        matched_partitions = (existing_partition for existing_partition in @merged_lines_availabilities.partitions when partition.group_id is existing_partition.group_id)
        expect(matched_partitions.length == 1).toBeTruthy("Partition not merged correctly")
        
  it "is merging a specific partition (in this case: group_id 1) on a specific availability entry (in this case: 2012-01-12) to 1 (available) if all lines have this entry and this partition set greater then 0 (available)", ->
    found_partition = false
    for av_date in @merged_lines_availabilities.changes
      if av_date[0] == "2012-01-12"
        for partition in av_date[2]
          found_partition = true if partition.group_id == 1
          expect(partition.in_quantity == 1).toBeTruthy("Summed nested partition with group_id 1 for the 2012-01-12 is not correct") if partition.group_id == 1 
    expect(found_partition).toBeTruthy("Partition not found")
         
  it "is merging a specific partition (in this case: group_id 2) on a specific availability entry (in this case: 2012-01-15) to 0 (unavailable) if one line doesnt have this partiton but all other lines have this entry and this partition set greater then 0 (available)", ->
    found_partition = false
    for av_date in @merged_lines_availabilities.changes
      if av_date[0] == "2012-01-15"
        for partition in av_date[2]
          found_partition = true if partition.group_id == 2
          expect(partition.in_quantity == 0).toBeTruthy("Summed nested partition with group_id 2 for the 2012-01-15 is not correct") if partition.group_id == 2
    expect(found_partition).toBeTruthy("Partition not found")
    