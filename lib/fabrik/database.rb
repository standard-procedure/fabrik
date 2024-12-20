# frozen_string_literal: true

require "active_support/core_ext/string"
require "delegate"

module Fabrik
  class Database
    def configure(&block) = instance_eval(&block)

    def register(klass, as: nil, &block)
      blueprint_name = (as.nil? ? blueprint_name_for(klass) : as.to_s.pluralize).to_sym
      @blueprints[blueprint_name] = Blueprint.new(klass, &block)

      define_singleton_method blueprint_name do
        proxy_for(blueprint_name)
      end

      proxy_for(blueprint_name)
    end
    alias_method :with, :register

    def defaults_for(klass) = blueprint_for(klass).default_attributes

    def search_keys_for(klass) = blueprint_for(klass).search_keys

    def after_create_for(klass) = blueprint_for(klass).callback

    def method_missing(method_name, *, &block) = (klass = class_from(method_name)).nil? ? super : register(klass)

    def respond_to_missing?(method_name, include_private = false) = !class_from(method_name).nil? || super

    def initialize
      @blueprints = {}
      @records = {}
    end

    private def blueprint_name_for(klass) = klass.name.split("::").map(&:underscore).join("_").pluralize

    private def blueprint_for(klass) = @blueprints.values.find { |bp| bp.klass == klass }

    private def proxy_for(blueprint_name)
      @records[blueprint_name] ||= Proxy.new(self, @blueprints[blueprint_name])
    end

    private def class_from(method_name)
      Object.const_get(method_name.to_s.classify)
    rescue NameError
      nil
    end
  end

  class Blueprint
    attr_reader :klass, :default_attributes, :search_keys, :callback

    def defaults(**default_attributes) = @default_attributes = default_attributes

    def search_using(*keys) = @search_keys = keys

    def after_create(&block) = @callback = block

    def call_after_create(record, db) = @callback&.call(record, db)

    def initialize(klass, &block)
      @klass = klass
      @default_attributes = {}
      @search_keys = []
      instance_eval(&block) if block_given?
    end
  end

  class Proxy < SimpleDelegator
    def create(label = nil, **attributes)
      (@blueprint.search_keys.any? ? find_or_create_record(attributes) : create_record(attributes)).tap do |record|
        @records[label.to_sym] = record if label
      end
    end

    def [](label) = @records[label.to_sym]

    def initialize(db, blueprint)
      @db = db
      @blueprint = blueprint
      @records = {}
      super(klass)
    end

    private def search_keys = @blueprint.search_keys

    private def klass = @blueprint.klass

    private def default_attributes = @blueprint.default_attributes

    private def label = @blueprint.klass.name.split("::").map(&:underscore).join("_").pluralize

    private def find_or_create_record(attributes) = klass.find_by(**attributes.slice(*search_keys)) || create_record(attributes)

    private def create_record(attributes)
      klass.create(**attributes_with_defaults(attributes)).tap do |record|
        @blueprint.call_after_create(record, @db)
      end
    end

    private def attributes_with_defaults attributes
      attributes_to_generate = default_attributes.keys - attributes.keys
      attributes_to_generate.each_with_object({}) { |name, generated_attributes| generated_attributes[name] = default_attributes[name].call }.merge(attributes)
    end
  end
end
