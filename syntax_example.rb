require 'schlepp'

Schlepp::Burden.new do
  # all actions performed in this directory
  cd 'data/'

  # do the defined actions for every subfolder
  glob 'catalogs/*' do |dir|
    # once we've finished up here we're going to create the catalog
    dir.after do |dir|
      catalog = Catalog.create!(:name => dir.name)
    end

    # we've got a csv file
    file CSV do |csv|
      # or maybe csv.name = :glob => '*.csv'
      csv.name = 'Lifestyle.csv'

      # defaults to false, if true throws an error when file is not found
      csv.required = false

      csv.before do |csv|
        # maybe set the file descriptor specifically with csv.descriptor?
      end

      # how we determine if a line is junk
      csv.reject_line do |line|
        # line is an array, if it doesn't look good, throw it out
        line[1].blank?
      end

      csv.load_mapping 'lifestyle.yml'

      # which columns to group on, in order. this also determines how many args
      # will be sent to the map function, because how many groupings there are
      # defines the depth of the nesting. one grouping has the main line and 
      # sub lines, two groupings has sub sub lines.
      csv.group = [3, 6]

      csv.before_line do |line|
        # do something with the line
      end

      # product_line is a line, which is a hash generated from the line and the
      # mapping. it also has the method children to get sub groups of lines.
      csv.map do |product_line|
        product = Product.new({
          :name    => product_line[:name],
          :number  => product_line[:number],
          :catalog => dir.name
          :colors  => []
        })

        product.children.each do |color_line|
          color = Color.new({
            :name  => color_line[:name],
            :code  => color_line[:code],
            :base  => color_line[:base],
            :sizes => []
          })

          color.children.each do |size_line|
            size = Size.new({
              :name => size_line[:name],
              :sort => size_line[:sort]
            })

            color.sizes << size
          end

          product.colors << color
        end

        product
      end

      csv.after_line do |product|
        product.save!
      end

      csv.after do |csv|
        # close up the file or something
      end

    end
  end
end
