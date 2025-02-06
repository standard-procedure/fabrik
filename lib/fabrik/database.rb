# frozen_string_literal: true

require "active_support/core_ext/string"
require "delegate"

module Fabrik
  class Database
    def configure(&block) = instance_eval(&block)

    def register(klass, as: nil, &block)
      blueprint_name = (as.nil? ? blueprint_name_for(klass) : as.to_s.pluralize).to_sym
      blueprint = Blueprint.new(klass, &block)
      @blueprints[blueprint_name] = blueprint
      @blueprints[klass] = blueprint

      define_singleton_method blueprint_name do
        proxy_for(blueprint_name)
      end

      proxy_for(blueprint_name)
    end
    alias_method :with, :register

    def defaults_for(klass) = @blueprints[klass].default_attributes

    def unique_keys_for(klass) = @blueprints[klass].unique_keys

    def after_create_for(klass) = @blueprints[klass].callback

    def method_missing(method_name, *, &block) = (klass = class_from(method_name)).nil? ? super : register(klass)

    def respond_to_missing?(method_name, include_private = false) = !class_from(method_name).nil? || super

    def initialize &config
      @blueprints = {}
      @records = {}
      instance_eval(&config) unless config.nil?
    end

    private def blueprint_name_for(klass) = klass.name.split("::").map(&:underscore).join("_").pluralize

    private def proxy_for(blueprint_name)
      @records[blueprint_name] ||= Proxy.new(self, @blueprints[blueprint_name])
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

    def initialize(klass, &block)
      @klass = klass
      @default_attributes = {}
      @unique_keys = []
      instance_eval(&block) if block_given?
    end
  end

  class Proxy < SimpleDelegator
    def create(label = nil, **attributes)
      (@blueprint.unique_keys.any? ? find_or_create_record(attributes) : create_record(attributes)).tap do |record|
        @records[label.to_sym] = record if label
      end
    end

    def method_missing(method_name, *args, &block)
      @records[method_name.to_sym]
    end

    def respond_to_missing?(method_name, include_private = false) = @@records.key?(label.to_sym) || super

    def initialize(db, blueprint)
      @db = db
      @blueprint = blueprint
      @records = {}
      super(klass)
    end

    private def unique_keys = @blueprint.unique_keys

    private def klass = @blueprint.klass

    private def default_attributes = @blueprint.default_attributes

    private def find_or_create_record(attributes)
      attributes = attributes_with_defaults(attributes)
      find_record(attributes) || create_record(attributes)
    end

    private def find_record(attributes) = attributes.slice(*unique_keys).empty? ? nil : klass.find_by(**attributes.slice(*unique_keys))

    private def create_record(attributes)
      klass.create(**attributes_with_defaults(attributes)).tap do |record|
        @blueprint.call_after_create(record, @db)
      end
    end

    private def attributes_with_defaults attributes
      attributes_to_generate = default_attributes.keys - attributes.keys
      attributes_to_generate.each_with_object({}) { |name, generated_attributes| generated_attributes[name] = default_attributes[name].call(@db) }.merge(attributes)
    end
  end
end
