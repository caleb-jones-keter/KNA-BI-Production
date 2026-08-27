# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {}
# META }

# CELL ********************

import pandas as pd
from pyspark.sql import SparkSession

# Start Spark session (Fabric notebooks have Spark by default)
spark = SparkSession.builder.getOrCreate()

# Your export link
url = "https://edbplus.keter.com/EdbWeb/ViewMailReport.aspx?mid=00355512-8ebf-4713-b285-f0df376bc47c&dataexport=1&renderAs=webexport&run=true"

# Try reading as CSV first
try:
    df = pd.read_csv(url)
except Exception as e:
    print("CSV read failed, trying Excel...")
    try:
        df = pd.read_excel(url)
    except Exception as e2:
        print("Excel read failed, trying HTML...")
        df_list = pd.read_html(url)
        df = df_list[0]  # first table on page

# Convert Pandas DataFrame to Spark DataFrame
spark_df = spark.createDataFrame(df)

# Save to Lakehouse table
# Make sure your notebook is attached to the Lakehouse BRZ_NA_SC_LH
spark_df.write.format("delta").mode("overwrite").saveAsTable("EDB_Budget")

print("✅ Data loaded into Lakehouse BRZ_NA_SC_LH as table EDB_Budget")



# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
