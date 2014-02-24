require 'spec_helper'

describe Chewy::Fields::Base do
  specify { described_class.new('name').name.should == :name }
  specify { described_class.new('name', type: 'integer').options[:type].should == 'integer' }

  describe '#check_analyzer!' do
    let(:create_field) { described_class.new(:name, analyzer: 'custom_analyzer') }

    context 'with defined analyzer' do
      before { Chewy.analyzer :custom_analyzer, tokenizer: 'standard'  }
      specify { expect { create_field }.to_not raise_error }
    end

    context 'with undefined analyzer' do
      before { Chewy.analyzers.clear }
      specify { expect { create_field }.to raise_error  'Undefined analyzer: :custom_analyzer' }
    end
  end

  describe '#compose' do
    let(:field) { described_class.new(:name, value: ->(o){ o.value }) }

    specify { field.compose(double(value: 'hello')).should == {name: 'hello'} }
    specify { field.compose(double(value: ['hello', 'world'])).should == {name: ['hello', 'world']} }

    specify { described_class.new(:name).compose(double(name: 'hello')).should == {name: 'hello'} }

    context do
      before do
        field.nested(described_class.new(:subname1, value: ->(o){ o.subvalue1 }))
        field.nested(described_class.new(:subname2, value: ->{ subvalue2 }))
        field.nested(described_class.new(:subname3))
      end

      specify { field.compose(double(value: double(subvalue1: 'hello', subvalue2: 'value', subname3: 'world')))
        .should == {name: {'subname1' => 'hello', 'subname2' => 'value', 'subname3' => 'world'}} }
      specify { field.compose(double(value: [
        double(subvalue1: 'hello1', subvalue2: 'value1', subname3: 'world1'),
        double(subvalue1: 'hello2', subvalue2: 'value2', subname3: 'world2')
      ])).should == {name: [
        {'subname1' => 'hello1', 'subname2' => 'value1', 'subname3' => 'world1'},
        {'subname1' => 'hello2', 'subname2' => 'value2', 'subname3' => 'world2'}
      ]} }
    end

    context do
      let(:field) { described_class.new(:name, type: 'multi_field') }
      before do
        field.nested(described_class.new(:name))
        field.nested(described_class.new(:untouched))
      end

      specify { field.compose(double(name: 'Alex')).should == {name: 'Alex'} }
    end
  end

  describe '#nested' do
    let(:field) { described_class.new(:name) }

    specify { expect { field.nested(described_class.new(:name1)) }
      .to change { field.nested[:name1] }.from(nil).to(an_instance_of(described_class))  }
  end

  describe '#mappings_hash' do
    let(:field) { described_class.new(:name, type: 'string') }
    let(:fields1) { 2.times.map { |i| described_class.new("name#{i+1}", type: "string#{i+1}") } }
    let(:fields2) { 2.times.map { |i| described_class.new("name#{i+3}", type: "string#{i+3}") } }
    before do
      fields1.each { |m| field.nested(m) }
      fields2.each { |m| fields1[0].nested(m) }
    end

    specify { field.mappings_hash.should == {name: {type: 'string', properties: {
      name1: {type: 'string1', properties: {
        name3: {type: 'string3'}, name4: {type: 'string4'}
      }}, name2: {type: 'string2'}
    }}} }

    context do
      let(:field) { described_class.new(:name, type: 'multi_field') }

      specify { field.mappings_hash.should == {name: {type: 'multi_field', fields: {
        name1: {type: 'string1', properties: {
          name3: {type: 'string3'}, name4: {type: 'string4'}
        }}, name2: {type: 'string2'}
      }}} }
    end
  end
end
