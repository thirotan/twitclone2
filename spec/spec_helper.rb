require 'rspec'
require 'rack/test'
require 'factory_girl'

FactoryGirl.definition_file_paths.unshift File.expand_path('./spec/factories', __FILE__)
FactoryGirl.find_definitions

RSpec.configure do |config|
  config.include Rack::Test::Methods
  config.include FactoryGirl::Syntax::Methods
end

