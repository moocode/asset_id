# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{asset_id}
  s.version = "0.1.5"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Richard Taylor"]
  s.date = %q{2011-05-14}
  s.description = %q{asset_id is a library for uploading static assets to Amazon S3.}
  s.email = %q{moomerman@gmail.com}
  s.files = ["LICENSE", "README.textile","lib/asset_id.rb"]
  s.has_rdoc = false
  s.homepage = %q{http://github.com/moomerman/asset_id}
  s.rdoc_options = ["--inline-source", "--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{asset_id}
  s.rubygems_version = %q{1.3.1}
  s.summary = %q{asset_id is a library for uploading static assets to Amazon S3.}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<mime-types>, [">= 1.16"])
      s.add_runtime_dependency(%q<aws-s3>, [">= 0.6.2"])
    else
      s.add_dependency(%q<mime-types>, [">= 1.16"])
      s.add_dependency(%q<aws-s3>, [">= 0.6.2"])
    end
  else
    s.add_dependency(%q<mime-types>, [">= 1.16"])
     s.add_dependency(%q<aws-s3>, [">= 0.6.2"])
  end
end
