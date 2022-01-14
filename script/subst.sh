#!/bin/bash

set -a
source data/arc.env
set +a

envsubst < "${1}"
