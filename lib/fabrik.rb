# frozen_string_literal: true

require_relative "fabrik/version"
require_relative "fabrik/database"

module Fabrik
  def self.configure(&block)
    @db ||= Database.new
    @db.configure(&block)
  end

  def self.db = @db
end
