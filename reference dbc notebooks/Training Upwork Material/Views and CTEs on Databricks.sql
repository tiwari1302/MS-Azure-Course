-- Databricks notebook source
-- MAGIC %md-sandbox
-- MAGIC 
-- MAGIC <div style="text-align: center; line-height: 0; padding-top: 9px;">
-- MAGIC   <img src="https://databricks.com/wp-content/uploads/2018/03/db-academy-rgb-1200px.png" alt="Databricks Learning" style="width: 600px">
-- MAGIC </div>

-- COMMAND ----------

-- MAGIC 
-- MAGIC %md
-- MAGIC # Views and CTEs on Databricks
-- MAGIC In this demonstration, you will create and explore views and common table expressions (CTEs).
-- MAGIC 
-- MAGIC ## Learning Objectives
-- MAGIC By the end of this lesson, you will be able to:
-- MAGIC * Use Spark SQL DDL to define views
-- MAGIC * Run queries that use common table expressions
-- MAGIC 
-- MAGIC 
-- MAGIC 
-- MAGIC **Resources**
-- MAGIC * [Create View - Databricks Docs](https://docs.databricks.com/spark/latest/spark-sql/language-manual/sql-ref-syntax-ddl-create-view.html)
-- MAGIC * [Common Table Expressions - Databricks Docs](https://docs.databricks.com/spark/latest/spark-sql/language-manual/sql-ref-syntax-qry-select-cte.html)

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Classroom Setup
-- MAGIC The following cell is for setting up the classroom. It simply installs a python library that is used to generate variables, configure a temporary directory, and import a dataset we will use later in the lesson. 

-- COMMAND ----------

-- MAGIC %python
-- MAGIC import sys, subprocess, os
-- MAGIC subprocess.check_call([sys.executable, "-m", "pip", "install", "git+https://github.com/databricks-academy/user-setup"])
-- MAGIC 
-- MAGIC from dbacademy import LessonConfig
-- MAGIC LessonConfig.configure(course_name="Databases Tables and Views on Databricks", use_db=False)
-- MAGIC LessonConfig.install_datasets(silent=True)

-- COMMAND ----------

-- MAGIC %python 
-- MAGIC dbutils.widgets.text("username", LessonConfig.clean_username)
-- MAGIC dbutils.widgets.text("working_directory", LessonConfig.working_dir)

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Important Note
-- MAGIC In order to keep from conflicting with other users and to ensure the code below runs correctly, there are places in the code that use widgets to store and use variables (e.g., `${username}`). You should not have to change these in order to make the code work correctly.

-- COMMAND ----------

-- MAGIC %md 
-- MAGIC We start by creating a table of data we can use for the demonstration.

-- COMMAND ----------

CREATE DATABASE IF NOT EXISTS ${username}_training_database;
USE ${username}_training_database;

-- mode "FAILFAST" will abort file parsing with a RuntimeException if any malformed lines are encountered
CREATE OR REPLACE TEMPORARY VIEW temp_delays USING CSV OPTIONS (
  path '${working_directory}/datasets/flights/departuredelays.csv',
  header "true",
  mode "FAILFAST"
);
CREATE OR REPLACE TABLE external_table LOCATION '${working_directory}/external_table' AS
  SELECT * FROM temp_delays;

SELECT * FROM external_table;

-- COMMAND ----------

-- MAGIC %md ## Views
-- MAGIC Let's create a view that contains only the data where the origin is 'ABQ' and the destination is 'LAX'.

-- COMMAND ----------

CREATE OR REPLACE VIEW view_delays_ABQ_LAX AS
SELECT * FROM external_table WHERE origin = 'ABQ' AND destination = 'LAX';
SELECT * FROM view_delays_ABQ_LAX;

-- COMMAND ----------

-- MAGIC %md 
-- MAGIC To show a list of tables (and views), we use the `SHOW TABLES` command.  
-- MAGIC   
-- MAGIC Note that the `view_delays_abq_lax` view is in the list. If we detach from, and reattach to, the cluster and reload the list of tables, view_delays_abq_lax persists. This is because View metadata (name, location, etc.) are stored in the metastore.
-- MAGIC 
-- MAGIC (The command `USE ${username}_training_database;` is used after reattaching to the cluster because state is lost when the SparkSession is deleted)

-- COMMAND ----------

USE ${username}_training_database;
SHOW tables;

-- COMMAND ----------

-- MAGIC %md 
-- MAGIC Now, let's create a temporary view. The syntax is very similar but adds `TEMPORARY` to the command. 

-- COMMAND ----------

CREATE OR REPLACE TEMPORARY VIEW temp_view AS
SELECT * FROM external_table WHERE delay > 120 ORDER BY delay ASC;
SELECT * FROM temp_view;

-- COMMAND ----------

-- MAGIC %md 
-- MAGIC Let's again show list of tables (and views).  
-- MAGIC   
-- MAGIC Two things we note are that the `temp_view` view is in the list and that `temp_view` is marked `isTemporary`.  
-- MAGIC   
-- MAGIC If we detach from, and reattach to, the cluster and reload the list of tables, `temp_view` is deleted. This is because temporary view metadata (name, location, etc.) are not stored in the metastore. When we detach from the cluster, the Spark session is deleted, which deletes the temporary view.

-- COMMAND ----------

USE ${username}_training_database;
SHOW TABLES;

-- COMMAND ----------

-- MAGIC %md 
-- MAGIC Let's now create a global temporary view. We add `GLOBAL` to the command. This view is just like the temporary view above, but it is different in one important way. It is added to the `global_temp` database that exists on the cluster. As long as the cluster is running, this database persists, and any notebooks attached to the cluster can access its global temporary views.  
-- MAGIC   
-- MAGIC Note when we use global temporary views, we have to prefix them with `global_temp.` since we are accessing the `global_temp` database. 

-- COMMAND ----------

CREATE OR REPLACE GLOBAL TEMPORARY VIEW global_temp_view_distance AS
SELECT * FROM external_table WHERE distance > 1000;
SELECT * FROM global_temp.global_temp_view_distance;

-- COMMAND ----------

-- MAGIC %md 
-- MAGIC Again, global temporary views are available to any notebook attached to the cluster, including
-- MAGIC - New notebooks
-- MAGIC - This notebook, even if it is detached from, and reattached to, the cluster

-- COMMAND ----------

SELECT * FROM global_temp.global_temp_view_distance;

-- COMMAND ----------

-- MAGIC %md 
-- MAGIC One thing to note is that global temporary views do not show in the list of tables.

-- COMMAND ----------

USE ${username}_training_database;
SHOW TABLES;

-- COMMAND ----------

-- MAGIC %md 
-- MAGIC ## Common Table Expressions (CTEs)
-- MAGIC CTEs can be used in a variety of contexts. Below, are a few examples of the different ways a CTE can be used in a query. First, an example of making multiple column aliases using a CTE.

-- COMMAND ----------

WITH flight_delays(
  total_delay_time,
  origin_airport,
  destination_airport
) AS (
  SELECT
    delay,
    origin,
    destination
  FROM
    external_table
)
SELECT
  *
FROM
  flight_delays
WHERE
  total_delay_time > 120
  AND origin_airport = "ATL"
  AND destination_airport = "DEN";

-- COMMAND ----------

-- MAGIC %md 
-- MAGIC Next, is an example of a CTE in a CTE definition.

-- COMMAND ----------

WITH lax_bos AS (
  WITH origin_destination (origin_airport, destination_airport) AS (
    SELECT
      origin,
      destination
    from
      external_table
  )
  SELECT
    *
  FROM
    origin_destination
  WHERE
    origin_airport = 'LAX'
    AND destination_airport = 'BOS'
)
SELECT
  count(origin_airport) AS `Total Flights from LAX to BOS`
FROM
  lax_bos;

-- COMMAND ----------

-- MAGIC %md 
-- MAGIC Now, here is an example of a CTE in a subquery.

-- COMMAND ----------

SELECT
  max(total_delay) AS `Longest Delay (in minutes)`
FROM
  (
    WITH delayed_flights(total_delay) AS (
      SELECT
        delay
      from
        external_table
    )
    SELECT
      *
    FROM
      delayed_flights
  );

-- COMMAND ----------

-- MAGIC %md 
-- MAGIC We can also use a CTE in a subquery expression.

-- COMMAND ----------

SELECT
  (
    WITH distinct_origins AS (
      SELECT DISTINCT origin FROM external_table
    )
    SELECT
      count(origin)
    FROM
      distinct_origins
  ) AS `Number of Different Origin Airports`;

-- COMMAND ----------

-- MAGIC %md 
-- MAGIC Finally, here is a CTE in a CREATE VIEW statement.

-- COMMAND ----------

CREATE OR REPLACE VIEW BOS_LAX AS
WITH origin_destination(origin_airport, destination_airport) AS 
(SELECT origin, destination FROM external_table)
SELECT * FROM origin_destination
WHERE origin_airport = 'BOS' AND destination_airport = 'LAX';
SELECT count(origin_airport) AS `Number of Delayed Flights from BOS to LAX` FROM BOS_LAX;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Clean up 
-- MAGIC We first drop the training database.

-- COMMAND ----------

DROP DATABASE ${username}_training_database CASCADE;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC Finally, we delete the working directory.

-- COMMAND ----------

-- MAGIC %python 
-- MAGIC path = dbutils.widgets.get("working_directory")
-- MAGIC dbutils.fs.rm(path, True)

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC &copy; 2021 Databricks, Inc. All rights reserved.<br/>
-- MAGIC Apache, Apache Spark, Spark and the Spark logo are trademarks of the <a href="http://www.apache.org/">Apache Software Foundation</a>.<br/>
-- MAGIC <br/>
-- MAGIC <a href="https://databricks.com/privacy-policy">Privacy Policy</a> | <a href="https://databricks.com/terms-of-use">Terms of Use</a> | <a href="http://help.databricks.com/">Support</a>
