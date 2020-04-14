Gem::Specification.new do |s|
  s.name = 'logstash-input-google-analytics-daily'
  s.version = '0.4.0'
  s.licenses = ['Apache License (2.0)']
  s.summary = "Logstash plugin to pull daily reports from Google Analytics."
  s.description = "Logstash plugin to pull daily reports from the Google Analytics v3 Core Reporting API. Install into Logstash using $LS_HOME/bin/logstash-plugin install logstash-input-google-analytics-daily."
  s.authors = ["Shalvah"]
  s.email = 'shalvah.adebayo@gmail.com'
  s.homepage = "http://www.elastic.co/guide/en/logstash/current/plugins-inputs-google_analytics_daily.html.html"
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
  s.add_runtime_dependency 'google-api-client', "~> 0.37"
  s.add_runtime_dependency 'googleauth', ">= 0.10.0"
  s.add_runtime_dependency 'json'
  s.add_development_dependency 'vcr'
  s.add_development_dependency 'webmock'
end
