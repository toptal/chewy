require 'spec_helper'

describe Chewy::Index::Compiled do
  def self.mapping(&block)
    before { stub_index(:products, &block) }
  end

  let(:index) { ProductsIndex }
  let(:context) { {} }

  describe 'compose (via compiled path)' do
    context 'plain fields' do
      mapping do
        field :name
        field :age
        field :tags
      end
      let(:attrs) { {name: 'Name', age: 13, tags: %w[Ruby RoR]} }

      it 'composes from method reads' do
        expect(index.compose(double(attrs), context: context)).to eq(attrs.as_json)
      end

      it 'composes from hash keys (symbol)' do
        expect(index.compose(attrs, context: context)).to eq(attrs.as_json)
      end

      it 'composes from hash keys (string)' do
        expect(index.compose(attrs.stringify_keys, context: context)).to eq(attrs.as_json)
      end
    end

    context 'value: lambdas of varying arity' do
      mapping do
        field :zero,  value: -> { name.upcase }
        field :one,   value: ->(o) { o.age + 1 }
        field :two,   value: ->(o, c) { c.bonus + o.age }
        field :three, value: ->(o, _c, ctx) { ctx[:boost] * o.age }
      end
      let(:obj) { double(name: 'x', age: 10) }
      let(:crutches) { double(bonus: 5) }
      let(:context) { {boost: 3} }

      it 'dispatches arity correctly' do
        expect(index.compose(obj, crutches, context: context)).to eq(
          'zero' => 'X', 'one' => 11, 'two' => 15, 'three' => 30
        )
      end
    end

    context 'value: symbol' do
      mapping { field :display_name, value: :name }

      it 'reads via method name' do
        expect(index.compose(double(name: 'foo'))).to eq('display_name' => 'foo')
      end
    end

    context 'nested object children' do
      mapping do
        field :addr do
          field :city, value: ->(a) { a.city.upcase }
        end
      end

      it 'handles single nested object' do
        obj = double(addr: double(city: 'paris'))
        expect(index.compose(obj)).to eq('addr' => {'city' => 'PARIS'})
      end

      it 'handles nil nested object' do
        expect(index.compose(double(addr: nil))).to eq('addr' => nil)
      end

      it 'handles array of nested objects' do
        obj = double(addr: [double(city: 'paris'), double(city: 'rome')])
        expect(index.compose(obj)).to eq('addr' => [{'city' => 'PARIS'}, {'city' => 'ROME'}])
      end
    end

    context 'fields: restriction' do
      mapping do
        field :name
        field :age
        field :extra, value: ->(o) { o.extra * 2 }
      end

      it 'composes only requested fields' do
        obj = double(name: 'x', age: 1, extra: 5)
        expect(index.compose(obj, fields: [:name])).to eq('name' => 'x')
        expect(index.compose(obj, fields: %i[name extra])).to eq('name' => 'x', 'extra' => 10)
      end

      it 'reuses the same compiled method for the same fields set' do
        obj = double(name: 'x', age: 1, extra: 5)
        index.compose(obj, fields: %i[name extra])
        first_methods = index.methods.grep(/__chewy_compose__/).size
        5.times { index.compose(obj, fields: %i[extra name]) }
        expect(index.methods.grep(/__chewy_compose__/).size).to eq(first_methods)
      end
    end

    context 'duplicated field name' do
      mapping do
        field :full_name, value: ->(o) { "first-#{o.name}" }
        field :full_name, value: ->(o) { "last-#{o.name}" }
      end

      it 'last declaration wins (no duplicate-key warning)' do
        obj = double(name: 'x')
        out = nil
        expect { out = index.compose(obj) }.not_to output(/duplicated/).to_stderr
        expect(out).to eq('full_name' => 'last-x')
      end
    end

    context 'join field' do
      mapping do
        field :type_kind, type: 'join', relations: {parent: %i[child]},
                          join: {type: :kind, id: :parent_id}
      end

      it 'composes join field as parent/child mapping' do
        obj = double(kind: 'child', parent_id: 7)
        expect(index.compose(obj)).to eq('type_kind' => {'name' => 'child', 'parent' => 7})
      end
    end

    context 'lambda with default arguments (negative arity)' do
      mapping do
        field :a, value: ->(o, c = nil) { c ? c.boost + o.age : o.age }
      end
      let(:obj) { double(age: 7) }

      it 'invokes lambda with only the args it declares' do
        expect(index.compose(obj, double(boost: 5))).to eq('a' => 12)
      end
    end

    context 'fields_key collision' do
      mapping do
        field :full_name, value: ->(o) { "FN:#{o.full_name}" }
        field :id,        value: ->(o) { "ID:#{o.id}" }
        field :full,      value: ->(o) { "F:#{o.full}" }
        field :name_id,   value: ->(o) { "NI:#{o.name_id}" }
      end

      it 'does not confuse [:full_name, :id] with [:full, :name_id]' do
        obj = double(full_name: 'X', id: 1, full: 'Y', name_id: 9)
        expect(index.compose(obj, fields: %i[full_name id])).to eq('full_name' => 'FN:X', 'id' => 'ID:1')
        expect(index.compose(obj, fields: %i[full name_id])).to eq('full' => 'F:Y', 'name_id' => 'NI:9')
      end
    end

    context 'field added after first compose' do
      mapping do
        field :a, value: ->(o) { o.a } # rubocop:disable Style/SymbolProc
      end

      it 'picks up newly defined field on subsequent compose' do
        obj = double(a: 1, b: 2)
        expect(index.compose(obj)).to eq('a' => 1)
        index.field :b, value: ->(o) { o.b } # rubocop:disable Style/SymbolProc
        expect(index.compose(obj)).to eq('a' => 1, 'b' => 2)
      end
    end

    context 'non-identifier field name' do
      mapping do
        field :'first-name', value: ->(o) { o.name } # rubocop:disable Style/SymbolProc
      end

      it 'falls back to plain path rather than producing invalid Ruby source' do
        obj = double(name: 'x')
        expect(index.compose(obj)).to eq('first-name' => 'x')
      end
    end

    context 'witchcraft fallback' do
      mapping do
        field :name
      end

      it 'uses witchcraft path when witchcraft! is set (with deprecation)' do
        # silence the deprecation noise
        original_stderr = $stderr
        $stderr = StringIO.new
        index.witchcraft!
        $stderr = original_stderr
        expect(index.compiled_compose_available?([])).to eq(false)
      end
    end
  end

  describe 'dispatch in Import.compose' do
    mapping do
      field :name
      field :age, value: ->(o) { o.age * 2 }
    end

    it 'uses the compiled path by default' do
      obj = double(name: 'a', age: 3)
      # trigger lazy compile so the singleton method exists before we mock it
      index.send(:ensure_compiled_compose_for!, [])
      expect(index).to receive(:__chewy_compose__).and_call_original
      expect(index.compose(obj)).to eq('name' => 'a', 'age' => 6)
    end
  end
end
