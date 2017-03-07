#!/usr/bin/env ruby

require 'daemons'
require 'pathname'
require 'ffi-rzmq'
require 'syslog'
require 'json'
require_relative './live-test-base'

def source(file, vars)
  # Replace the specified variables in our environment with those read from file.
  # Do this by sourcing the file in bash, exporting the variables and then printing the
  # environment back out.  Then read the printed-out environment back in to this Ruby
  # process.
  ENV.replace(eval(`/bin/bash -c 'source #{file} && export #{vars.join " "} && ruby -e "p ENV"'`))
end

def raise_alarm(zmq, status)

  data = {:dep_id => ENV['deployment_id'], :test_type => "basic", :test_worker => ENV['test_worker_id'], :status => status}.to_json
  puts data
  zmq.send_string data

end

path = Pathname.new("/var/log/clearwater-live-verification/");
Daemons.run_proc("clearwater-live-verification",
                 dir_mode: :normal,
                 dir: path) do

  ctx = ZMQ::Context.new(1)
  zmq = ctx.socket(ZMQ::PUB)
  zmq.connect("tcp://84.39.50.209:5556")
  # Initially we don't know the state of the deployment
  raise_alarm(zmq, 0)

  loop do

    # Refresh the important environment variables from /etc/clearwater/config.
    #source("/etc/clearwater/config", ["home_domain", "ellis_address", "pcscf_address", "signup_key"])
    if ENV['ellis_hostname'] then
      ENV['ELLIS'] = ENV['ellis_hostname']
    else
      ENV['ELLIS'] = "ellis.#{ENV['home_domain']}"
    end
    if ENV['pcscf_hostname'] then
      ENV['PROXY'] = ENV['pcscf_hostname']
    else
      ENV['PROXY'] = "#{ENV['home_domain']}"
    end
    ENV['SIGNUP_CODE'] = ENV['signup_key']
    ENV['TRANSPORT'] = 'tcp'
    ENV['ELLIS_USER'] = ENV['test_worker_id'] + "@example.com"

    # These tests exit with their success code so catch the exit status here.
    begin
      run_tests_base(ENV['home_domain'], "Basic *")
    rescue SystemExit => e
      success = e.status
    end

    if success == 0 then
      # Tests passed - clear the alarm
      raise_alarm(zmq, 1)
    else
      # Tests failed - raise the critical alarm
      raise_alarm(zmq, 0)

      # Sleep for a bit (failing the test can happen very fast and we don't
      # want to DoS the deployment.
      sleep 30
    end
  end
end
