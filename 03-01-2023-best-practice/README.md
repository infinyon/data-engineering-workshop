# Set up

Please follow the instruction in [InfinyOn Cloud](https://www.fluvio.io/docs/get-started/cloud/) to set up your InfinyOn Cloud account.

# City of Helsinki's Transportation Data

Helisnki City provides real-time transportation data via MQTT broker.  The data is in JSON format.  The data is available at `mqtt://mqtt.hsl.fi`.  Please see [Helsinki City's MQTT documentation](https://digitransit.fi/en/developers/apis/4-realtime-api/vehicle-positions/) for more information.

# Start MQTT Connector

Start an MQTT Connector to connect to the City of Helsinki's transportation data in real-time via their MQTT broker.

The `mqtt-conn.yaml` yaml is defined as follows:

```yaml

version: 0.5.2
name: helsinki-bus 
type: mqtt-source
topic: helsinki
direction: source
create-topic: true
parameters:
  mqtt_topic: "/hfp/v2/journey/ongoing/vp/+/+/+/#"
  payload_output_type: json
secrets:
  MQTT_URL: mqtt://mqtt.hsl.fi
  
```

Let's run it to start the connector:

```bash

fluvio cloud connector create --config mqtt-conn.yaml

```

Checkout your InfinyOn Cloud dashboard to see the topic and the inbound traffic metrics.

You can watch real-time traffic through the CLI by running:

```bash

fluvio consume helsinki

```

# Testing Transformation

Before we send data to Postgres, we'll perform a transformation.  We will use the `consume` command in the CLI to perform transformation. The CLI is connected to InfinyOn Cloud, and all transformations are performed in the Cloud before the results are sent to the CLI client. The yaml file `jolt.yaml` contains the transformation specification. 

## Testing Jolt Transformation

### Download Jolt Transformation from the Hub

SmartModule Hub is a place to share SmartModules. You can download the Jolt transformation from the Hub. The are 2 ways to download a SmartModule through the CLI or InfinyOn Cloud.

Let's use InfinyOn Cloud to download SmartModule:
* Click the Hub icon on the top/left menu bar
* Find `jolt` transformation SmartModule
* Click "Install" button

This operation downloads Jolt Transformation to your Cloud account.

You can confirm that `jolt` SmartModule has been downloaded by running:

```bash

 $ fluvio smartmodule list

   SMARTMODULE          SIZE     
  infinyon/jolt@0.1.0  564.0 KB 

 ```

 ### Running Jolt Transformation

Jolt is a DSL language for JSON to JSON transformation.  We defined the transformation specification is in the `jolt.yaml` file.  The transformation specification is in the [Jolt](https://intercom.help/godigibee/en/articles/4044359-transformer-getting-to-know-jolt). 

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

We pick subset of JSON fields in the original records and rename them.  In this case, we only care about latitude, logitude, vehicle, route, speed, and timestamp.  We also rename them to 'lat', 'long', 'vehicle', 'route', 'speed', and 'tst'.


Let's run the transformation locally:

```bash

$ fluvio consume helsinki --transforms-file jolt.yaml

{"lat":60.553262,"long":24.969189,"route":"9967","speed":0.0,"tst":"2023-03-01T06:04:57.140Z","vehicle":240}
.....

```

This way, you can test the transformation before sending the data to downstream systems.


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

First drop exiting table if it exists:

```sql
drop table speed;
```

Then create new table `speed`:

```sql
create table speed(lat float, long float, vehicle integer);
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

Similar to Jolt, we need to download SQL SmartModule from the Hub. The `json-sql` SmartModule translates JSON records into SQL commands.

* Click the Hub icon on the top/left
* Find `json-sql` transformation in the SmartModules list
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

```yaml

name: helsinki-speed
type: sql-sink
version: 0.1.1
topic: helsinki
parameters:
 database-url: "postgres://user:password@db.postgreshost.example/dbname"
 rust_log: "sql_sink=INFO,sqlx=WARN"
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
  - uses: infinyon/json-sql@0.1.0
    with:
      mapping:
        table: "speed"
        map-columns:
          "lat":
            json-key: "lat"
            value:
              type: "float"
              default: "0"
              required: true
          "long":
            json-key: "long"
            value:
              type: "float"
              required: true
          "vehicle":
            json-key: "vehicle"
            value:
              type: "int"
              required: true
              
```

Please change `database-url` field to your specific Postgres URL.

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

This MQTT connector uses large amount of data which will consume your Cloud account credits rapidly.  
You can clean up objects by running:

```bash

$ ./cleanup.sh


```
