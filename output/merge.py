import json
import csv

def merge_files():
    print("Loading files...")
    # 1. Load the files (Using utf-8 encoding to prevent special character errors)
    with open('TNEB_Master_Data.json', 'r', encoding='utf-8') as f:
        master_data = json.load(f)

    with open('tneb_section_office.json', 'r', encoding='utf-8') as f:
        section_data = json.load(f)

    # 2. Extract coordinates from the section file
    print("Extracting coordinates from section data...")
    section_coords = {}
    for f in section_data.get('features', []):
        props = f.get('properties', {})
        
        # Using circle_cod + section_co to create a unique matching key
        if 'circle_cod' in props and 'section_co' in props:
            key = str(props['circle_cod']) + "_" + str(props['section_co'])
            geom = f.get('geometry')
            
            if geom and geom.get('type') == 'Point':
                coords = geom.get('coordinates')
                if coords and len(coords) >= 2:
                    # GeoJSON coordinates are [longitude, latitude]
                    section_coords[key] = (coords[0], coords[1]) 

    # 3. Update the master data
    print("Merging coordinates into master data...")
    updated_count = 0
    for f in master_data.get('features', []):
        props = f.get('properties', {})
        if 'circle_cod' in props and 'section_co' in props:
            key = str(props['circle_cod']) + "_" + str(props['section_co'])
            
            if key in section_coords:
                lon, lat = section_coords[key]
                props['office_lon'] = lon
                props['office_lat'] = lat
                updated_count += 1

    print(f"Successfully merged {updated_count} records!")

    # 4. Save the updated master data as FORMATTED JSON
    print("Saving formatted JSON file...")
    with open('TNEB_Master_Data_Merged.json', 'w', encoding='utf-8') as out_f:
        # indent=4 is the magic parameter that formats the JSON beautifully
        json.dump(master_data, out_f, indent=4, ensure_ascii=False)

    # 5. Save the updated properties as CSV
    print("Saving CSV file...")
    with open('TNEB_Master_Data_Merged.csv', 'w', newline='', encoding='utf-8') as f:
        if master_data.get('features'):
            # Grab all keys from the first feature's properties to use as column headers
            keys = master_data['features'][0]['properties'].keys()
            writer = csv.DictWriter(f, fieldnames=keys)
            writer.writeheader()
            
            for feature in master_data.get('features', []):
                writer.writerow(feature['properties'])
                
    print("Done! Check your folder for 'TNEB_Master_Data_Merged.json' and 'TNEB_Master_Data_Merged.csv'.")

if __name__ == "__main__":
    merge_files()