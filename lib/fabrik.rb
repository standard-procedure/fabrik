# frozen_string_literal: true

require_relative "fabrik/version"
require_relative "fabrik/database"

module Fabrik
  def self.configure(&block) = db.configure(&block)

  def self.db = @db ||= Database.new
end
