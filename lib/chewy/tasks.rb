Dir[File.expand_path('../../tasks/*.rake', __FILE__)].sort.each do |file|
  load file
end
