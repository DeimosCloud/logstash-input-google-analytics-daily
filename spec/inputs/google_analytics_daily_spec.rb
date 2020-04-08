# Tests currently nto in use
#
# # encoding: utf-8
# require "logstash/inputs/google_analytics_daily"
# require "vcr"
# require "json"
#
# ENV['SSL_CERT_FILE'] = "/Users/rsavage/Downloads/cacert.pem"
#
# VCR.configure do |config|
#   config.cassette_library_dir = File.join(File.dirname(__FILE__), '..', 'fixtures', 'vcr_cassettes')
#   config.hook_into :webmock
# end
#
# RSpec.describe LogStash::Inputs::GoogleAnalyticsDaily do
#   describe "inputs/google_analytics_daily" do
#     context "get users overview" do
#       let(:options) do
#         {
#             "view_id" => "ga:213576060",
#             "metrics" => ["ga:users","ga:sessions"],
#             "key_file_path" => "C:/logstash-7.6.1/keyfile.json",
#             "dates" => ['yesterday', '2020-04-05'],
#             'dimensions' => ['ga:browser'],
#             "interval" => nil,
#
#         }
#       end
#       let(:input) { LogStash::Inputs::GoogleAnalyticsDaily.new(options) }
#       let(:expected_fields_result) { ["ga_pageviews"] }
#       let(:queue) { [] }
#       subject { input }
#       it "loads pageviews" do
#         #VCR.use_cassette("get_audience_overview") do
#           subject.register
#           subject.run(queue)
#           expect(queue.length).to eq(1)
#           e = queue.pop
#           expected_fields_result.each do |f|
#             expect(e.to_hash).to include(f)
#           end
#         #end
#       end
#     end
#   end
#
# end
