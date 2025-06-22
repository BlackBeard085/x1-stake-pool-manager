#!/bin/bash

jq '.delegate = 0' config.json > tmp_config.json && mv tmp_config.json config.json
