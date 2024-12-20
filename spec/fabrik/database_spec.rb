# frozen_string_literal: true

require "spec_helper"

module Fabrik
  class ::Person
  end

  class ::Company
  end

  class Machine
  end

  RSpec.describe Fabrik::Database do
    subject(:db) { described_class.new }

    describe ".configure" do
      context "registering a simple blueprint" do
        it "generates proxy methods for accessing the class" do
          db.configure do
            with ::Person
          end

          expect(db).to respond_to(:people)
        end
      end

      context "registering a blueprint for a namespaced class" do
        it "generates proxy methods for accessing the class" do
          db.configure do
            with Machine
          end

          expect(db).to respond_to(:fabrik_machines)
        end
      end

      context "registering a blueprint with an alternate name" do
        it "generates proxy methods for accessing the class" do
          db.configure do
            with ::Person, as: :user
          end

          expect(db).to respond_to(:users)
        end
      end

      context "registering a blueprint with default attributes" do
        it "records the default attributes for the class" do
          db.configure do
            with ::Person do
              defaults first_name: -> { "Alice" }, last_name: -> { "Aardvark" }, age: -> { rand(18..57) }
            end
          end

          expect(db.defaults_for(::Person).keys).to eq [:first_name, :last_name, :age]
        end
      end

      context "registering a blueprint with search keys" do
        it "records the search keys for the class" do
          db.configure do
            with ::Person do
              search_using :first_name, :last_name
            end
          end

          expect(db.search_keys_for(::Person)).to eq [:first_name, :last_name]
        end
      end

      context "registering a blueprint with after_create callback" do
        it "records the after_create callback for the class" do
          db.configure do
            with ::Person do
              after_create do |person|
                puts "Hello #{person}"
              end
            end
          end

          expect(db.after_create_for(::Person)).to_not be_nil
        end
      end
    end

    describe "#create" do
      subject(:db) { described_class.new }

      context "blueprint not registered" do
        it "creates a new record and stores the reference" do
          alice = double("Person", id: 1)
          allow(::Person).to receive(:create).with(first_name: "Alice", last_name: "Aardvark", age: 25).and_return(alice)

          db.people.create :alice, first_name: "Alice", last_name: "Aardvark", age: 25

          expect(::Person).to have_received(:create).with(first_name: "Alice", last_name: "Aardvark", age: 25)
          expect(db.people[:alice]).to eq alice
        end
      end

      context "blueprint registered" do
        it "creates a new record and stores the reference" do
          alice = double("Person", id: 1)
          allow(::Person).to receive(:create).with(first_name: "Alice", last_name: "Aardvark", age: 25).and_return(alice)

          db.configure do
            with ::Person
          end
          db.people.create :alice, first_name: "Alice", last_name: "Aardvark", age: 25

          expect(::Person).to have_received(:create).with(first_name: "Alice", last_name: "Aardvark", age: 25)
          expect(db.people[:alice]).to eq alice
        end
      end

      context "blueprint registered with an alternate name" do
        it "creates a new record and stores the reference" do
          alice = double("Person", id: 1)
          allow(::Person).to receive(:create).with(first_name: "Alice", last_name: "Aardvark", age: 25).and_return(alice)

          db.configure do
            with ::Person, as: :user
          end
          db.users.create :alice, first_name: "Alice", last_name: "Aardvark", age: 25

          expect(::Person).to have_received(:create).with(first_name: "Alice", last_name: "Aardvark", age: 25)
          expect(db.users[:alice]).to eq alice
        end
      end

      context "blueprint registered with default attributes" do
        it "creates a new record and stores the reference" do
          arthur = double("Person", id: 1)
          allow(::Person).to receive(:create).with(first_name: "Arthur", last_name: "Aardvark", age: 33).and_return(arthur)

          db.configure do
            with ::Person do
              defaults first_name: -> { "Alice" }, last_name: -> { "Aardvark" }, age: -> { 33 }
            end
          end
          db.people.create :arthur, first_name: "Arthur"

          expect(::Person).to have_received(:create).with(first_name: "Arthur", last_name: "Aardvark", age: 33)
          expect(db.people[:arthur]).to eq arthur
        end
      end

      context "blueprint registered with unique keys" do
        context "no record found" do
          it "creates a new record and stores the refeence" do
            alice = double("Person", id: 1)
            allow(::Person).to receive(:find_by).with(first_name: "Alice", last_name: "Aardvark").and_return(nil)
            allow(::Person).to receive(:create).with(first_name: "Alice", last_name: "Aardvark", age: 25).and_return(alice)

            db.configure do
              with ::Person do
                search_using :first_name, :last_name
              end
            end
            db.people.create :alice, first_name: "Alice", last_name: "Aardvark", age: 25

            expect(::Person).to have_received(:find_by).with(first_name: "Alice", last_name: "Aardvark")
            expect(::Person).to have_received(:create).with(first_name: "Alice", last_name: "Aardvark", age: 25)
            expect(db.people[:alice]).to eq alice
          end
        end

        context "existing record found" do
          it "returns the existing record without updating it" do
            alice = double("Person", id: 1)
            allow(::Person).to receive(:find_by).with(first_name: "Alice", last_name: "Aardvark").and_return(alice)

            db.configure do
              with ::Person do
                search_using :first_name, :last_name
              end
            end
            db.people.create :alice, first_name: "Alice", last_name: "Aardvark", age: 25

            expect(::Person).to have_received(:find_by).with(first_name: "Alice", last_name: "Aardvark")
          end
        end
      end

      context "blueprint registered with after_create callback" do
        it "creates a new record and fires the callback" do
          alice = double("Person", id: 1, first_name: "Alice")
          alices_company = double("Company", id: 1)
          allow(::Person).to receive(:create).with(first_name: "Alice", last_name: "Aardvark", age: 25).and_return(alice)
          allow(::Company).to receive(:create).with(name: "Alice's Company").and_return(alices_company)

          db.configure do
            with ::Company
            with ::Person do
              after_create do |person, db|
                db.companies.create :alices_company, name: "#{person.first_name}'s Company"
              end
            end
          end
          db.people.create :alice, first_name: "Alice", last_name: "Aardvark", age: 25

          expect(::Person).to have_received(:create).with(first_name: "Alice", last_name: "Aardvark", age: 25)
          expect(::Company).to have_received(:create).with(name: "Alice's Company")
          expect(db.companies[:alices_company]).to eq alices_company
        end

        it "does not fire the callback if an existing record is found" do
          alice = double("Person", id: 1)
          allow(::Person).to receive(:find_by).with(first_name: "Alice", last_name: "Aardvark").and_return(alice)
          allow(::Person).to receive(:create).with(first_name: "Alice", last_name: "Aardvark", age: 25).and_return(alice)
          alices_company = double("Company", id: 1)
          allow(::Company).to receive(:create).with(name: "Alice's Company").and_return(alices_company)

          db.configure do
            with ::Person do
              search_using :first_name, :last_name
              after_create do |person, db|
                db.companies.create :alices_company, name: "#{person.first_name}'s Company"
              end
            end
          end
          db.people.create :alice, first_name: "Alice", last_name: "Aardvark", age: 25

          expect(::Company).to_not have_received(:create).with(name: "Alice's Company")
        end
      end
    end
  end
end
