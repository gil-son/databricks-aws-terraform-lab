# Databricks notebook source
# Validation job: read creditcard.csv from the data bucket and write it as Delta bronze.

# COMMAND ----------

dbutils.widgets.text("catalog", "homol_catalog")
dbutils.widgets.text("data_bucket", "")

catalog = dbutils.widgets.get("catalog")
data_bucket = dbutils.widgets.get("data_bucket")
source = f"s3://{data_bucket}/raw/creditcard/creditcard.csv"
target = f"{catalog}.bronze.creditcard_raw"

# COMMAND ----------

df = spark.read.option("header", True).option("inferSchema", True).csv(source)
df.write.format("delta").mode("overwrite").saveAsTable(target)

# COMMAND ----------

result = spark.table(target)
total = result.count()
frauds = result.filter("Class = 1").count()
print(f"{target}: {total} rows, {frauds} frauds")

assert total == 284807, f"expected 284807 rows, got {total}"
assert frauds == 492, f"expected 492 frauds, got {frauds}"
