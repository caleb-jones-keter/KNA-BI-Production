# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {
# META     "lakehouse": {
# META       "default_lakehouse": "624ea251-e87f-45d7-8358-a55b3fa46385",
# META       "default_lakehouse_name": "NA_Supply_Chain",
# META       "default_lakehouse_workspace_id": "8e2b746d-3224-4a82-8467-a2800eef337e",
# META       "known_lakehouses": [
# META         {
# META           "id": "624ea251-e87f-45d7-8358-a55b3fa46385"
# META         },
# META         {
# META           "id": "be5e5c20-9808-4724-9f8d-cc5502142d75"
# META         }
# META       ]
# META     }
# META   }
# META }

# CELL ********************

from pyspark.sql.functions import col, sum, concat_ws, log, exp, log1p, abs
from pyspark.ml.feature import VectorAssembler, StringIndexer
from pyspark.ml import Pipeline

#### PREPPING THE DATA ####

df = spark.read.table("`NA_Supply_Chain`.`dbo`.`FACT Armada LTL History USA`")

df.printSchema()

## verify we have good data
df.select(
    "Weight",
    "Freight Class",
    "Distance",
    "Origin Zip3",
    "Dest Zip3",
    "Charge Total"
).summary().show()

## Check for missing values
df.select(
    [
        sum(col(c).isNull().cast("int")).alias(c)
        for c in [
            "Weight",
            "Freight Class",
            "Distance",
            "Origin Zip3",
            "Dest Zip3",
            "Charge Total"
        ]
    ]
).show()

## Filter out bad rows
model_df = df.filter(
    (col("Weight") > 0) &
    (col("Distance") > 0) &
    (col("Charge Total") > 0)
)
## Filter out top 1% of Charges
q99 = model_df.approxQuantile("Charge Total", [0.99], 0.01)[0]

model_df = model_df.filter(col("Charge Total") <= q99)


## Transform Weight and Distance
model_df = model_df.withColumn(
    "LogWeight",
    log1p(col("Weight"))
)

model_df = model_df.withColumn(
    "LogDistance",
    log1p(col("Distance"))
)

## Create lane feature
# model_df = model_df.withColumn(
#     "Lane",
#     concat_ws("_", col("Origin Zip3"), col("Dest Zip3"))
# )

model_df.select(
    "Weight",
    "Freight Class",
    "Distance",
    "Origin Zip3",
    "Dest Zip3",
    "Charge Total"
).summary().show()

# print("Unique Lanes:", model_df.select("Lane").distinct().count())


## Convert string categories into numeric indexes

freight_indexer = StringIndexer(
    inputCol="Freight Class",
    outputCol="FreightClassIndex",
    handleInvalid="keep"
)

origin_indexer = StringIndexer(
    inputCol="Origin Zip3",
    outputCol="OriginZipIndex",
    handleInvalid="keep"
)

dest_indexer = StringIndexer(
    inputCol="Dest Zip3",
    outputCol="DestZipIndex",
    handleInvalid="keep"
)

# lane_indexer = StringIndexer(
#     inputCol="Lane",
#     outputCol="LaneIndex",
#     handleInvalid="keep"
# )


#### Build feature vector
## VERSION A
# assembler = VectorAssembler(
#     inputCols=[
#         "Weight",
#         "Distance",
#         "FreightClassIndex",
#         "LaneIndex"
#     ]
#     ,
#     outputCol="features"
# )

## VERSION B
# assembler = VectorAssembler(
#     inputCols=[
#         "Weight",
#         "Distance",
#         "FreightClassIndex",
#         "OriginZipIndex",
#         "DestZipIndex"
#     ]
#     ,
#     outputCol="features"
# )

## VERSION C
assembler = VectorAssembler(
    inputCols=[
        "LogWeight",
        "LogDistance",
        "FreightClassIndex",
        "OriginZipIndex",
        "DestZipIndex"
    ],
    outputCol="features"
)


## Build a pipeline

pipeline = Pipeline(stages=[
    freight_indexer,
    origin_indexer,
    dest_indexer,
    assembler
])


## Fit the pipeline
pipeline_model = pipeline.fit(model_df)

## Transform the data
feature_df = pipeline_model.transform(model_df)

## Check the Result
# feature_df.select(
#     "Weight",
#     "Distance",
#     "Freight Class",
#     "FreightClassIndex",
#     "OriginZipIndex",
#     "DestZipIndex",    
#     # "Lane",
#     # "LaneIndex",
#     "features",
#     "Charge Total"
# ).show(5, truncate=False)

feature_df.select("Charge Total").summary().show()

print(
    feature_df.approxQuantile(
        "Charge Total",
        [0.5, 0.9, 0.95, 0.99],
        0.01
    )
)

## Log the values and Split into training and testing data
feature_df = feature_df.withColumn(
    "label",
    log(col("Charge Total"))
)

train_df, test_df = feature_df.randomSplit([0.8, 0.2], seed=42)

print("Training Rows:", train_df.count())
print("Testing Rows:", test_df.count())
train_df = train_df.cache()
test_df = test_df.cache()


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

#### BUILDING THE MODEL ####

# from pyspark.sql.functions import col
from pyspark.ml.regression import GBTRegressor
from pyspark.ml.evaluation import RegressionEvaluator

## Create GBT model
gbt = GBTRegressor(
    featuresCol="features",
    labelCol="label",
    maxIter=100,
    maxDepth=5,
    stepSize=0.1,
    maxBins=1024,
    seed = 42
)


## Train model
gbt_model = gbt.fit(train_df)

## Generate predictions
predictions = gbt_model.transform(test_df)

log_rmse_evaluator = RegressionEvaluator(
    labelCol="label",
    predictionCol="prediction",
    metricName="rmse"
)

log_r2_evaluator = RegressionEvaluator(
    labelCol="label",
    predictionCol="prediction",
    metricName="r2"
)

print("Log RMSE:", log_rmse_evaluator.evaluate(predictions))
print("Log R2:", log_r2_evaluator.evaluate(predictions))

## Convert prediction back to dollars
predictions = predictions.withColumn(
    "predicted_charge",
    exp(col("prediction"))
)

## Actual dollar values
predictions = predictions.withColumn(
    "actual_charge",
    col("Charge Total")
)

## Show predictions
predictions.select(
    "Weight",
    "Distance",
    "Freight Class",
    "Origin Zip3",
    "Dest Zip3",
    "actual_charge",
    "predicted_charge"
).show(20, False)

## RMSE Evaluation
rmse_evaluator = RegressionEvaluator(
    labelCol="actual_charge",
    predictionCol="predicted_charge",
    metricName="rmse"
)

rmse = rmse_evaluator.evaluate(predictions)

print("RMSE:", rmse)

## MAE Evaluation
mae_evaluator = RegressionEvaluator(
    labelCol="actual_charge",
    predictionCol="predicted_charge",
    metricName="mae"
)

mae = mae_evaluator.evaluate(predictions)

print("MAE:", mae)

## R^2 Evaluation
r2_evaluator = RegressionEvaluator(
    labelCol="actual_charge",
    predictionCol="predicted_charge",
    metricName="r2"
)

r2 = r2_evaluator.evaluate(predictions)

print("R2:", r2)

## MAPE

predictions = predictions.withColumn(
    "APE",
    abs(col("actual_charge") - col("predicted_charge")) / col("actual_charge")
)

predictions.selectExpr(
    "avg(APE) as MAPE"
).show()




# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
