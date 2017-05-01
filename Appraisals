appraise 'rails.4.2.activerecord' do
  gem 'activerecord', '~> 4.2.0'
  gem 'activesupport', '~> 4.2.0'

  gem 'activejob', '~> 4.2.0'
  gem 'resque', require: false
  gem 'sidekiq', require: false

  gem 'kaminari', '~> 0.17.0', require: false
  gem 'will_paginate', require: false
end

%w(4.2 5.0).each do |activesupport|
  appraise "rails.#{activesupport}.activerecord" do
    gem 'activerecord', "~> #{activesupport}.0"
    gem 'activesupport', "~> #{activesupport}.0"

    gem 'activejob', "~> #{activesupport}.0"
    gem 'resque', require: false
    gem 'sidekiq', require: false

    gem 'kaminari-core', '~> 1.0.0', require: false
    gem 'will_paginate', require: false
  end
end

appraise 'rails.4.2.mongoid.5.1' do
  gem 'mongoid', '~> 5.1.0'
  gem 'activesupport', '~> 4.2.0'

  gem 'activejob', '~> 4.2.0'
  gem 'resque', require: false
  gem 'sidekiq', require: false

  gem 'kaminari', '~> 0.17.0', require: false
  gem 'will_paginate', require: false
end

%w(6.0 6.1).each do |mongoid|
  appraise "rails.5.1.mongoid.#{mongoid}" do
    gem 'mongoid', "~> #{mongoid}.0"
    gem 'activesupport', '~> 5.1.0'

    gem 'activejob', '~> 5.1.0'
    gem 'resque', require: false
    gem 'sidekiq', require: false

    gem 'kaminari-core', '~> 1.0.0', require: false
    gem 'will_paginate', require: false
  end
end

%w(4.45).each do |sequel|
  appraise "sequel.#{sequel}" do
    gem 'sequel', "~> #{sequel}.0"
    gem 'activesupport', '~> 5.0.0'

    gem 'kaminari-core', '~> 1.0.0', require: false
    gem 'will_paginate', require: false
  end
end
