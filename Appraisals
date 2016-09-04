%w(3.2 4.2 5.0).each do |version|
  appraise "rails.#{version}.activerecord" do
    gem 'activerecord', "~> #{version}.0"
    gem 'activesupport', "~> #{version}.0"
    gem 'activejob', "~> #{version}.0" if version >= '4.2'
    gem 'resque', require: false
    gem 'sidekiq', require: false
  end

  appraise "rails.#{version}.activerecord.kaminari" do
    gem 'activerecord', "~> #{version}.0"
    gem 'activesupport', "~> #{version}.0"
    gem 'activejob', "~> #{version}.0" if version >= '4.2'
    gem 'kaminari', '0.16.3', require: false
  end

  appraise "rails.#{version}.activerecord.will_paginate" do
    gem 'activerecord', "~> #{version}.0"
    gem 'activesupport', "~> #{version}.0"
    gem 'activejob', "~> #{version}.0" if version >= '4.2'
    gem 'will_paginate', require: false
  end
end

{ '4.0' => '4.2', '5.1' => '4.2' }.each do |(mongoid, activesupport)|
  appraise "rails.#{activesupport}.mongoid.#{mongoid}" do
    gem 'mongoid', "~> #{mongoid}.0"
    gem 'activesupport', "~> #{activesupport}.0"
    gem 'resque', require: false
    gem 'sidekiq', require: false
  end

  appraise "rails.#{activesupport}.mongoid.#{mongoid}.kaminari" do
    gem 'mongoid', "~> #{mongoid}.0"
    gem 'activesupport', "~> #{activesupport}.0"
    gem 'kaminari', '0.16.3', require: false
  end

  appraise "rails.#{activesupport}.mongoid.#{mongoid}.will_paginate" do
    gem 'mongoid', "~> #{mongoid}.0"
    gem 'activesupport', "~> #{activesupport}.0"
    gem 'will_paginate', require: false
  end
end

%w(4.38).each do |sequel|
  appraise "sequel.#{sequel}" do
    gem 'sequel', "~> #{sequel}.0"
    gem 'activesupport', '~> 5.0.0'
  end
end
