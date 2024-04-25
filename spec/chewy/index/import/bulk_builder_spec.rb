require 'spec_helper'

SimpleComment = Class.new do
  attr_reader :content, :comment_type, :commented_id, :updated_at, :id

  def initialize(hash)
    @id = hash['id']
    @content = hash['content']
    @comment_type = hash['comment_type']
    @commented_id = hash['commented_id']
    @updated_at = hash['updated_at']
  end

  def derived
    "[derived] #{content}"
  end
end

describe Chewy::Index::Import::BulkBuilder do
  before { Chewy.massacre }

  subject { described_class.new(index, to_index: to_index, delete: delete, fields: fields) }
  let(:index) { CitiesIndex }
  let(:to_index) { [] }
  let(:delete) { [] }
  let(:fields) { [] }

  describe '#bulk_body' do
    context 'simple bulk', :orm do
      before do
        stub_model(:city)
        stub_index(:cities) do
          index_scope City
          field :name, :rating
        end
      end
      let(:cities) { Array.new(3) { |i| City.create!(id: i + 1, name: "City#{i + 17}", rating: 42) } }

      specify { expect(subject.bulk_body).to eq([]) }

      context do
        let(:to_index) { cities }
        specify do
          expect(subject.bulk_body).to eq([
            {index: {_id: 1, data: {'name' => 'City17', 'rating' => 42}}},
            {index: {_id: 2, data: {'name' => 'City18', 'rating' => 42}}},
            {index: {_id: 3, data: {'name' => 'City19', 'rating' => 42}}}
          ])
        end
      end

      context do
        let(:delete) { cities }
        specify do
          expect(subject.bulk_body).to eq([
            {delete: {_id: 1}}, {delete: {_id: 2}}, {delete: {_id: 3}}
          ])
        end
      end

      context do
        let(:to_index) { cities.first(2) }
        let(:delete) { [cities.last] }
        specify do
          expect(subject).to receive(:data_for).with(cities.first).and_call_original
          expect(subject).to receive(:data_for).with(cities.second).and_call_original
          expect(subject.bulk_body).to eq([
            {index: {_id: 1, data: {'name' => 'City17', 'rating' => 42}}},
            {index: {_id: 2, data: {'name' => 'City18', 'rating' => 42}}},
            {delete: {_id: 3}}
          ])
        end

        context ':fields' do
          let(:fields) { %w[name] }
          specify do
            expect(subject).to receive(:data_for).with(cities.first, fields: [:name]).and_call_original
            expect(subject).to receive(:data_for).with(cities.second, fields: [:name]).and_call_original
            expect(subject.bulk_body).to eq([
              {update: {_id: 1, data: {doc: {'name' => 'City17'}}}},
              {update: {_id: 2, data: {doc: {'name' => 'City18'}}}},
              {delete: {_id: 3}}
            ])
          end
        end
      end
    end

    context 'custom id', :orm do
      before do
        stub_model(:city)
      end

      before do
        stub_index(:cities) do
          index_scope City
          root id: -> { name } do
            field :rating
          end
        end
      end

      let(:london) { City.create(id: 1, name: 'London', rating: 4) }

      specify do
        expect { CitiesIndex.import(london) }
          .to update_index(CitiesIndex).and_reindex(london.name)
      end

      context 'indexing' do
        let(:to_index) { [london] }

        specify do
          expect(subject.bulk_body).to eq([
            {index: {_id: london.name, data: {'rating' => 4}}}
          ])
        end
      end

      context 'destroying' do
        let(:delete) { [london] }

        specify do
          expect(subject.bulk_body).to eq([
            {delete: {_id: london.name}}
          ])
        end
      end
    end

    context 'crutches' do
      before do
        stub_index(:cities) do
          crutch :names do |collection|
            collection.to_h { |item| [item.id, "Name#{item.id}"] }
          end

          field :name, value: ->(o, c) { c.names[o.id] }
        end
      end

      let(:to_index) { [double(id: 42)] }

      specify do
        expect(subject.bulk_body).to eq([
          {index: {_id: 42, data: {'name' => 'Name42'}}}
        ])
      end

      context 'witchcraft' do
        before { CitiesIndex.witchcraft! }
        specify do
          expect(subject.bulk_body).to eq([
            {index: {_id: 42, data: {'name' => 'Name42'}}}
          ])
        end
      end
    end

    context 'empty ids' do
      before do
        stub_index(:cities) do
          field :name
        end
      end

      let(:to_index) { [{id: 1, name: 'Name0'}, double(id: '', name: 'Name1'), double(name: 'Name2')] }
      let(:delete) { [double(id: '', name: 'Name3'), {name: 'Name4'}, '', 2] }

      specify do
        expect(subject.bulk_body).to eq([
          {index: {_id: 1, data: {'name' => 'Name0'}}},
          {index: {data: {'name' => 'Name1'}}},
          {index: {data: {'name' => 'Name2'}}},
          {delete: {_id: {'name' => 'Name4'}}},
          {delete: {_id: 2}}
        ])
      end

      context do
        let(:fields) { %w[name] }

        specify do
          expect(subject.bulk_body).to eq([
            {update: {_id: 1, data: {doc: {'name' => 'Name0'}}}},
            {delete: {_id: {'name' => 'Name4'}}},
            {delete: {_id: 2}}
          ])
        end
      end
    end

    context 'with parents' do
      let(:index) { CommentsIndex }
      before do
        stub_model(:comment)
        stub_index(:comments) do
          index_scope Comment

          crutch :content_with_crutches do |collection| # collection here is a current batch of products
            collection.to_h { |comment| [comment.id, "[crutches] #{comment.content}"] }
          end

          field :content
          field :content_with_crutches, value: ->(comment, crutches) { crutches.content_with_crutches[comment.id] }
          field :comment_type, type: :join, relations: {question: %i[answer comment], answer: :vote, vote: :subvote}, join: {type: :comment_type, id: :commented_id}
        end
      end

      let!(:existing_comments) do
        [
          Comment.create!(id: 1, content: 'Where is Nemo?', comment_type: :question),
          Comment.create!(id: 2, content: 'Here.', comment_type: :answer, commented_id: 1),
          Comment.create!(id: 31, content: 'What is the best programming language?', comment_type: :question)
        ]
      end

      def do_raw_index_comment(options:, data:)
        CommentsIndex.client.index(options.merge(index: 'comments', refresh: true, body: data))
      end

      def raw_index_comment(comment)
        options = {id: comment.id, routing: root(comment).id}
        comment_type = comment.commented_id.present? ? {name: comment.comment_type, parent: comment.commented_id} : comment.comment_type
        do_raw_index_comment(
          options: options,
          data: {content: comment.content, comment_type: comment_type}
        )
      end

      def root(comment)
        current = comment
        # slow, but it's OK, as we don't have too deep trees
        current = Comment.find(current.commented_id) while current.commented_id
        current
      end

      before do
        CommentsIndex.reset! # initialize index
      end

      let(:comments) do
        [
          Comment.create!(id: 3, content: 'There!', comment_type: :answer, commented_id: 1),
          Comment.create!(id: 4, content: 'Yes, he is here.', comment_type: :vote, commented_id: 2),

          Comment.create!(id: 11, content: 'What is the sense of the universe?', comment_type: :question),
          Comment.create!(id: 12, content: 'I don\'t know.', comment_type: :answer, commented_id: 11),
          Comment.create!(id: 13, content: '42', comment_type: :answer, commented_id: 11),
          Comment.create!(id: 14, content: 'I think that 42 is a correct answer', comment_type: :vote, commented_id: 13),

          Comment.create!(id: 21, content: 'How are you?', comment_type: :question),

          Comment.create!(id: 32, content: 'Ruby', comment_type: :answer, commented_id: 31)
        ]
      end

      context 'when indexing a single object' do
        let(:to_index) { [comments[0]] }

        specify do
          expect(subject.bulk_body).to eq([
            {index: {_id: 3, routing: '1', data: {'content' => 'There!', 'content_with_crutches' => '[crutches] There!', 'comment_type' => {'name' => 'answer', 'parent' => 1}}}}
          ])
        end
      end

      context 'with raw import' do
        before do
          stub_index(:comments) do
            index_scope Comment
            default_import_options raw_import: ->(hash) { SimpleComment.new(hash) }

            crutch :content_with_crutches do |collection| # collection here is a current batch of products
              collection.to_h { |comment| [comment.id, "[crutches] #{comment.content}"] }
            end

            field :content
            field :content_with_crutches, value: ->(comment, crutches) { crutches.content_with_crutches[comment.id] }
            field :derived
            field :comment_type, type: :join, relations: {question: %i[answer comment], answer: :vote, vote: :subvote}, join: {type: :comment_type, id: :commented_id}
          end
        end

        let(:to_index) { [comments[0]].map { |c| SimpleComment.new(c.attributes) } } # id: 3
        let(:delete) { [existing_comments[0]].map { |c| c } } # id: 1

        specify do
          expected_data = {'content' => 'There!', 'content_with_crutches' => '[crutches] There!', 'derived' => '[derived] There!', 'comment_type' => {'name' => 'answer', 'parent' => 1}}
          expect(subject.bulk_body).to eq([
            {index: {_id: 3, routing: '1', data: expected_data}},
            {delete: {_id: 1, routing: '1'}}
          ])
        end
      end

      context 'when switching parents' do
        let(:switching_parent_comment) { comments[0].tap { |c| c.update!(commented_id: 31) } } # id: 3
        let(:removing_parent_comment) { comments[1].tap { |c| c.update!(commented_id: nil, comment_type: nil) } } # id: 4
        let(:converting_to_parent_comment) { comments[3].tap { |c| c.update!(commented_id: nil, comment_type: :question) } } # id: 12
        let(:converting_to_child_comment) { comments[6].tap { |c| c.update!(commented_id: 1, comment_type: :answer) } } # id: 21
        let(:fields) { %w[commented_id comment_type] }

        let(:to_index) { [switching_parent_comment, removing_parent_comment, converting_to_parent_comment, converting_to_child_comment] }

        before do
          existing_comments.each { |c| raw_index_comment(c) }
          comments.each { |c| raw_index_comment(c) }
        end

        specify do
          expect(subject.bulk_body).to eq([
            {delete: {_id: 3, routing: '1', parent: 1}},
            {index: {_id: 3, routing: '31', data: {'content' => 'There!', 'content_with_crutches' => '[crutches] There!', 'comment_type' => {'name' => 'answer', 'parent' => 31}}}},
            {delete: {_id: 4, routing: '1', parent: 2}},
            {index: {_id: 4, routing: '4', data: {'content' => 'Yes, he is here.', 'content_with_crutches' => '[crutches] Yes, he is here.', 'comment_type' => nil}}},
            {delete: {_id: 12, routing: '11', parent: 11}},
            {index: {_id: 12, routing: '12', data: {'content' => 'I don\'t know.', 'content_with_crutches' => '[crutches] I don\'t know.', 'comment_type' => 'question'}}},
            {delete: {_id: 21, routing: '21'}},
            {index: {_id: 21, routing: '1', data: {'content' => 'How are you?', 'content_with_crutches' => '[crutches] How are you?', 'comment_type' => {'name' => 'answer', 'parent' => 1}}}}
          ])
        end
      end

      context 'when indexing with grandparents' do
        let(:comments) do
          [
            Comment.create!(id: 3, content: 'Yes, he is here.', comment_type: :vote, commented_id: 2),
            Comment.create!(id: 4, content: 'What?', comment_type: :subvote, commented_id: 3)
          ]
        end
        let(:to_index) { comments }

        before do
          existing_comments.each { |c| raw_index_comment(c) }
        end

        specify do
          expected_data3 = {'content' => 'Yes, he is here.', 'content_with_crutches' => '[crutches] Yes, he is here.', 'comment_type' => {'name' => 'vote', 'parent' => 2}}
          expected_data4 = {'content' => 'What?', 'content_with_crutches' => '[crutches] What?', 'comment_type' => {'name' => 'subvote', 'parent' => 3}}
          expect(subject.bulk_body).to eq([
            {index: {_id: 3, routing: '1', data: expected_data3}},
            {index: {_id: 4, routing: '1', data: expected_data4}}
          ])
        end
      end

      context 'when switching grandparents' do
        let(:comments) do
          [
            Comment.create!(id: 3, content: 'Yes, he is here.', comment_type: :vote, commented_id: 2),
            Comment.create!(id: 4, content: 'What?', comment_type: :subvote, commented_id: 3)
          ]
        end
        let(:switching_parent_comment) { existing_comments[1].tap { |c| c.update!(commented_id: 31) } } # id: 2
        let(:fields) { %w[commented_id comment_type] }
        let(:to_index) { [switching_parent_comment] }

        before do
          existing_comments.each { |c| raw_index_comment(c) }
          comments.each { |c| raw_index_comment(c) }
        end

        it 'reindexes children and grandchildren' do
          expected_data2 = {'content' => 'Here.', 'content_with_crutches' => '[crutches] Here.', 'comment_type' => {'name' => 'answer', 'parent' => 31}}
          expected_data3 = {'content' => 'Yes, he is here.', 'content_with_crutches' => '[crutches] Yes, he is here.', 'comment_type' => {'name' => 'vote', 'parent' => 2}}
          expected_data4 = {'content' => 'What?', 'content_with_crutches' => '[crutches] What?', 'comment_type' => {'name' => 'subvote', 'parent' => 3}}
          expect(subject.bulk_body).to eq([
            {delete: {_id: 2, routing: '1', parent: 1}},
            {index: {_id: 2, routing: '31', data: expected_data2}},
            {delete: {_id: 3, routing: '1', parent: 2}},
            {index: {_id: 3, routing: '31', data: expected_data3}},
            {delete: {_id: 4, routing: '1', parent: 3}},
            {index: {_id: 4, routing: '31', data: expected_data4}}
          ])
        end
      end

      describe 'when removing parents or grandparents' do
        let(:comments) do
          [
            Comment.create!(id: 3, content: 'Yes, he is here.', comment_type: :vote, commented_id: 2),
            Comment.create!(id: 4, content: 'What?', comment_type: :subvote, commented_id: 3)
          ]
        end
        let(:delete) { [existing_comments[0]] } # id: 1

        before do
          existing_comments.each { |c| raw_index_comment(c) }
          comments.each { |c| raw_index_comment(c) }
        end

        it 'does not remove all descendants' do
          expect(subject.bulk_body).to eq([
            {delete: {_id: 1, routing: '1'}}
          ])
        end
      end

      context 'when indexing' do
        let(:to_index) { comments }

        specify do
          expected_data3 = {'content' => 'There!', 'content_with_crutches' => '[crutches] There!', 'comment_type' => {'name' => 'answer', 'parent' => 1}}
          expected_data4 = {'content' => 'Yes, he is here.', 'content_with_crutches' => '[crutches] Yes, he is here.', 'comment_type' => {'name' => 'vote', 'parent' => 2}}

          expected_data11 = {'content' => 'What is the sense of the universe?', 'content_with_crutches' => '[crutches] What is the sense of the universe?', 'comment_type' => 'question'}
          expected_data12 = {'content' => 'I don\'t know.', 'content_with_crutches' => '[crutches] I don\'t know.', 'comment_type' => {'name' => 'answer', 'parent' => 11}}
          expected_data13 = {'content' => '42', 'content_with_crutches' => '[crutches] 42', 'comment_type' => {'name' => 'answer', 'parent' => 11}}
          expected_data14 = {'content' => 'I think that 42 is a correct answer', 'content_with_crutches' => '[crutches] I think that 42 is a correct answer',
                             'comment_type' => {'name' => 'vote', 'parent' => 13}}

          expected_data21 = {'content' => 'How are you?', 'content_with_crutches' => '[crutches] How are you?', 'comment_type' => 'question'}

          expected_data32 = {'content' => 'Ruby', 'content_with_crutches' => '[crutches] Ruby', 'comment_type' => {'name' => 'answer', 'parent' => 31}}

          expect(subject.bulk_body).to eq([
            {index: {_id: 3, routing: '1', data: expected_data3}},
            {index: {_id: 4, routing: '1', data: expected_data4}},

            {index: {_id: 11, routing: '11', data: expected_data11}},
            {index: {_id: 12, routing: '11', data: expected_data12}},
            {index: {_id: 13, routing: '11', data: expected_data13}},
            {index: {_id: 14, routing: '11', data: expected_data14}},

            {index: {_id: 21, routing: '21', data: expected_data21}},

            {index: {_id: 32, routing: '31', data: expected_data32}}
          ])
        end
      end

      context 'when deleting' do
        before do
          existing_comments.each { |c| raw_index_comment(c) }
          comments.each { |c| raw_index_comment(c) }
        end

        let(:delete) { comments }
        specify do
          expect(subject.bulk_body).to eq([
            {delete: {_id: 3, routing: '1', parent: 1}},
            {delete: {_id: 4, routing: '1', parent: 2}},

            {delete: {_id: 11, routing: '11'}},
            {delete: {_id: 12, routing: '11', parent: 11}},
            {delete: {_id: 13, routing: '11', parent: 11}},
            {delete: {_id: 14, routing: '11', parent: 13}},

            {delete: {_id: 21, routing: '21'}},

            {delete: {_id: 32, routing: '31', parent: 31}}
          ])
        end
      end

      context  'when updating' do
        before do
          comments.each { |c| raw_index_comment(c) }
        end
        let(:fields) { %w[content] }
        let(:to_index) { comments }
        specify do
          expect(subject.bulk_body).to eq([
            {update: {_id: 3, routing: '1', data: {doc: {'content' => comments[0].content}}}},
            {update: {_id: 4, routing: '1', data: {doc: {'content' => comments[1].content}}}},

            {update: {_id: 11, routing: '11', data: {doc: {'content' => comments[2].content}}}},
            {update: {_id: 12, routing: '11', data: {doc: {'content' => comments[3].content}}}},
            {update: {_id: 13, routing: '11', data: {doc: {'content' => comments[4].content}}}},
            {update: {_id: 14, routing: '11', data: {doc: {'content' => comments[5].content}}}},

            {update: {_id: 21, routing: '21', data: {doc: {'content' => comments[6].content}}}},

            {update: {_id: 32, routing: '31', data: {doc: {'content' => comments[7].content}}}}
          ])
        end
      end
    end
  end

  describe '#index_objects_by_id' do
    before do
      stub_index(:cities) do
        field :name
      end
    end

    let(:to_index) { [double(id: 1), double(id: 2), double(id: ''), double] }
    let(:delete) { [double(id: 3)] }

    specify { expect(subject.index_objects_by_id).to eq('1' => to_index.first, '2' => to_index.second) }
  end
end
