# frozen_string_literal: true

require "active_support/core_ext/string"
require "delegate"
require "ostruct"

module Fabrik
  class Database
    def configure(&configuration) = instance_eval(&configuration)

    def register(klass, as: nil, &configuration)
      blueprint_name = (as.nil? ? blueprint_name_for(klass) : as.to_s.pluralize).to_sym
      @proxies[blueprint_name] ||= Proxy.new(self, Blueprint.new(klass))
      @proxies[blueprint_name].configure(&configuration)
      @proxies[blueprint_name]
    end
    alias_method :with, :register

    def defaults_for(klass) = proxy_for(klass).default_attributes

    def unique_keys_for(klass) = proxy_for(klass).unique_keys

    def after_create_for(klass) = proxy_for(klass).callback

    def functions_for(klass) = proxy_for(klass).functions

    def method_missing(method_name, *, &block)
      @proxies[method_name] || ((klass = class_from(method_name)).nil? ? super : register(klass))
    end

    def respond_to_missing?(method_name, include_private = false)
      @proxies.key?(method_name) || !class_from(method_name).nil? || super
    end

    def initialize &config
      @proxies = {}
      instance_eval(&config) unless config.nil?
    end

    private def blueprint_name_for(klass) = klass.name.split("::").map(&:underscore).join("_").pluralize

    private def proxy_for(klass) = @proxies.values.find { |proxy| proxy.klass == klass }

    private def class_from(method_name)
      klass = nil
      name = method_name.to_s.singularize.classify
      name = name.sub!(/(?<=[a-z])(?=[A-Z])/, "::") until name.nil? || (klass = name.safe_constantize)
      klass
    end
  end

  class Blueprint
    def initialize(klass)
      @klass = klass
      @default_attributes = {}
      @unique_keys = []
      @functions = {}
    end

    attr_reader :klass, :default_attributes, :unique_keys, :callback, :functions

    def defaults(**default_attributes) = @default_attributes = default_attributes

    def unique(*keys) = @unique_keys = keys

    def after_create(&block) = @callback = block

    def call_after_create(record, db) = @callback.nil? ? nil : db.instance_exec(record, &@callback)

    def function(name, &implementation) = @functions[name.to_sym] = implementation

    def method_missing(method_name, *args, &block)
      @default_attributes[method_name.to_sym] = args.first.nil? ? block : ->(_) { args.first }
    end

    def respond_to_missing?(method_name, include_private = false) = @default_attributes.key?(method_name.to_sym) || super

    def to_s = "#{klass} blueprint (#{object_id}) (#{default_attributes.keys.size} defaults, #{unique_keys.size} unique keys #{(!callback.nil?) ? "with callback" : ""})"

    def configure(&configuration)
      instance_eval(&configuration) unless configuration.nil?
    end
  end

  class Proxy < SimpleDelegator
    def initialize(db, blueprint)
      @db = db
      @blueprint = blueprint
      @records = {}
      super(klass)
    end
    attr_accessor :blueprint

    def create(label = nil, after_create: true, **attributes)
      (@blueprint.unique_keys.any? ? find_or_create_record(attributes, callback: after_create) : create_record(attributes, callback: after_create)).tap do |record|
        self[label] = record if label
      end
    end
    alias_method :create!, :create

    def [](label) = @records[label.to_sym]

    def []=(label, record)
      @records[label.to_sym] = record
    end

    def method_missing(method_name, *args, &block) = self[method_name] || call_function(method_name, *args) || super

    def respond_to_missing?(method_name, include_private = false) = !self[method_name].nil? || !functions[method_name].nil? || super

    def to_s = "Proxy #{object_id} for #{@blueprint} (#{@records.keys.size} records)"

    def configure(&configuration)
      @blueprint.configure(&configuration) unless configuration.nil?
    end

    def unique_keys = @blueprint.unique_keys

    def klass = @blueprint.klass

    def default_attributes = @blueprint.default_attributes

    def callback = @blueprint.callback

    def functions = @blueprint.functions

    private def find_or_create_record(attributes, callback:)
      attributes = attributes_with_defaults(attributes)
      find_record(attributes) || create_record(attributes, callback: callback)
    end

    private def find_record(attributes) = attributes.slice(*unique_keys).empty? ? nil : klass.find_by(**attributes.slice(*unique_keys))

    private def create_record(attributes, callback:)
      klass.create!(**attributes_with_defaults(attributes)).tap do |record|
        @blueprint.call_after_create(record, @db) if callback
      end
    end

    private def attributes_with_defaults attributes
      attributes_to_generate = default_attributes.keys - attributes.keys
      attributes_to_generate.each_with_object(OpenStruct.new(**attributes)) do |name, generated_attributes|
        generated_attributes[name] = default_attributes[name].nil? ? nil : @db.instance_exec(generated_attributes, &default_attributes[name])
      end.to_h.merge(attributes)
    end

    private def call_function(method_name, *args)
      functions[method_name].nil? ? nil : @db.instance_exec(*args, &functions[method_name])
    end
  end
end
