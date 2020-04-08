Gem::Specification.new do |s|
  s.name = 'logstash-input-google-analytics-daily'
  s.version = '1.0.0'
  s.licenses = ['Apache License (2.0)']
  s.summary = "Pull daily reports from the Google Analytics v3 Core Reporting API."
  s.description = "This gem is a logstash plugin required to be installed on top of the Logstash core pipeline using $LS_HOME/bin/plugin install gemname. This gem is not a stand-alone program"
  s.authors = ["Shalvah"]
  s.email = 'hello@shalvah.me'
  s.homepage = "http://www.elastic.co/guide/en/logstash/current/index.html"
  s.require_paths = ["lib"]

  # Files
  s.files = Dir['lib/**/*','spec/**/*','vendor/**/*','*.gemspec','*.md','CONTRIBUTORS','Gemfile','LICENSE','NOTICE.TXT']
   # Tests
  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  # Special flag to let us know this is actually a logstash plugin
  s.metadata = { "logstash_plugin" => "true", "logstash_group" => "input" }

  # Gem dependencies
  s.add_runtime_dependency "logstash-core-plugin-api", ">= 2.0.0", "< 3.0.0"
  s.add_runtime_dependency 'stud', '>= 0.0.22'
  s.add_runtime_dependency 'google-api-client', "0.37"
  s.add_runtime_dependency 'googleauth'
  s.add_development_dependency 'vcr'
  s.add_development_dependency 'webmock'
  s.add_development_dependency 'json'
end
