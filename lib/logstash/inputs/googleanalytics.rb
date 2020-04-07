# encoding: utf-8
require "logstash/inputs/base"
require "logstash/namespace"
require "stud/interval"
require 'google/apis/analytics_v3'
require 'googleauth'

# Generate a repeating message.
#
# This plugin is intented only as an example.

class LogStash::Inputs::GoogleAnalytics < LogStash::Inputs::Base
  config_name "googleanalytics"

  # If undefined, Logstash will complain, even if codec is unused.
  default :codec, "plain"

  # Most of these inputs are described in the Google Analytics API docs.
  # https://developers.google.com/analytics/devguides/reporting/core/v3/reference#q_details
  # Any changes from the format described above have been noted.

  # Type for logstash filtering
  config :type, :validate => :string, :default => 'googleanalytics'

  # View (profile) id, in the format 'ga:XXXX'
  # https://developers.google.com/analytics/devguides/reporting/core/v3/reference#ids
  config :view_id, :validate => :string, :required => true

  # In the format YYYY-MM-DD, or relative by using today, yesterday, or the NdaysAgo pattern
  # https://developers.google.com/analytics/devguides/reporting/core/v3/reference#startDate
  config :start_date, :validate => :string, :default => 'yesterday'

  # In the format YYYY-MM-DD, or relative by using today, yesterday, or the NdaysAgo pattern
  # https://developers.google.com/analytics/devguides/reporting/core/v3/reference#endDate
  config :end_date, :validate => :string, :default => 'yesterday'

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
  config :dimensions, :validate => :string, :list => true, :default => nil

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
  # This is the result to start with, beginning at 1
  # You probably don't need to change this but it has been included here for completeness
  # https://developers.google.com/analytics/devguides/reporting/core/v3/reference#startIndex
  config :start_index, :validate => :number, :default => 1
  # This is the number of results in a page. This plugin will start at
  # @start_index and keep pulling pages of data until it has all results.
  # You probably don't need to change this but it has been included here for completeness
  # https://developers.google.com/analytics/devguides/reporting/core/v3/reference#maxResults
  config :max_results, :validate => :number, :default => 10000
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
  config :interval, :validate => :number, :required => false


  public
  def register
  end # def register

  def run(queue)
    # we can abort the loop if stop? becomes true
    while !stop?
      start_time = Time.now

      analytics = get_service
      results_index = @start_index

      while !stop?
        options = client_options(results_index)
        puts options
        results = analytics.get_ga_data(
            options['view_id'],
            options['start-date'],
            options['end-date'],
            options['metrics'],
            dimensions: options['dimensions'],
        )

        @logger.warn('Result', :data => results)
        if results.rows.first
          query = results.query.to_h
          profile_info = results.profile_info.to_h
          column_headers = results.column_headers.map{|c| c.name}

          results.rows.each do |row|
            event = LogStash::Event.new
            decorate(event)
            # Populate Logstash event fields
            event.set('ga.contains_sampled_data', results.contains_sampled_data?)
            event.set('ga.query', query) if @store_query
            event.set('ga.profile_info', profile_info) if @store_profile

            # Combine GA column headers with values from row as key-value group
            column_headers.zip(row).each do |key, value|
              if is_num(value)
                float_value = Float(value)
                # Sometimes GA returns infinity. if so, the number is invalid
                # so set it to zero.
                if float_value == Float::INFINITY
                  event.set(key.gsub(':','.metrics.'), 0.0)
                else
                  event.set(key.gsub(':','.metrics.'), float_value)
                end
              else
                event.set(key.gsub(':','.metrics.'), value)
              end
            end

            # Try to add a date unless it was already added
            # %F = YYYY-MM-DD
            if @start_date == @end_date
                # if @start_date == 'today'
                #   event.set('ga_date', Date.parse(Time.now.strftime("%F")))
                # elsif @start_date == 'yesterday'
                #   event.set('ga_date', Date.parse(Time.at(Time.now.to_i - 86400).strftime("%F")))
                # elsif @start_date.include?('daysAgo')
                #   days_ago = @start_date.sub('daysAgo','').to_i
                #   event.set('ga_date', Date.parse(Time.at(Time.now.to_i - (days_ago*86400)).strftime("%F")))
                # else
                #   event.set('ga_date', Date.parse(@start_date))
                # end
            else
              # Convert YYYYMMdd to YYYY-MM-dd
              event.set('ga_date', Date.parse(Time.now.strftime("%F")).to_s)
            end

            # Use date as ID to prevent duplicate entries in Elasticsearch
            event.set('_id', event.get('ga_date'))

            puts event.to_hash
            queue << event
          end
        end

        # Iterate over all pages of the results before  moving on
        nextLink = results.next_link rescue nil
        if nextLink
          start_index += @max_results
        else
          break
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
  end # def run

  private
  def client_options(results_index)
    options = {
      'view_id' => @view_id,
      'start-date' => @start_date,
      'end-date' => @end_date,
      'metrics' => @metrics.join(','),
      'max-results' => @max_results,
      'output' => 'json',
      'start-index' => results_index
    }
    options.merge!({ 'dimensions' => @dimensions.join(',') }) if @dimensions
    options.merge!({ 'filters' => @filters }) if @filters
    options.merge!({ 'sort' => @sort }) if @sort
    options.merge!({ 'segment' => @segment }) if @segment
    options.merge!({ 'samplingLevel' => @sampling_level }) if @sampling_level
    options.merge!({ 'include-empty-rows' => @include_empty_rows }) if !@include_empty_rows.nil?
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

