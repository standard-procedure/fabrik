# frozen_string_literal: true

require_relative "lib/fabrik/version"

Gem::Specification.new do |spec|
  spec.name = "standard_procedure_fabrik"
  spec.version = Fabrik::VERSION
  spec.authors = ["Rahoul Baruah"]
  spec.email = ["rahoulb@echodek.co"]

  spec.summary = "Fabrik"
  spec.description = "Fixtures, fittings and seeds"
  spec.homepage = "https://www.theartandscienceofruby.com"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/standard_procedure"
  spec.metadata["changelog_uri"] = "https://github.com/standard_procedure"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport", ">= 8.0.1"
  spec.add_dependency "standard-procedure-plumbing"
end
