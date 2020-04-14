# encoding: utf-8
require "logstash/inputs/base"
require "logstash/namespace"
require "stud/interval"
require 'google/apis/analytics_v3'
require 'googleauth'
require 'json'

# Pull daily reports from Google Analytics using the v3 Core Reporting API.
# This plugin will generate one Logstash event per date, with each event containing all the data for that date
# The plugin will try to maintain a single event per date and list of metrics

class LogStash::Inputs::GoogleAnalyticsDaily < LogStash::Inputs::Base
  config_name "google_analytics_daily"

  # If undefined, Logstash will complain, even if codec is unused.
  default :codec, "plain"

  # Most of these inputs are described in the Google Analytics API docs.
  # https://developers.google.com/analytics/devguides/reporting/core/v3/reference#q_details
  # Any changes from the format described above have been noted.

  # Type for logstash filtering
  config :type, :validate => :string, :default => 'google_analytics_daily'

  # View (profile) id, in the format 'ga:XXXX'
  # https://developers.google.com/analytics/devguides/reporting/core/v3/reference#ids
  config :view_id, :validate => :string, :required => true

  # This plugin will fetch daily reports for dates in the specified range
  # In the format YYYY-MM-DD
  config :start_date, :validate => :string, :required => true

  config :end_date, :validate => :string, :default => Time.now.to_s

  # The aggregated statistics for user activity to your site, such as clicks or pageviews.
  # Maximum of 10 metrics for any query
  # https://developers.google.com/analytics/devguides/reporting/core/v3/reference#metrics
  # For a full list of metrics, see the documentation
  # https://developers.google.com/analytics/devguides/reporting/core/dimsmets
  config :metrics, :validate => :string, :list => true, :required => true

  # Breaks down metrics by common criteria; for example, by ga:browser or ga:city
  # Maximum of 7 dimensions in any query
  # https://developers.google.com/analytics/devguides/reporting/core/v3/reference#dimensions
  # For a full list of dimensions, see the documentation
  # https://developers.google.com/analytics/devguides/reporting/core/dimsmets
  config :dimensions, :validate => :string, :list => true, :default => []

  # Used to restrict the data returned from your request
  # https://developers.google.com/analytics/devguides/reporting/core/v3/reference#filters
  config :filters, :validate => :string, :default => nil

  # A list of metrics and dimensions indicating the sorting order and sorting direction for the returned data
  # https://developers.google.com/analytics/devguides/reporting/core/v3/reference#sort
  config :sort, :validate => :string, :default => nil

  # https://developers.google.com/analytics/devguides/reporting/core/v3/reference#segment
  config :segment, :validate => :string, :default => nil

  # Valid values are DEFAULT, FASTER, HIGHER_PRECISION
  # https://developers.google.com/analytics/devguides/reporting/core/v3/reference#samplingLevel
  config :sampling_level, :validate => :string, :default => nil

  # https://developers.google.com/analytics/devguides/reporting/core/v3/reference#include-empty-rows
  config :include_empty_rows, :validate => :boolean, :default => true

  # These values need to be pulled from your Google Developers Console
  # For more information, see the docs. Be sure to enable Google Analytics API
  # access for your application.
  # https://developers.google.com/identity/protocols/OAuth2ServiceAccount

  # This should be the path to the public/private key as a standard P12 file
  config :key_file_path, :validate => :string, :required => true

  # This will store the query in the resulting logstash event
  # https://developers.google.com/analytics/devguides/reporting/core/v3/reference#data_response
  config :store_query, :validate => :boolean, :default => true

  # This will store the profile information in the resulting logstash event
  # https://developers.google.com/analytics/devguides/reporting/core/v3/reference#data_response
  config :store_profile, :validate => :boolean, :default => true

  # Interval to run the command. Value is in seconds. If no interval is given,
  # this plugin only fetches data once.
  config :interval, :validate => :number, :required => false, :default => 60 * 60 * 24 # Daily


  public

  def register
  end

  def run(queue)
    # we abort the loop if stop? becomes true
    while !stop?
      start_time = Time.now

      analytics = get_service

      @dates = (Date.parse(@start_date)..Date.parse(@end_date))

      @dates.each do |date|
        date = date.to_s
        options = get_request_parameters(date)

        results = analytics.get_ga_data(
            options[:view_id],
            options[:start_date],
            options[:end_date],
            options[:metrics],
            dimensions: options[:dimensions],
            filters: options[:filters],
            include_empty_rows: options[:include_empty_rows],
            sampling_level: options[:sampling_level],
            segment: options[:segment],
            sort: options[:sort],
        )

        column_headers = results.column_headers.map &:name

        rows = []

        if results.rows && results.rows.first

          # Example with dimensions, multiple metrics:
          # rows: [[Chrome, Cape Town, 6, 8], [Chrome, Paris, 1, 5], [Safari, Paris, 1, 3]], column_headers: ['ga:browser', 'ga:city', 'ga:user', 'ga:sessions']
          # Example with dimension, single metric:
          # rows: [[Chrome, 6]], column_headers: ['ga:browser', 'ga:user']
          # Example with no dimension, single metric:
          # rows: [[6]], column_headers: ['ga:user']
          # Dimensions always appear before values
          results.rows.each do |row|
            dimensions = []
            metrics = []

            column_headers.zip(row) do |header, value|
              # Combine GA column headers with values from row
              if is_num(value)
                float_value = Float(value)
                # Sometimes GA returns infinity. if so, the number is invalid
                # so set it to zero.
                value = (float_value == Float::INFINITY) ? 0.0 : float_value
              end

              entry = {
                  name: header,
                  value: value
              }
              if @metrics.include?(header)
                metrics << entry
              else
                dimensions << entry
              end

            end

            rows << {metrics: metrics, dimensions: dimensions}
          end

          query = results.query.to_h
          profile_info = results.profile_info.to_h

          # Transform into proper format for one event per metric
          @metrics.each do |metric|
            rows_for_this_metric = rows.clone.map do |row|
              new_row = {}
              new_row[:metric] = row[:metrics].find { |m| m[:name] == metric }
              new_row[:dimensions] = row[:dimensions]
              new_row
            end

            rows_for_this_metric.each do |row|
              event = LogStash::Event.new
              decorate(event)
              # Populate Logstash event fields
              event.set('ga.contains_sampled_data', results.contains_sampled_data?)
              event.set('ga.query', query.to_json) if @store_query
              event.set('ga.profile_info', profile_info) if @store_profile
              event.set('ga.date', date)

              event.set("ga.metric.name", metric)
              event.set("ga.metric.value", row[:metric][:value])


              # Remap dimensions into key: value
              # Might lead to "mapping explosion", but otherwise aggregations are tough
              joined_dimension_name = ''
              row[:dimensions].each do |d|
                dimension_name = d[:name].sub("ga:", '')
                joined_dimension_name += dimension_name
                event.set("ga.dimensions.#{dimension_name}", d[:value])
              end

              queue << event
            end
          end
        end
      end

      # If no interval was set, we're done
      if @interval.nil?
        break
      else
        # Otherwise we sleep till the next run
        time_lapsed = Time.now - start_time
        # Sleep for the remainder of the interval, or 0 if the duration ran
        # longer than the interval.
        time_to_sleep_for = [0, @interval - time_lapsed].max
        if time_to_sleep_for == 0
          @logger.warn(
              "Execution ran longer than the interval. Skipping sleep.",
              :duration => time_lapsed,
              :interval => @interval
          )
        else
          Stud.stoppable_sleep(time_to_sleep_for) { stop? }
        end
      end
    end # loop
  end

  private

  def get_request_parameters(date)
    options = {
        :view_id => @view_id,
        :start_date => date,
        :end_date => date,
        :metrics => @metrics.join(','),
        :output => 'json',
    }
    options.merge!({:dimensions => @dimensions.join(',')}) if (@dimensions and @dimensions.size)
    options.merge!({:filters => @filters}) if @filters
    options.merge!({:sort => @sort}) if @sort
    options.merge!({:segment => @segment}) if @segment
    options.merge!({:sampling_level => @sampling_level}) if @sampling_level
    options.merge!({:include_empty_rows => @include_empty_rows}) if !@include_empty_rows.nil?
    return options
  end

  def get_service
    scope = 'https://www.googleapis.com/auth/analytics.readonly'
    authorizer = Google::Auth::ServiceAccountCredentials.make_creds(
        json_key_io: File.open(@key_file_path),
        scope: scope
    )

    analytics = Google::Apis::AnalyticsV3::AnalyticsService.new
    analytics.authorization = authorizer
    return analytics
  end

  private

  def is_num(a)
    return (Float(a) and true) rescue false
  end
end # class LogStash::Inputs::GoogleAnalytics

