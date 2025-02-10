# frozen_string_literal: true

require "active_support/core_ext/string"
require "delegate"
require "ostruct"

module Fabrik
  class Database
    def configure(&block) = instance_eval(&block)

    def register(klass, as: nil, &block)
      blueprint_name = (as.nil? ? blueprint_name_for(klass) : as.to_s.pluralize).to_sym
      blueprint = Blueprint.new(klass, &block)
      set_blueprint_for(blueprint_name, blueprint)

      define_singleton_method blueprint_name do
        proxy_for blueprint_name
      end

      proxy_for blueprint_name
    end
    alias_method :with, :register

    def defaults_for(klass) = @blueprints[klass].default_attributes

    def unique_keys_for(klass) = @blueprints[klass].unique_keys

    def after_create_for(klass) = @blueprints[klass].callback

    def method_missing(method_name, *, &block) = (klass = class_from(method_name)).nil? ? super : register(klass)

    def respond_to_missing?(method_name, include_private = false) = !class_from(method_name).nil? || super

    def initialize &config
      @blueprints = {}
      @proxies = {}
      instance_eval(&config) unless config.nil?
    end

    private def blueprint_name_for(klass) = klass.name.split("::").map(&:underscore).join("_").pluralize

    private def proxy_for(klass_or_blueprint_name)
      blueprint_name = klass_or_blueprint_name.is_a?(Class) ? blueprint_name_for(klass_or_blueprint_name) : klass_or_blueprint_name
      @proxies[blueprint_name.to_sym] ||= Proxy.new(self, @blueprints[blueprint_name])
    end

    private def set_blueprint_for(name, blueprint)
      @blueprints[name] = blueprint
      @blueprints[blueprint.klass] = blueprint
      proxy_for(name).blueprint = blueprint
    end

    private def class_from(method_name)
      klass = nil
      name = method_name.to_s.singularize.classify
      name = name.sub!(/(?<=[a-z])(?=[A-Z])/, "::") until name.nil? || (klass = name.safe_constantize)
      klass
    end
  end

  class Blueprint
    attr_reader :klass, :default_attributes, :unique_keys, :callback

    def defaults(**default_attributes) = @default_attributes = default_attributes

    def unique(*keys) = @unique_keys = keys

    def after_create(&block) = @callback = block

    def call_after_create(record, db) = @callback.nil? ? nil : db.instance_exec(record, &@callback)

    def method_missing(method_name, *args, &block)
      @default_attributes[method_name.to_sym] = args.first.nil? ? block : ->(_) { args.first }
    end

    def respond_to_missing?(method_name, include_private = false) = @default_attributes.key?(method_name.to_sym) || super

    def to_s = "#{klass} blueprint (#{object_id}) (#{default_attributes.keys.size} defaults, #{unique_keys.size} unique keys #{(!callback.nil?) ? "with callback" : ""})"

    def initialize(klass, &block)
      @klass = klass
      @default_attributes = {}
      @unique_keys = []
      instance_eval(&block) unless block.nil?
    end
  end

  class Proxy < SimpleDelegator
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

    def method_missing(method_name, *args, &block) = self[method_name.to_sym] || super

    def respond_to_missing?(method_name, include_private = false) = !self[method_name].nil? || super

    def to_s = "Proxy #{object_id} for #{@blueprint} (#{@records.keys.size} records)"

    def initialize(db, blueprint)
      @db = db
      @blueprint = blueprint
      @records = {}
      super(klass)
    end

    attr_accessor :blueprint

    private def unique_keys = @blueprint.unique_keys

    private def klass = @blueprint.klass

    private def default_attributes = @blueprint.default_attributes

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
  end
end
