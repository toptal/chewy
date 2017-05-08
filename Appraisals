%w(4.2 5.0).each do |activesupport|
  appraise "rails.#{activesupport}.activerecord" do
    gem 'activerecord', "~> #{activesupport}.0"
    gem 'activesupport', "~> #{activesupport}.0"
    gem 'activejob', "~> #{activesupport}.0"
    gem 'resque', require: false
    gem 'sidekiq', require: false
  end

  appraise "rails.#{activesupport}.activerecord.kaminari" do
    gem 'activerecord', "~> #{activesupport}.0"
    gem 'activesupport', "~> #{activesupport}.0"
    gem 'activejob', "~> #{activesupport}.0"
    gem 'kaminari', '~> 0.17.0', require: false
  end if activesupport == '4.2'

  appraise "rails.#{activesupport}.activerecord.kaminari_one" do
    gem 'activerecord', "~> #{activesupport}.0"
    gem 'activesupport', "~> #{activesupport}.0"
    gem 'activejob', "~> #{activesupport}.0"
    gem 'kaminari-core', '~> 1.0.0', require: false
    gem 'kaminari-activerecord', require: false
  end if activesupport == '5.0'

  appraise "rails.#{activesupport}.activerecord.will_paginate" do
    gem 'activerecord', "~> #{activesupport}.0"
    gem 'activesupport', "~> #{activesupport}.0"
    gem 'activejob', "~> #{activesupport}.0"
    gem 'will_paginate', require: false
  end
end

{ '5.1' => '4.2', '6.0' => '5.0' }.each do |(mongoid, activesupport)|
  appraise "rails.#{activesupport}.mongoid.#{mongoid}" do
    gem 'mongoid', "~> #{mongoid}.0"
    gem 'activesupport', "~> #{activesupport}.0"
    gem 'resque', require: false
    gem 'sidekiq', require: false
  end

  appraise "rails.#{activesupport}.mongoid.#{mongoid}.kaminari" do
    gem 'mongoid', "~> #{mongoid}.0"
    gem 'activesupport', "~> #{activesupport}.0"
    gem 'kaminari', '~> 0.17.0', require: false
  end if activesupport == '4.2'

  appraise "rails.#{activesupport}.mongoid.#{mongoid}.kaminari_one" do
    gem 'mongoid', "~> #{mongoid}.0"
    gem 'activesupport', "~> #{activesupport}.0"
    gem 'kaminari-core', '~> 1.0.0', require: false
    gem 'kaminari-mongoid', require: false
  end if activesupport == '5.0'

  appraise "rails.#{activesupport}.mongoid.#{mongoid}.will_paginate" do
    gem 'mongoid', "~> #{mongoid}.0"
    gem 'activesupport', "~> #{activesupport}.0"
    gem 'will_paginate', require: false
  end
end

%w(4.42).each do |sequel|
  appraise "sequel.#{sequel}" do
    gem 'sequel', "~> #{sequel}.0"
    gem 'activesupport', '~> 5.0.0'
  end
end
