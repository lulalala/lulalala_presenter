# frozen_string_literal: true
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
# load Rails first
require 'rails'

# load the plugin
require 'lulalala_presenter'

# needs to load the app next
require 'fake_app/fake_app'

require 'test/unit/rails/test_help'

# The pages are server-rendered html, so no browser (or Capybara server) is needed.
require 'capybara/rails'
Capybara.default_driver = :rack_test

class ActionDispatch::IntegrationTest
  include Capybara::DSL

  # Rails' system testing hook switches Capybara to selenium before each test.
  setup { Capybara.current_driver = :rack_test }
end

module DatabaseDeleter
  def setup
    Book.delete_all
    Author.delete_all
    Movie.delete_all
    super
  end
end

Test::Unit::TestCase.send :prepend, DatabaseDeleter

CreateAllTables.up unless ActiveRecord::Base.connection.table_exists? 'authors'
