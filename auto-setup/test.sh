#!/bin/sh

jsonfilter -i config.json -e @.rathole_remote_addr
jsonfilter -i config.json -e @.rathole_default_token
