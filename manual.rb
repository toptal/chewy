# load it to a pry instance and run `simple_test`

require 'active_record'
require_relative 'lib/chewy'

host = ENV['ES_HOST'] || 'localhost'
port = ENV['ES_PORT'] || 9206

Chewy.settings = {
  host: "#{host}:#{port}",
  wait_for_status: 'green',
  index: {
    number_of_shards: 1,
    number_of_replicas: 0
  }
}

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: 'file::memory:?cache=shared', pool: 10)
ActiveRecord::Base.logger = Logger.new('/dev/null')
ActiveRecord::Base.raise_in_transactional_callbacks = true if ActiveRecord::Base.respond_to?(:raise_in_transactional_callbacks)

ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS 'comments'")

ActiveRecord::Schema.define do
  create_table :comments do |t|
    t.column :content, :string
    t.column :comment_type, :string
    t.column :parent, :integer
    t.column :updated_at, :datetime
  end
end

class Comment < ActiveRecord::Base; end

class CommentsIndex < Chewy::Index
  define_type Comment do
    field :content
    field :comment_type, type: :join, relations: {question: [:answer, :comment], answer: :vote}, value: -> { parent.present? ? {name: comment_type, parent: parent} : comment_type }
  end
end

def create_existing_comments
  @existing_comments = [
    Comment.create!(id: 1, content: 'Where is Nemo?', comment_type: :question),
    Comment.create!(id: 2, content: 'Here.', comment_type: :answer, parent: 1),
    Comment.create!(id: 31, content: 'What is the best programming language?', comment_type: :question)
  ]
end

def create_new_comments
  @new_comments = [
    Comment.create!(id: 3, content: 'There!', comment_type: :answer, parent: 1),
    Comment.create!(id: 4, content: 'Yes, he is here.', comment_type: :vote, parent: 2),

    Comment.create!(id: 11, content: 'What is the sense of the universe?', comment_type: :question),
    Comment.create!(id: 12, content: 'I don\'t know.', comment_type: :answer, parent: 11),
    Comment.create!(id: 13, content: '42', comment_type: :answer, parent: 11),
    Comment.create!(id: 14, content: 'I think that 42 is a correct answer', comment_type: :vote, parent: 13),

    Comment.create!(id: 21, content: 'How are you?', comment_type: :question),

    Comment.create!(id: 32, content: 'Ruby', comment_type: :answer, parent: 31)
  ]
end

def simple_test
  Object.send(:remove_const, :Rails) if defined?(Rails)
  CommentsIndex.reset!

  create_existing_comments
  CommentsIndex.import!
  create_new_comments
  CommentsIndex.import!

  children_ids = CommentsIndex.query(has_parent: {parent_type: 'question', query: {match: {content: 'universe' }}}).pluck(:_id).sort

  raise 'Invalid children found' unless children_ids == ['12', '13']

  puts '==== Correctly found children'
end
