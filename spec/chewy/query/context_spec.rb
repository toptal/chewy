require 'spec_helper'

describe Chewy::Query::Context do
  def Bool options
    Chewy::Query::Nodes::Bool.new.tap do |bool|
      bool.must(*options[:must]) if options[:must].present?
      bool.must_not(*options[:must_not]) if options[:must_not].present?
      bool.should(*options[:should]) if options[:should].present?
    end
  end

  %w(field group and or not raw exists missing prefix regexp range equal query script).each do |method|
    define_method method.camelize do |*args|
      "Chewy::Query::Nodes::#{method.camelize}".constantize.new *args
    end
  end

  def query &block
    Chewy::Query::Context.new(&block).__result__
  end

  context 'outer scope' do
    let(:email) { 'email' }
    specify { query { email }.should be_eql Field(:email) }
    specify { query { o{email} }.should == 'email' }
  end

  context 'field' do
    let(:email) { 'email' }
    specify { query { f(:email) }.should be_eql Field(:email) }
    specify { query { f{ :email } }.should be_eql Field(:email) }
    specify { query { f{ email } }.should be_eql Field(:email) }
    specify { query { email }.should be_eql Field(:email) }
    specify { query { emails.first }.should be_eql Field('emails.first') }
    specify { query { emails.first.second }.should be_eql Field('emails.first.second') }
    specify { query { email == 'email' }.should be_eql Equal(:email, 'email') }
    specify { query { name != 'name' }.should be_eql Not(Equal(:name, 'name')) }
  end

  context 'bool' do
    specify { query { must(email == 'email') }.should be_eql Bool(must: [Equal(:email, 'email')]) }
    specify { query { must_not(email == 'email') }.should be_eql Bool(must_not: [Equal(:email, 'email')]) }
    specify { query { should(email == 'email') }.should be_eql Bool(should: [Equal(:email, 'email')]) }
    specify { query {
      must(email == 'email').should(address != 'address', age == 42)
      .must_not(sex == 'm').must(name == 'name')
    }.should be_eql Bool(
      must: [Equal(:email, 'email'), Equal(:name, 'name')],
      must_not: [Equal(:sex, 'm')],
      should: [Not(Equal(:address, 'address')), Equal(:age, 42)]
    ) }
  end

  context 'exists' do
    specify { query { email? }.should be_eql Exists(:email) }
    specify { query { !!email? }.should be_eql Exists(:email) }
    specify { query { emails.first? }.should be_eql Exists('emails.first') }
    specify { query { !!emails.first? }.should be_eql Exists('emails.first') }
  end

  context 'missing' do
    specify { query { !email }.should be_eql Missing(:email) }
    specify { query { !email? }.should be_eql Missing(:email) }
    specify { query { !emails.first }.should be_eql Missing('emails.first') }
    specify { query { !emails.first? }.should be_eql Missing('emails.first') }
  end

  context 'range' do
    specify { query { age > 42 }.should be_eql Range(:age, gt: 42) }
    specify { query { age >= 42 }.should be_eql Range(:age, gt: 42, left_closed: true) }
    specify { query { age < 42 }.should be_eql Range(:age, lt: 42) }
    specify { query { age <= 42 }.should be_eql Range(:age, lt: 42, right_closed: true) }

    specify { query { age == (30..42) }.should be_eql Range(:age, gt: 30, lt: 42) }
    specify { query { age == [30..42] }.should be_eql Range(:age, gt: 30, lt: 42, left_closed: true, right_closed: true) }
    specify { query { age <=> (30..42) }.should be_eql Range(:age, gt: 30, lt: 42, right_closed: true) }
    specify { query { age <=> [30..42] }.should be_eql Range(:age, gt: 30, lt: 42, left_closed: true) }
  end

  context 'prefix' do
    specify { query { name =~ 'nam' }.should be_eql Prefix(:name, 'nam') }
    specify { query { name !~ 'nam' }.should be_eql Not(Prefix(:name, 'nam')) }
  end

  context 'regexp' do
    specify { query { name =~ /name/ }.should be_eql Regexp(:name, 'name') }
    specify { query { name == /name/ }.should be_eql Regexp(:name, 'name') }
    specify { query { name !~ /name/ }.should be_eql Not(Regexp(:name, 'name')) }
    specify { query { name != /name/ }.should be_eql Not(Regexp(:name, 'name')) }
  end

  context 'query' do
    let(:some_query) { 'some query' }
    specify { query { q('some query') }.should be_eql Query('some query') }
    specify { query { q{'some query'} }.should be_eql Query('some query') }
    specify { query { q{ some_query } }.should be_eql Query('some query') }
  end

  context 'raw' do
    let(:raw_query) { {term: {name: 'name'}} }
    specify { query { r(term: {name: 'name'}) }.should be_eql Raw(term: {name: 'name'}) }
    specify { query { r{ {term: {name: 'name'}} } }.should be_eql Raw(term: {name: 'name'}) }
    specify { query { r{ raw_query } }.should be_eql Raw(term: {name: 'name'}) }
  end

  context 'script' do
    let(:some_script) { 'some script' }
    specify { query { s('some script') }.should be_eql Script('some script') }
    specify { query { s{'some script'} }.should be_eql Script('some script') }
    specify { query { s{ some_script } }.should be_eql Script('some script') }
  end

  context 'and or not' do
    specify { query { (email == 'email') & (name == 'name') }
      .should be_eql And(Equal(:email, 'email'), Equal(:name, 'name')) }
    specify { query { (email == 'email') | (name == 'name') }
      .should be_eql Or(Equal(:email, 'email'), Equal(:name, 'name')) }
    specify { query { !(email == 'email') }.should be_eql Not(Equal(:email, 'email')) }

    specify { query { (email == 'email') & (name == 'name') | (address != 'address') }
      .should be_eql Or(
        And(
          Equal(:email, 'email'),
          Equal(:name, 'name')
        ),
        Not(Equal(:address, 'address'))
      ) }
    specify { query { (email == 'email') & ((name == 'name') | (address != 'address')) }
      .should be_eql And(
        Equal(:email, 'email'),
        Or(
          Equal(:name, 'name'),
          Not(Equal(:address, 'address')),
        )
      ) }
    specify { query { (email == 'email') & ((name == 'name') & (address != 'address')) }
      .should be_eql And(
        Equal(:email, 'email'),
        Equal(:name, 'name'),
        Not(Equal(:address, 'address')),
      ) }
    specify { query { ((email == 'email') | (name == 'name')) | (address != 'address') }
      .should be_eql Or(
        Equal(:email, 'email'),
        Equal(:name, 'name'),
        Not(Equal(:address, 'address')),
      ) }
    specify { query { !((email == 'email') | (name == 'name')) }
      .should be_eql Not(Or(Equal(:email, 'email'), Equal(:name, 'name'))) }
    specify { query { !!((email == 'email') | (name == 'name')) }
      .should be_eql Or(Equal(:email, 'email'), Equal(:name, 'name')) }
  end
end
