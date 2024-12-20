# frozen_string_literal: true

require "spec_helper"

module Fabrik
  class Machine
  end

  RSpec.describe Fabrik do
    describe ".configure" do
      it "should build a default database" do
        Fabrik.configure do
          register Machine
        end

        expect(Fabrik.db).to_not be_nil
        expect(Fabrik.db).to respond_to(:fabrik_machines)
      end
    end
  end
end
