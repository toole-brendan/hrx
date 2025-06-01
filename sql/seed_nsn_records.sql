-- Seed data for nsn_records table
-- Common military equipment NSN records

INSERT INTO nsn_records (nsn, lin, item_name, description, category, unit_of_issue) 
VALUES 
    -- Weapons
    ('1005-01-231-0973', 'R95996', 'RIFLE,5.56 MILLIMETER', 'M4 Carbine, 5.56mm NATO, select fire rifle', 'weapons', 'EA'),
    ('1005-01-447-3405', 'P95215', 'PISTOL,CALIBER .45', 'M1911A1 .45 caliber pistol', 'weapons', 'EA'),
    ('1005-01-565-7445', 'M20988', 'MACHINE GUN,7.62MM', 'M240B Machine Gun, 7.62mm NATO', 'weapons', 'EA'),
    ('1005-01-521-5387', 'R97069', 'RIFLE,5.56MM,M16A4', 'M16A4 Rifle, 5.56mm NATO', 'weapons', 'EA'),
    ('1005-01-566-0668', 'S56289', 'SHOTGUN,12 GAUGE', 'M590A1 Shotgun, 12 gauge', 'weapons', 'EA'),
    
    -- Optics & Night Vision
    ('5855-01-534-5931', 'M99811', 'MONOCULAR,NIGHT VISION', 'AN/PVS-14 Night Vision Monocular', 'optics', 'EA'),
    ('1240-01-412-5010', 'S97120', 'SIGHT,REFLEX', 'M68 CCO Close Combat Optic', 'optics', 'EA'),
    ('5855-01-647-6498', 'G43212', 'GOGGLES,NIGHT VISION', 'AN/PSQ-20 Enhanced Night Vision Goggle', 'optics', 'EA'),
    ('1240-01-540-3690', 'T12345', 'SIGHT,RIFLE COMBAT', 'ACOG Rifle Combat Optic', 'optics', 'EA'),
    ('5855-01-629-5938', 'B89034', 'SIGHT,THERMAL WEAPON', 'AN/PAS-28 Thermal Weapon Sight', 'optics', 'EA'),
    
    -- Communications Equipment
    ('5820-01-451-8250', 'R12312', 'RADIO SET', 'AN/PRC-152A Multiband Radio', 'communications', 'EA'),
    ('5820-01-522-8761', 'R45678', 'RADIO SET,MANPACK', 'AN/PRC-117G Multiband Radio', 'communications', 'EA'),
    ('5965-01-577-9114', 'A56789', 'ANTENNA,WHIP', 'Whip Antenna for Tactical Radio', 'communications', 'EA'),
    ('5820-01-564-2137', 'H23456', 'HANDSET,RADIO', 'H-250/U Radio Handset', 'communications', 'EA'),
    
    -- Body Armor & Protection
    ('8470-01-520-7373', 'B12345', 'BODY ARMOR SET', 'Improved Outer Tactical Vest (IOTV) with plates', 'protection', 'SE'),
    ('8415-01-537-2755', 'H45678', 'HELMET,COMBAT', 'Advanced Combat Helmet (ACH)', 'protection', 'EA'),
    ('8470-01-497-8627', 'P67890', 'PLATE,ARMOR,FRONT', 'Enhanced Small Arms Protective Insert (ESAPI)', 'protection', 'EA'),
    ('8470-01-520-7382', 'G78901', 'GROIN PROTECTOR', 'Groin Protection System', 'protection', 'EA'),
    ('8470-01-532-2002', 'D89012', 'DELTOID PROTECTOR', 'Deltoid and Axillary Protection System (DAPS)', 'protection', 'SE'),
    
    -- Field Equipment
    ('8465-01-524-7310', 'P78901', 'PACK,COMBAT', 'MOLLE II Rucksack, Large', 'field_gear', 'EA'),
    ('7210-00-782-6865', 'S23456', 'SLEEPING BAG', 'Modular Sleep System (MSS)', 'field_gear', 'SE'),
    ('8340-01-482-3963', 'T34567', 'TENT,COMBAT', 'Improved Combat Shelter', 'field_gear', 'EA'),
    ('8465-01-525-0616', 'F45678', 'FRAME,PACK', 'MOLLE II Frame', 'field_gear', 'EA'),
    ('8465-01-515-8645', 'P56789', 'POUCH,AMMUNITION', 'MOLLE Ammunition Pouch', 'field_gear', 'EA'),
    
    -- Medical Equipment
    ('6545-01-539-8165', 'M45678', 'FIRST AID KIT', 'Individual First Aid Kit (IFAK)', 'medical', 'EA'),
    ('6515-01-560-7813', 'T67890', 'TOURNIQUET', 'Combat Application Tourniquet (CAT)', 'medical', 'EA'),
    ('6510-01-562-5288', 'B78901', 'BANDAGE,COMBAT', 'Emergency Trauma Dressing', 'medical', 'EA'),
    ('6545-01-519-9161', 'C89012', 'KIT,COMBAT LIFESAVER', 'Combat Lifesaver Kit', 'medical', 'KT'),
    
    -- Vehicles & Vehicle Equipment
    ('2320-01-533-1905', 'T78456', 'TRUCK,UTILITY', 'M-ATV Mine Resistant Vehicle', 'vehicles', 'EA'),
    ('2540-01-558-5013', 'A90123', 'ARMOR KIT,VEHICULAR', 'Up-Armor Kit for HMMWV', 'vehicles', 'KT'),
    ('6115-01-275-5061', 'G01234', 'GENERATOR SET', 'MEP-831A 3KW Tactical Generator', 'vehicles', 'EA'),
    
    -- IT Equipment
    ('7025-01-583-5937', 'C12345', 'COMPUTER,LAPTOP', 'Toughbook Tactical Laptop', 'it_equipment', 'EA'),
    ('5895-01-577-0423', 'N23456', 'NAVIGATION SET,GPS', 'Defense Advanced GPS Receiver (DAGR)', 'it_equipment', 'EA'),
    ('5895-01-541-0694', 'P34567', 'PLUGGER,GPS', 'Precision Lightweight GPS Receiver', 'it_equipment', 'EA')
ON CONFLICT (nsn) DO UPDATE SET
    lin = EXCLUDED.lin,
    item_name = EXCLUDED.item_name,
    description = EXCLUDED.description,
    category = EXCLUDED.category,
    unit_of_issue = EXCLUDED.unit_of_issue,
    updated_at = CURRENT_TIMESTAMP; 