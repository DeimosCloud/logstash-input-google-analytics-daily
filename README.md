# Logstash Plugin

This is a plugin for [Logstash](https://github.com/elastic/logstash).

## Documentation

Logstash provides infrastructure to automatically generate documentation for this plugin. We use the asciidoc format to write documentation so any comments in the source code will be first converted into asciidoc and then into html. All plugin documentation are placed under one [central location](http://www.elastic.co/guide/en/logstash/current/).

- For formatting code or config example, you can use the asciidoc `[source,ruby]` directive
- For more asciidoc formatting tips, see the excellent reference here https://github.com/elastic/docs#asciidoc-guide

## Developing

### 1. Plugin Development and Testing

#### Code
- To get started, you'll need JRuby with the Bundler gem installed (`jruby -S gem install bundler`).

- Install dependencies

```sh
jruby -S bundle install
```

#### Test

- Run tests

```sh
jruby -S bundle exec rspec
```

### Running your plugin locally in Logstash

#### Linking the gem

- Edit Logstash's `Gemfile` and add the local plugin path, for example:

```ruby
gem "logstash-input-google-analytics-daily", :path => "/your/local/logstash-input-googleanalytics"
```

- Install the plugin
```sh
bin/plugin install --no-verify
```
- Run Logstash with your plugin
Example logstash.conf:

```
input {
  google_analytics_daily {
    view_id => "ga:62549480"
    metrics =>  ["ga:users","ga:sessions"]
    key_file_path => "C:/logstash-7.6.1/keyfile.json"
    dates => ['yesterday', '2020-04-05']
    dimensions => ['ga:browser', 'ga:city']
  }
}

output {
  stdout {
    codec => rubydebug
  }
}
```

```sh
bin/logstash -f logstash.conf
```

NOTE: Any modifications to the plugin code will not show up until you restart Logstash.

#### 2.2 Run in an installed Logstash

 Logstash by editing its `Gemfile` and pointing the `:path` to your local plugin development directory or you can build the gem and install it using:

- Build your plugin gem
```sh
jruby -S gem build logstash-input-google-analytics-daily.gemspec
```
- Install the plugin from the Logstash home
```sh
bin/plugin install  install Projects/logstash-input-google-analytics-daily/logstash-input-google-analytics-daily-1.0.0.gem
```
- Start Logstash with your pipeline config:

```sh
bin/logstash -f logstash.conf
```