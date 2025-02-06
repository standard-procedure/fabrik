# frozen_string_literal: true

require "spec_helper"
require "faker"

module Fabrik
  class ::Person
  end

  class ::Company
  end

  class Machine
  end

  module ::Intergalactic
    class Spaceship
    end
  end

  class ::InterplanetarySpaceship
  end

  RSpec.describe Fabrik::Database do
    describe ".new" do
      it "creates the database" do
        db = described_class.new
        expect(db).not_to respond_to(:users)
      end

      it "creates and configures the database" do
        db = described_class.new do
          with ::Person, as: :user
        end
        expect(db).to respond_to(:users)
      end
    end

    describe ".configure" do
      context "simple blueprint" do
        it "generates proxy methods for the class" do
          db = described_class.new

          db.configure do
            with ::Person do
              unique :first_name, :last_name
            end
          end

          expect(db.unique_keys_for(::Person)).to include :first_name
        end
      end

      context "namespaced class" do
        it "generates proxy methods for the namespaced, underscored, class" do
          db = described_class.new

          db.configure do
            with Machine
          end

          expect(db).to respond_to(:fabrik_machines)
        end
      end

      context "alternate name" do
        it "generates proxy methods for the alternate, plural, name" do
          db = described_class.new

          db.configure do
            with ::Person, as: :user
          end

          expect(db).to respond_to(:users)
        end
      end

      context "default attributes" do
        it "records the defaults with the proxy" do
          db = described_class.new

          db.configure do
            with ::Person do
              first_name "Alice"
              last_name "Aardvark"
              age { rand(18..57) }
            end
          end

          expect(db.defaults_for(::Person).keys).to eq [:first_name, :last_name, :age]
        end
      end

      context "unique keys" do
        it "records the unique keys with the proxy" do
          db = described_class.new

          db.configure do
            with ::Person do
              unique :first_name, :last_name
            end
          end

          expect(db.unique_keys_for(::Person)).to eq [:first_name, :last_name]
        end
      end

      context "after_create" do
        it "records the after_create callback with the proxy" do
          db = described_class.new

          db.configure do
            with ::Person do
              after_create { |person| puts "Hello #{person}" }
            end
          end

          expect(db.after_create_for(::Person)).to_not be_nil
        end
      end
    end

    describe "#create" do
      subject(:db) { described_class.new }

      context "blueprint not registered" do
        it "registers the class, creates a new record and stores the reference" do
          alice = double("Person", id: 1)
          allow(::Person).to receive(:create).with(first_name: "Alice", last_name: "Aardvark", age: 25).and_return(alice)

          db.people.create :alice, first_name: "Alice", last_name: "Aardvark", age: 25

          expect(::Person).to have_received(:create).with(first_name: "Alice", last_name: "Aardvark", age: 25)
          expect(db.people.alice).to eq alice
        end

        it "handles different types of class naming" do
          allow(::Intergalactic::Spaceship).to receive(:create).and_return(double("Intergalactic::Spaceship", id: 1))
          allow(::InterplanetarySpaceship).to receive(:create).and_return(double("InterplanetarySpaceship", id: 1))

          db.intergalactic_spaceships.create :discovery
          db.interplanetary_spaceships.create :enterprise

          expect(::Intergalactic::Spaceship).to have_received(:create)
          expect(::InterplanetarySpaceship).to have_received(:create)
        end
      end

      context "blueprint registered" do
        it "uses the blueprint to create a new record and stores the reference" do
          alice = double("Person", id: 1)
          allow(::Person).to receive(:create).with(first_name: "Alice", last_name: "Aardvark", age: 99).and_return(alice)

          db.configure do
            with ::Person do
              age 99
            end
          end
          db.people.create :alice, first_name: "Alice", last_name: "Aardvark"

          expect(::Person).to have_received(:create).with(first_name: "Alice", last_name: "Aardvark", age: 99)
          expect(db.people.alice).to eq alice
        end
      end

      context "blueprint registered with an alternate name" do
        it "uses the blueprint to create a new record and stores the reference" do
          alice = double("Person", id: 1)
          allow(::Person).to receive(:create).with(first_name: "Alice", last_name: "Aardvark", age: 25).and_return(alice)

          db.configure do
            with ::Person, as: :user
          end
          db.users.create :alice, first_name: "Alice", last_name: "Aardvark", age: 25

          expect(::Person).to have_received(:create).with(first_name: "Alice", last_name: "Aardvark", age: 25)
          expect(db.users.alice).to eq alice
        end
      end

      context "blueprint registered with default attributes" do
        it "uses the blueprint to create a new record with default values and stores the reference" do
          arthur = double("Person", id: 1)
          allow(::Person).to receive(:create).with(first_name: "Arthur", last_name: "Aardvark", age: 33, email: kind_of(String)).and_return(arthur)

          db.configure do
            with ::Person do
              first_name "Alice"
              last_name "Aardvark"
              age 33
              email { |person| Faker::Internet.email(name: "#{person.first_name} #{person.last_name}") }
            end
          end
          db.people.create :arthur, first_name: "Arthur"

          expect(::Person).to have_received(:create).with(first_name: "Arthur", last_name: "Aardvark", age: 33, email: kind_of(String))
          expect(db.people.arthur).to eq arthur
        end
      end

      context "blueprint registered with unique keys" do
        context "no record found" do
          it "uses the blueprint to create a new record and stores the refeence" do
            alice = double("Person", id: 1)
            allow(::Person).to receive(:find_by).with(first_name: "Alice", last_name: "Aardvark").and_return(nil)
            allow(::Person).to receive(:create).with(first_name: "Alice", last_name: "Aardvark", age: 25).and_return(alice)

            db.configure do
              with ::Person do
                unique :first_name, :last_name
              end
            end
            db.people.create :alice, first_name: "Alice", last_name: "Aardvark", age: 25

            expect(::Person).to have_received(:find_by).with(first_name: "Alice", last_name: "Aardvark")
            expect(::Person).to have_received(:create).with(first_name: "Alice", last_name: "Aardvark", age: 25)
            expect(db.people.alice).to eq alice
          end
        end

        context "existing record found" do
          it "returns the existing record without updating it" do
            alice = double("Person", id: 1)
            allow(::Person).to receive(:find_by).with(first_name: "Alice", last_name: "Aardvark").and_return(alice)

            db.configure do
              with ::Person do
                unique :first_name, :last_name
              end
            end
            db.people.create :alice, first_name: "Alice", last_name: "Aardvark", age: 25

            expect(::Person).to have_received(:find_by).with(first_name: "Alice", last_name: "Aardvark")
          end
        end
      end

      context "blueprint registered with default attributes and unique keys" do
        context "no record found" do
          it "uses the blueprint to create a new record with default values and stores the refeence" do
            alice = double("Person", id: 1)
            allow(::Person).to receive(:find_by).with(first_name: "Alice", last_name: "Aardvark").and_return(nil)
            allow(::Person).to receive(:create).with(first_name: "Alice", last_name: "Aardvark", age: 25).and_return(alice)

            db.configure do
              with ::Person do
                first_name { "Alice" }
                last_name { "Aardvark" }
                age 33
                unique :first_name, :last_name
              end
            end
            db.people.create :alice, first_name: "Alice", age: 25

            expect(::Person).to have_received(:find_by).with(first_name: "Alice", last_name: "Aardvark")
            expect(::Person).to have_received(:create).with(first_name: "Alice", last_name: "Aardvark", age: 25)
            expect(db.people.alice).to eq alice
          end
        end

        context "existing record found" do
          it "returns the existing record without updating it" do
            alice = double("Person", id: 1)
            allow(::Person).to receive(:find_by).with(first_name: "Alice", last_name: "Aardvark").and_return(alice)

            db.configure do
              with ::Person do
                first_name "Arthur"
                last_name "Aardvark"
                age 33
                unique :first_name, :last_name
              end
            end
            db.people.create :alice, first_name: "Alice", age: 25

            expect(::Person).to have_received(:find_by).with(first_name: "Alice", last_name: "Aardvark")
          end
        end
      end

      context "blueprint registered with after_create callback" do
        it "uses the blueprint to create a new record and fires the callback" do
          alice = double("Person", id: 1, first_name: "Alice")
          alices_company = double("Company", id: 1)
          allow(::Person).to receive(:create).with(first_name: "Alice", last_name: "Aardvark", age: 25).and_return(alice)
          allow(::Company).to receive(:create).with(name: "Alice's Company").and_return(alices_company)

          db.configure do
            with ::Company
            with ::Person do
              after_create { |person| companies.create :alices_company, name: "#{person.first_name}'s Company" }
            end
          end
          db.people.create :alice, first_name: "Alice", last_name: "Aardvark", age: 25

          expect(::Person).to have_received(:create).with(first_name: "Alice", last_name: "Aardvark", age: 25)
          expect(::Company).to have_received(:create).with(name: "Alice's Company")
          expect(db.companies.alices_company).to eq alices_company
        end

        it "does not fire the callback if an existing record is found" do
          alice = double("Person", id: 1)
          allow(::Person).to receive(:find_by).with(first_name: "Alice", last_name: "Aardvark").and_return(alice)
          allow(::Person).to receive(:create).with(first_name: "Alice", last_name: "Aardvark", age: 25).and_return(alice)
          alices_company = double("Company", id: 1)
          allow(::Company).to receive(:create).with(name: "Alice's Company").and_return(alices_company)

          db.configure do
            with ::Person do
              unique :first_name, :last_name
              after_create { |person| companies.create :alices_company, name: "#{person.first_name}'s Company" }
            end
          end
          db.people.create :alice, first_name: "Alice", last_name: "Aardvark", age: 25

          expect(::Company).to_not have_received(:create).with(name: "Alice's Company")
        end
      end
    end
  end
end
