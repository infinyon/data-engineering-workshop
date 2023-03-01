# Set up

Please follow the instruction in [InfinyOn Cloud](https://www.fluvio.io/docs/get-started/cloud/) to set up your InfinyOn Cloud account.

# Start MQTT Connector

Start MQTT Connector that will connect to City of Helsinki's MQTT broker.

```bash

fluvio cloud connector create --config mqtt-conn.yaml

```

You should see Cloud dashboard with 1 Topic and Inbound Traffic metrics.

You can watch real-time traffic by running:

```bash

flvuio consume helsinki
```

# Testing Transformation

Before we send transform data to Postgres, let's test the transformation.  We will use consume command in the CLI to perform transformation in Cloud and send out to console.  The yaml file `jolt.yaml` contains the transformation specification.  Note that the transformation is done in the Cloud.

## Testing Jolt Transformation

### Download Jolt Transformation from the Hub

SmartModule Hub is a place to share SmartModules.  You can download the Jolt transformation from the Hub.  

In order to download, goto Cloud UI
* Click the Hub icon on the left
* Find `jolt` transformation from list of the SmartModules
* Click "Install" button

This will download Jolt Transformation to your Cloud account.

You can confirm that the transformation is downloaded by running:

```bash

 $ fluvio smartmodule list

   SMARTMODULE          SIZE     
  infinyon/jolt@0.1.0  564.0 KB 

 ```

 ### Running Jolt Transformation

The Jolt transformat allow JSON to JSON transformation.  The transformation specification is in the `jolt.yaml` file.  The transformation specification is in the [Jolt](https://intercom.help/godigibee/en/articles/4044359-transformer-getting-to-know-jolt). 

In the `jolt.yaml` file, you will see the following:

```yaml

transforms:
  - uses: infinyon/jolt@0.1.0
    with:
      spec:
        - operation: shift
          spec:
            payload:
              VP:
                lat: "lat"
                long: "long"
                veh: "vehicle"
                route: "route"
                spd: "speed"
                tst: "tst"
```

This pick subset of JSON fields and rename them.  In this case, we only care about field 'lat', 'long', 'vehicle', 'route', 'speed', and 'tst'.  We also rename them to 'lat', 'long', 'vehicle', 'route', 'speed', and 'tst'.



```bash

$ fluvio consume helsinki --transforms-file jolt.yaml

{"lat":60.553262,"long":24.969189,"route":"9967","speed":0.0,"tst":"2023-03-01T06:04:57.140Z","vehicle":240}
.....

```

This way, you can test the transformation before sending the data to downstream system.


# Sending JSON data to Postgres

Finally, we will send the transformed data to Postgres.  We will use combination of JOLT and SQL transformation to transform raw JSON to postgreSQL table.


## Set up Postgres account in ElephantSQL

Please follow the instruction in [ElephantSQL](https://www.elephantsql.com/) to set up your Postgres account.

## Download Postgres CLI

Follow instruction at https://www.pgcli.com/install to install Postgres CLI.

## Connect to Postgres

```bash

$ pgcli <your-postgres-url>

```

## Create table

In the PGCLI, create a table called `speed` with the following schema:

```sql

create table speed(lat float, long flo
 at, vehicle integer);

``` 

You can confirm that the table is created by running:

```bash

select * from speed;

+-----+------+---------+
| lat | long | vehicle |
|-----+------+---------|
+-----+------+---------+
SELECT 0

```

### Download SQL Transformation from the Hub

Similar to Jolt transformation, we will download SQL transformation from the Hub.  

* Click the Hub icon on the left
* Find `json-sql` transformation from list of the SmartModules
* Click "Install" button

You should see two SmartModule transformations in your Cloud account.

```bash

 $ fluvio smartmodule list

fluvio smartmodule list
  SMARTMODULE              SIZE     
  infinyon/json-sql@0.1.0  556.7 KB 
  infinyon/jolt@0.1.0      564.0 KB 
```

### Running Start SQL connector

The `sql-conn.yaml` file contains connector configuration as well as transformation specification.  
Please change `database-url` fiele to your Postgres URL.

You can start SQL connector by running:

```bash

fluvio cloud connector create --config sql-conn.yaml

```

This will start SQL connector that will connect to Postgres and send transformed data to Postgres.

You should see in the pgcli by running:

```bash

select * from speed;

+--------------------+--------------------+---------+
| lat                | long               | vehicle |
|--------------------+--------------------+---------|
| 60.2665901184082   | 25.03239631652832  | 1031    |
| 60.1678466796875   | 24.941499710083008 | 417     |
| 60.22567367553711  | 24.77872657775879  | 455     |
| 60.187068939208984 | 24.74913787841797  | 667     

```

You can perform group by operation like:

```

select avg(lat) from speed by group by
  vehicle

+--------------------+
| avg                |
|--------------------|
| 60.21897888183594  |
| 60.18917274475098  |


```

# Cleaning up

This MQTT connector consume large amount of data which will consume your Cloud account credits.  You can delete the connector by running:

```bash

$ fluvio cloud connector delete helsinki-speed
$ fluvio cloud connector delete helsinki-bus

```