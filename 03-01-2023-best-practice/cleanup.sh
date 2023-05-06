#!/usr/bin/env bash
set -e

fluvio cloud connector delete helsinki-mqtt
fluvio cloud connector delete helsinki-sql
fluvio smartmodule delete infinyon/jolt@0.1.0
fluvio smartmodule delete infinyon/json-sql@0.1.0
fluvio topic delete helsinki
