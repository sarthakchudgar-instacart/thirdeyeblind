import instaquery as iq
import pandas as pd

# Path to the Excel file
FILE_PATH = '/Users/sarthakchudgar/cursor_workspace/Projects/thirdeyeblind/InstacartPresentsThirdEyeBlind-guestlist-export-2025-12-04--11.54.04.EST.10ea6118d05cc7c2-6931bdaf8e72d.xlsx'

# Read the Excel file
print("Reading Excel file...")
df = pd.read_excel(FILE_PATH)

# Preview the data
print(f"\nFile has {len(df)} rows and {len(df.columns)} columns")
print(f"\nColumns: {list(df.columns)}")
print(f"\nFirst 5 rows:")
print(df.head())

# Clean column names (remove spaces, special chars for Snowflake compatibility)
df.columns = [col.strip().replace(' ', '_').replace('-', '_').lower() for col in df.columns]
print(f"\nCleaned column names: {list(df.columns)}")

# Upload to Snowflake
TABLE_NAME = "thirdeyeblind_guestlist"
print(f"\nUploading to sandbox_db.sarthakchudgar.{TABLE_NAME}...")

iq.upload(df, TABLE_NAME)

print(f"\nUpload complete!")

# Verify the upload
print("\nVerifying upload - first 5 rows from Snowflake:")
result = iq.query(f"SELECT * FROM sandbox_db.sarthakchudgar.{TABLE_NAME} LIMIT 5")
print(result)

print(f"\nTotal rows in Snowflake table:")
count = iq.query(f"SELECT COUNT(*) as row_count FROM sandbox_db.sarthakchudgar.{TABLE_NAME}")
print(count)

