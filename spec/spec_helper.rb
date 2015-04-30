require File.expand_path( '../../lib/schlepp', __FILE__ )

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = [:should, :expect] }
  config.mock_with(:rspec) { |c| c.syntax = [:should, :expect] }
end
