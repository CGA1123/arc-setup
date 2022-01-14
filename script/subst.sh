#!/bin/bash

set -a
source arc.env
set +a

envsubst < "${1}"
