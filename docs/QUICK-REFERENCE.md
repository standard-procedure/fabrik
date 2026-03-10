# Fabrik

Ruby gem for simplified ActiveRecord factory/fixture definitions — used as `standard_procedure_fabrik` in Rails projects.

---

## Environment

Run `test -d /workspaces` to determine if you are inside the devcontainer.

**Inside** (`/workspaces` exists): run commands directly.
```bash
bin/rspec spec/path/to/file_spec.rb:LINE_NUMBER
```

**Outside** (`/workspaces` does not exist): exec into the container.
```bash
devcontainer exec --workspace-folder ~/Developer/fabrik bash -lc "bin/rspec spec/path/to/file_spec.rb:LINE_NUMBER"
```

**Start the container** (from project root on host):
```bash
dccup
```

**Interactive shell** (from project root on host):
```bash
dccsh
```

**Stop the container** (from project root on host):
```bash
dccdown
```

---

## About This Gem

Fabrik is a factory library for test data and database seeds. It is used as `standard_procedure_fabrik` across all the Rails projects in this workspace.

**Gem name**: `standard_procedure_fabrik`  
**Require**: `require "standard_procedure/fabrik"`  
**Main module**: `Fabrik`

---

## Common Commands

```bash
bundle exec rspec               # Run all specs
bundle exec guard               # Continuous testing (auto-runs on save)
bundle exec standardrb --fix    # Auto-fix code style
bundle exec rake                # Run default task (tests)
```

---

## File Locations

| What | Where |
|------|-------|
| Main library | `lib/standard_procedure/fabrik.rb` |
| Specs | `spec/` |
| Gemspec | `standard_procedure_fabrik.gemspec` |
| Changelog | `CHANGELOG.md` |

---

## Usage Pattern (in Rails projects)

```ruby
# In db/fabrik.rb (or spec/support/fabrik.rb)
Fabrik.configure do
  blueprint :user do
    email { Faker::Internet.email }
    name  { Faker::Name.name }
  end

  blueprint :site do
    name    { Faker::Company.name }
    account { build :account }
  end
end

# In tests/seeds
user = Fabrik.build :user
site = Fabrik.db.sites.create name: "My Site", account: my_account
```

---

## Documentation Index

- [README.md](../README.md) - Gem overview and usage

This file is symlinked as CLAUDE.md and AGENTS.md.
