require 'simplecov'
SimpleCov.start

require 'sequel'
require 'test/unit'
require_relative '../lib/tdp'

require_relative 'test_basic'
require_relative 'test_upgrade'
require_relative 'test_validate'
require_relative 'test_init'
require_relative 'test_retrofit'
require_relative 'test_rename'
