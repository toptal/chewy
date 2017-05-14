module ClassHelpers
  extend ActiveSupport::Concern

  def stub_index(name, superclass = nil, &block)
    stub_class("#{name.to_s.camelize}Index", superclass || Chewy::Index)
      .tap { |i| i.class_eval(&block) if block }
  end

  def stub_class(name, superclass = nil, &block)
    stub_const(name.to_s.camelize, Class.new(superclass || Object, &block))
  end

  def stub_model(_name, _superclass = nil)
    raise NotImplementedError, 'Seems like no ORM/ODM are loaded, please check your Gemfile'
  end

  def skip_on_version_gte(version, message = "Removed from elasticsearch #{version}")
    skip message if Chewy.default_client.version >= version
  end

  def skip_on_version_lt(version, message = "Only for elasticsearch #{version} and greater")
    skip message if Chewy.default_client.version < version
  end

  def skip_on_plugin_missing_from_version(plugin, version, message = "Plugin '#{plugin}' is missing on elasticsearch > #{version}")
    return if Chewy.default_client.version < version
    plugins = Chewy.default_client.nodes.info(plugins: true)['nodes'].values.map { |item| item['plugins'] }.flatten
    skip message unless plugins.find { |item| item['name'] == plugin }
  end
end
