import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from awsgluedq.transforms import EvaluateDataQuality

args = getResolvedOptions(sys.argv, ['csvTransformation'])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['csvTransformation'], args)

# Default ruleset used by all target nodes with data quality enabled
DEFAULT_DATA_QUALITY_RULESET = """
    Rules = [
        ColumnCount > 0
    ]
"""

# Script generated for node AWS Glue Data Catalog
AWSGlueDataCatalog_node1769546723816 = glueContext.create_dynamic_frame.from_catalog(database="csv-data-pipline-catalog", table_name="weather_data_csv", transformation_ctx="AWSGlueDataCatalog_node1769546723816")

# Script generated for node Change Schema
ChangeSchema_node1769547381084 = ApplyMapping.apply(frame=AWSGlueDataCatalog_node1769546723816, mappings=[("ghi", "long", "ghi", "long"), ("dhi", "long", "dhi", "long"), ("precip", "double", "precip", "double"), ("timestamp_utc", "string", "timestamp_utc", "string"), ("temp", "double", "temp", "double"), ("app_temp", "double", "app_temp", "double"), ("dni", "long", "dni", "long"), ("snow_depth", "long", "snow_depth", "long"), ("wind_cdir", "string", "wind_cdir", "string"), ("rh", "long", "rh", "long"), ("pod", "string", "pod", "string"), ("pop", "long", "pop", "long"), ("ozone", "long", "ozone", "long"), ("clouds_hi", "long", "clouds_hi", "long"), ("clouds", "long", "clouds", "long"), ("vis", "double", "vis", "double"), ("wind_spd", "double", "wind_spd", "double"), ("wind_cdir_full", "string", "wind_cdir_full", "string"), ("slp", "long", "slp", "long"), ("datetime", "string", "datetime", "string"), ("ts", "long", "ts", "long"), ("pres", "long", "pres", "long"), ("dewpt", "double", "dewpt", "double"), ("uv", "long", "uv", "long"), ("clouds_mid", "long", "clouds_mid", "long"), ("wind_dir", "long", "wind_dir", "long"), ("snow", "long", "snow", "long"), ("clouds_low", "long", "clouds_low", "long"), ("solar_rad", "double", "solar_rad", "double"), ("wind_gust_spd", "double", "wind_gust_spd", "double"), ("timestamp_local", "string", "timestamp_local", "string"), ("`description(output)`", "string", "`description(output)`", "string"), ("code", "long", "code", "long")], transformation_ctx="ChangeSchema_node1769547381084")

# Script generated for node Amazon S3
EvaluateDataQuality().process_rows(frame=ChangeSchema_node1769547381084, ruleset=DEFAULT_DATA_QUALITY_RULESET, publishing_options={"dataQualityEvaluationContext": "EvaluateDataQuality_node1769546718242", "enableDataQualityResultsPublishing": True}, additional_options={"dataQualityResultsPublishing.strategy": "BEST_EFFORT", "observations.scope": "ALL"})
AmazonS3_node1769547446076 = glueContext.write_dynamic_frame.from_options(frame=ChangeSchema_node1769547381084, connection_type="s3", format="csv", connection_options={"path": "s3://weather-csv-final-data", "partitionKeys": []}, transformation_ctx="AmazonS3_node1769547446076")

job.commit()