-- Populate test NSN data for development/testing
-- This script adds some common military equipment NSN records

INSERT INTO nsn_data (nsn, lin, nomenclature, fsc, niin, unit_price, manufacturer, part_number, specifications, last_updated, created_at, updated_at)
VALUES 
-- Radio equipment
('5820-01-451-8250', 'R12345', 'RADIO SET, MANPACK', '5820', '014518250', 5000.00, 'Harris Corporation', 'RF-7800M-MP', '{"weight": "11.5 lbs", "frequency": "30-512 MHz", "power": "5W"}', NOW(), NOW(), NOW()),
('5820-01-522-9160', 'R67890', 'RADIO, PORTABLE', '5820', '015229160', 3500.00, 'Motorola Solutions', 'APX8000', '{"weight": "14 oz", "frequency": "VHF/UHF", "battery": "7.4V Li-Ion"}', NOW(), NOW(), NOW()),
('5820-01-564-6153', 'R11111', 'RADIO SET, TACTICAL', '5820', '015646153', 12000.00, 'L3Harris Technologies', 'RF-7850M-HH', '{"weight": "32 oz", "encryption": "AES-256", "channels": "256"}', NOW(), NOW(), NOW()),

-- Night vision equipment  
('5855-01-547-5175', 'N23456', 'NIGHT VISION GOGGLES', '5855', '015475175', 3200.00, 'L3 Warrior Systems', 'AN/PVS-14', '{"generation": "Gen 3", "magnification": "1x", "fov": "40 degrees"}', NOW(), NOW(), NOW()),
('5855-01-629-5334', 'N78901', 'NIGHT VISION DEVICE, BINOCULAR', '5855', '016295334', 8500.00, 'Elbit Systems of America', 'AN/PVS-31A', '{"generation": "Gen 3", "magnification": "1x", "weight": "539g"}', NOW(), NOW(), NOW()),

-- Weapon optics
('1240-01-412-6986', 'W34567', 'SIGHT, REFLEX', '1240', '014126986', 650.00, 'Aimpoint Inc', 'CompM4s', '{"battery": "AA", "battery_life": "80000 hours", "weight": "11.8 oz"}', NOW(), NOW(), NOW()),
('1240-01-576-3144', 'W89012', 'SIGHT, HOLOGRAPHIC WEAPON', '1240', '015763144', 700.00, 'L3 EOTech', 'EXPS3-0', '{"battery": "CR123", "reticle": "68 MOA ring", "weight": "11.2 oz"}', NOW(), NOW(), NOW()),

-- Body armor
('8470-01-520-7373', 'A45678', 'ARMOR, BODY, FRAGMENTATION PROTECTIVE', '8470', '015207373', 1600.00, 'Point Blank Enterprises', 'IOTV Gen III', '{"size": "Medium", "protection": "Level IIIA", "weight": "30 lbs"}', NOW(), NOW(), NOW()),
('8470-01-564-5892', 'A90123', 'VEST, ARMOR PLATE CARRIER', '8470', '015645892', 350.00, 'Crye Precision', 'JPC 2.0', '{"size": "Medium", "material": "500D Cordura", "weight": "1.5 lbs"}', NOW(), NOW(), NOW()),

-- Medical supplies
('6515-01-521-7976', 'M56789', 'TOURNIQUET, NONPNEUMATIC', '6515', '015217976', 30.00, 'Composite Resources Inc', 'CAT Gen 7', '{"type": "windlass", "width": "1.5 inches", "weight": "2.7 oz"}', NOW(), NOW(), NOW()),
('6545-01-539-2732', 'M01234', 'BANDAGE, GAUZE, COMPRESSED', '6545', '015392732', 12.00, 'North American Rescue', 'Emergency Trauma Dressing', '{"size": "6 inch", "sterile": "yes", "vacuum_packed": "yes"}', NOW(), NOW(), NOW()),

-- Batteries
('6135-01-447-3846', 'B67890', 'BATTERY, NONRECHARGEABLE', '6135', '014473846', 3.50, 'Surefire LLC', 'SF123A', '{"type": "CR123A", "voltage": "3V", "capacity": "1550mAh"}', NOW(), NOW(), NOW()),
('6140-01-490-4316', 'B12345', 'BATTERY, STORAGE', '6140', '014904316', 85.00, 'Bren-Tronics Inc', 'BB-2590/U', '{"type": "Li-Ion", "voltage": "14.4V", "capacity": "15Ah"}', NOW(), NOW(), NOW())
ON CONFLICT (nsn) DO UPDATE SET
  lin = EXCLUDED.lin,
  nomenclature = EXCLUDED.nomenclature,
  unit_price = EXCLUDED.unit_price,
  manufacturer = EXCLUDED.manufacturer,
  part_number = EXCLUDED.part_number,
  specifications = EXCLUDED.specifications,
  last_updated = NOW(),
  updated_at = NOW(); 