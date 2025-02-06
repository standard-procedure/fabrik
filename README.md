# Fabrik

## Simplify your database seeds and test fixtures.

Fabrik is a factory for your ActiveRecord models.

It's designed to be used in both your test cases and in your database seeds.

And I think the API is pretty nice and the code is pretty simple.

## Database seeds

Database seeds are great.

Screwed up your development database?  Just drop it, rebuild it and load in your starting data.

Added a new feature and want to show people what it looks like?  Add some new records into your seeds, run them, then you've got a nice set of demo data, all pre-loaded.

For this to work, seeds need to be idempotent.  When you run your seeds against a database with existing data, it should only insert the new stuff, leaving the old untouched.

Fabrik does this.

## Specs and tests

I love RSpec.  Other test frameworks (cough; minitest) are available.

And if you're writing Rails apps, your tests or specs are, most likely, going to be using ActiveRecord models which end up hitting the database.  That's just how Rails works, no matter what the isolationists say.

So, when setting up your test fixtures, you want to set up the smallest amount of data to prove your case.

And, because tests are documentation, you want that setup to be there, next to the test code, so anyone reading it can understand how everything hangs together.

Fabrik does this.

## Configuration

Fabrik allows you to configure three aspects of how you create your objects.

### Default attributes

When you're writing a spec, you probably only care about one aspect of the model involved.

So Fabrik allows you to set default attributes; then when you're creating a model, you can specify the ones you're interested in and ignore all the rest.

```ruby
@db = Fabrik.db
@db.configure do
  with Person do
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    email { |person| Faker::Internet.email(name: person.first_name) }
    age 33
  end
end

@alice = @db.people.create first_name: "Alice"

puts @alice.first_name # => Alice
puts @alice.last_name # => Hermann
puts @alice.email # => alice@some-domain.com
puts @alice.age # => 33
```

When specifying a default, you can either use a fixed value - for example `age 33`.  

Or you can pass a block and use a dynamic value - for example `last_name { Faker::Name.last_name }`.

If you pass a block, you can also access any attributes that have been generated so far - in this case we are accessing `person.first_name`.  Whilst attributes that were supplied in the call to `create` are generally safe, relying on values that were generated dynamically may not be.  The default value generators _should_ be called in the order of declaration, giving you access to dynamic values declared beforehand - but this is not guaranteed.  It's generally safer to avoid references when generating default values.  

### Uniqueness

When you've got a database packed with existing data, you don't want your seeds to fail because of a uniqueness constraint.  Or your tests to fail because suddenly they're finding two records when they were only expecting one.

So Fabrik lets you define what makes a model unique.  Then when you create it, it checks for an existing record first and only creates a new one if the original is not found.

```ruby
@db.configure do
  with Person do
    unique :email
  end
end
@alice = @db.people.create first_name: "Alice", last_name: "Aardvark", email: "alice@example.com"
@zac = @db.people.create first_name: "Zac", last_name: "Zebra", email: "alice@example.com"

@alice == @zac # => true
puts @zac.first_name # => Alice
puts @zac.last_name # => Aardvark
```

### Special processing

Some models are special.  They can't live on their own.  Their invariants won't let them.  Maybe a `Company` cannot exist without a `CEO`.  While your main application logic can ensure that's always the case, when you're writing your tests, it becomes a pain specifying it over and over again.

So Fabrik lets you define specific processing that happens after a new record is created.

```ruby
@db.configure do
  with Company do
    name { Faker::Company.name }
    after_create { |company| employees.create company: company, role: "CEO" }
  end
  with Employee do
    first_name { Faker::Name.first_name }
    last_name  { Faker::Name.last_name }
    role "Cleaner"
  end
end
@db.companies.create name: "MegaCorp"
puts Company.find_by(name: "MegaCorp").employees.size # => 1
```

## References

You've created a load of models.  And you need to reference them to create more models.  You could search for them by hand, but that's for chumps.

So Fabrik let's you give your models a label.  And then refer back to that model using the label.

```ruby
@db.people.create :alice, first_name: "Alice"

puts @db.people.alice # => Alice
```

## Classes and naming

You've got a load of models in your application.  Fabrik allows you to configure some rules for each one.  But not all of them need special processing.  Why waste your time telling Fabrik about all these classes when you've got more important things to do?

So Fabrik takes a guess at any names you give it and tries its best to figure out which class you mean.

```ruby
class Intergalactic::Spaceship < ApplicationRecord
  # whatever
end

@db.intergalactic_spaceships.create :ufo

puts Intergalactic::Spaceship.count # => 1
```

Or maybe you're writing a Rails engine and all your classes are namespaced.  Typing long names is so _boring_.

So Fabrik lets you register an alternative name for your classes.

```ruby
@db.configure do
  with MyAccountsPackageEngine::Invoice, as: :invoice do
    due_date { 7.days.from_now }
  end
end

@invoice = @db.invoices.create
```

## Installation

Add `standard_procedure_fabrik` to your `Gemfile`

```sh
bundle add standard_procedure_fabrik
```

If you're only using it for tests, add it to your `test` group.  If you're using it for seeds, add it with all your other gems.  While you're at it, add [Faker](https://github.com/faker-ruby/faker) as well - at the very least, it will probably make you smile with some of the stuff it generates for your test data.

## Usage

### Global

Most of the time, you can use the global `Fabrik.db` instance.  

```ruby
Fabrik.configure do
  with Person do
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    email { Faker::Internet.email }
  end
end

Fabrik.db.people.create :alice, first_name: "Alice"
```

Watch out - because this uses a global instance, it's not thread-safe.  That's not an issue if you're just using it for database seeds or in most test runners (single-threaded or parallelised with multiple processes).  But it *might* cause problems if you're using threads to parallelise your tests, or you're reconfiguring while your application is running.

### Localised

Create an instance of a [Fabrik::Database](/lib/fabrik/database.rb), configure it and use it.

```ruby
db = Fabrik::Database.new do
  with Person do
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    email { Faker::Internet.email }
  end
end

db.people.create :alice, first_name: "Alice"
```

In an RSpec:

```ruby
RSpec.describe "Whatever" do
  let(:db) do 
    Fabrik::Database.new do 
      # ... whatever
    end
  end
end
```

In a minitest ... I don't know, I've not used minitest in years but I'm sure it's easy enough.


## Development

Important note: this gem is not under the MIT Licence - it's under the [LGPL](/LICENSE).  This may or may not make it suitable for your use.  I have reasons for this, which don't belong in a README.  But the net result is, this library is open-source, it's free software and you can license *your own* code any way you want.  But if you change *this code*, you have to publish those changes under the same rules.

So, fork the repo, bundle install, add RSpecs for the changes you want to make and `rake spec` to run the tests. Then send me a pull request.  You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/standard-procedure/fabrik.

### Code of Conduct

Don't be a dick.

If you think you're being reasonable but most people think you're being a dick, then you're not being reasonable, you're actually being a dick.

We're not computers - we're human beings.  And human beings are soft, squishy and emotional.  That's just how it is.
