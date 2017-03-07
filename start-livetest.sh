#!/bin/bash

source /etc/profile.d/rvm.sh
cd repos/vnfs/vims-test/
bundle exec lib/daemon.rb run
