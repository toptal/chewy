[
  {rails: '4.2', es: '5', kaminari: '0.17'},
  {rails: '4.2', mongoid: '5.4', es: '5', kaminari: '0.17'},
  {rails: '5.2', es: '5'},
  {rails: '5.2', mongoid: '6.4', es: '5'},
  {rails: '5.2', sequel: '4.49', es: '5'},
  {rails: '6.0', es: '5'},
  {rails: '6.0', mongoid: 'master', es: '5'},
  {rails: '6.0', sequel: '5.24', es: '5'},
  {rails: '5.2', es: '6'},
  {rails: '5.2', mongoid: '6.4', es: '6'},
  {rails: '5.2', sequel: '4.49', es: '6'},
  {rails: '6.0', es: '7'},
  {rails: '6.0', mongoid: 'master', es: '7'},
  {rails: '6.0', sequel: '5.24', es: '7'}
].each do |config|
  appraise config.to_a.join('.') do
    gem 'elasticsearch', "~> #{config[:es]}.0"

    if config[:rails] >= '6.0'
      gem 'sqlite3', '~> 1.4.0'
    else
      gem 'sqlite3', '~> 1.3.6'
    end

    if config.key?(:mongoid)
      if config[:mongoid] == 'master'
        gem 'mongoid', github: 'mongodb/mongoid'
      else
        gem 'mongoid', "~> #{config[:mongoid]}.0"
      end
    elsif config.key?(:sequel)
      gem 'sequel', "~> #{config[:sequel]}.0"
    else
      gem 'activerecord', "~> #{config[:rails]}.0"
    end
    gem 'activesupport', "~> #{config[:rails]}.0"

    unless config.key?(:sequel)
      gem 'activejob', "~> #{config[:rails]}.0"
      gem 'resque', require: false
      gem 'shoryuken', require: false
      gem 'aws-sdk-sqs', require: false
      gem 'sidekiq', require: false
    end

    gem 'kaminari', "~> #{config[:kaminari] || '1.1'}.0", require: false
    gem 'will_paginate', require: false

    gem 'parallel', require: false
  end
end
