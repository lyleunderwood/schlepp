namespace :schlepp do

  desc "Process all Burdens"
  task :process_all => :environment do
    Schlepp::Burden.process
  end

  desc "Process the Burden with the given label"
  task :process, [:label] => :environment do |t, args|
    unless Schlepp::Burden.process(args.label.to_sym)
      fail "Couldn't find Burden: #{args.label}"
    end
  end
end