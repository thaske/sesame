require_relative "lib/sesame/version"

Gem::Specification.new do |spec|
  spec.name          = "sesame"
  spec.version       = Sesame::VERSION
  spec.authors       = ["thaske (github.com/thaske)"]
  spec.summary       = "Internal Amazon SES email tracking, suppression, and webhook toolkit for Rails."
  spec.description   = "Internal gem providing models, services, mailer instrumentation, and SNS webhook handling for Amazon SES tracking and suppressions. Opinionated for internal use."
  spec.license       = "MIT"

  spec.files         = Dir.chdir(__dir__) do
    Dir["lib/**/*", "app/**/*", "config/routes.rb", "README.md", "MIT-LICENSE"]
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "rails", ">= 7.0"

  spec.add_development_dependency "rspec-rails", "~> 6.0"
  spec.add_development_dependency "factory_bot_rails", "~> 6.0"
  spec.add_development_dependency "pg", "~> 1.5"
end
