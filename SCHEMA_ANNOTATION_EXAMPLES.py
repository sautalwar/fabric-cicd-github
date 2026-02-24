# Example: How to Add Schema Annotations to Your Notebooks
# This ensures schema changes are automatically detected on every commit

# =============================================================================
# BEFORE: No schema tracking (changes go undetected)
# =============================================================================

import pandas as pd
from pyspark.sql import functions as F

# Load customer data
df = spark.read.parquet("abfss://data@storage.dfs.core.windows.net/customers")

# Add churn prediction
df = df.withColumn("churn_risk", F.when(F.col("days_since_purchase") > 90, "High").otherwise("Low"))

# Write output
df.write.mode("overwrite").parquet("abfss://data@storage.dfs.core.windows.net/customers_with_churn")


# =============================================================================
# AFTER: With schema annotations (breaking changes are detected!)
# =============================================================================

import pandas as pd
from pyspark.sql import functions as F

# SCHEMA: customers_with_churn
# COLUMNS: customer_id (string), customer_name (string), email (string), lifetime_value (double), days_since_purchase (int), churn_risk (string)

# Load customer data
df = spark.read.parquet("abfss://data@storage.dfs.core.windows.net/customers")

# Add churn prediction
df = df.withColumn("churn_risk", F.when(F.col("days_since_purchase") > 90, "High").otherwise("Low"))

# Write output
df.write.mode("overwrite").parquet("abfss://data@storage.dfs.core.windows.net/customers_with_churn")


# =============================================================================
# EXAMPLE: What happens when you make a BREAKING CHANGE
# =============================================================================

# Scenario 1: Remove a column (BREAKING!)
# OLD:
# SCHEMA: customers_with_churn
# COLUMNS: customer_id (string), customer_name (string), email (string), lifetime_value (double), days_since_purchase (int), churn_risk (string)

# NEW (removed 'email' column):
# SCHEMA: customers_with_churn
# COLUMNS: customer_id (string), customer_name (string), lifetime_value (double), days_since_purchase (int), churn_risk (string)

# Result: GitHub Actions will block this commit and comment:
# 🚨 BREAKING CHANGE: Column 'email' was removed from table 'customers_with_churn'
# This will break Power BI reports that use the 'email' field!


# Scenario 2: Change data type (BREAKING!)
# OLD:
# COLUMNS: customer_id (string), lifetime_value (double)

# NEW (changed lifetime_value from double to int):
# COLUMNS: customer_id (string), lifetime_value (int)

# Result: GitHub Actions will block this commit and comment:
# 🚨 BREAKING CHANGE: Column 'lifetime_value' type changed from double to int
# This may cause precision loss in Power BI calculations!


# Scenario 3: Add a new column (SAFE)
# OLD:
# COLUMNS: customer_id (string), customer_name (string), email (string)

# NEW (added 'phone_number' column):
# COLUMNS: customer_id (string), customer_name (string), email (string), phone_number (string nullable)

# Result: GitHub Actions allows this commit and comments:
# ✅ Safe change: Column 'phone_number' was added to table 'customers_with_churn'
# Existing Power BI reports will continue to work.


# =============================================================================
# REAL EXAMPLE: Customer Segmentation Feature
# =============================================================================

# SCHEMA: customers_with_segments
# COLUMNS: customer_id (string), customer_name (string), email (string), lifetime_value (double), customer_segment (string), churn_risk (string), segmentation_date (timestamp)

import pandas as pd
from pyspark.sql import functions as F
from datetime import datetime

# Load customer data
df = spark.read.parquet("abfss://data@storage.dfs.core.windows.net/customers")

# Add customer segmentation (NEW FEATURE)
df = df.withColumn(
    "customer_segment",
    F.when(F.col("lifetime_value") > 5000, "High-Value")
     .when(F.col("lifetime_value") >= 1000, "Mid-Tier")
     .otherwise("Low-Tier")
)

# Add churn risk
df = df.withColumn(
    "churn_risk",
    F.when(F.col("days_since_purchase") > 90, "High").otherwise("Low")
)

# Add timestamp
df = df.withColumn("segmentation_date", F.current_timestamp())

# Write output
df.write.mode("overwrite").parquet("abfss://data@storage.dfs.core.windows.net/customers_with_segments")

# When you commit this:
# ✅ GitHub Actions detects: Added columns 'customer_segment' and 'segmentation_date'
# ✅ Validates: No breaking changes - existing Power BI reports will work
# ✅ Comments on PR: "Safe to merge. Power BI reports won't break."
