require 'digest/md5'
require 'json'

require 'active_support/cache'
require 'amatch'
require 'dalli'
require 'faraday'
require 'faraday_middleware'
require 'fuzzy_match'
require 'json-pointer'
require 'sinatra'
require 'sinatra/cross_origin'

FuzzyMatch.engine = :amatch

module WhosGotDirt
  class JSONFileAPI < Sinatra::Base
    WHITELIST = ENV['WHOSGOTDIRT_WHITELIST'].split(',')

    register Sinatra::CrossOrigin
    enable :cross_origin

    helpers do
      # Returns an HTTP/HTTPS client.
      #
      # @return [Faraday::Connection] an HTTP/HTTPS client
      def client
        @client ||= Faraday.new do |connection|
          connection.request :url_encoded

          connection.use FaradayMiddleware::Gzip

          if ENV['MEMCACHIER_SERVERS']
            connection.response :caching do
              ActiveSupport::Cache::MemCacheStore.new(ENV['MEMCACHIER_SERVERS'], {
                expires_in: 86400, # 1 day
                value_max_bytes: Integer(1048576), # 1 MB
                username: ENV['MEMCACHIER_USERNAME'],
                password: ENV['MEMCACHIER_PASSWORD'],
              })
            end
          end

          connection.adapter Faraday.default_adapter
        end
      end

      # Returns an HTTP status code with an error message.
      #
      # @param [Fixnum] status_code a status code
      # @param [String] error_message an error message
      # @return [Array] the status code and error message
      def error(status_code, error_message)
        content_type 'application/json'
        [status_code, JSON.dump({error: {message: error_message}})]
      end

      # Sets the `Content-Type` and `ETag` headers and returns the response as a JSON string.
      #
      # @param [Hash] a JSON-serializable hash
      # @return [String] a JSON string
      def etag_and_return(response)
        content_type 'application/json'
        etag Digest::MD5.hexdigest(response.inspect)
        JSON.dump(response)
      end
    end

    get '/*' do
      # Sinatra collapses the slashes in the splat.
      url = URI::Parser.new.unescape(env['REQUEST_PATH'][1..-1])
      if url.empty?
        return error(404, "URL path must be an encoded URL")
      end
      if !WHITELIST.include?(url)
        return error(404, "'#{url}' is not a whitelisted URL")
      end
      ['path', 'q'].each do |parameter|
        if !params.key?(parameter)
          return error(422, "parameter '#{parameter}' must be provided")
        end
        if params[parameter].nil? || params[parameter].empty?
          return error(422, "parameter '#{parameter}' can't be blank")
        end
      end
      path = params[:path]

      response = client.get(url)
      # The response body must be a JSON array.
      fuzzer = FuzzyMatch.new(JSON.load(response.body), read: lambda{|record|
        # @see https://gist.github.com/jpmckinney/1374639
        JsonPointer.new(record, path).value.tr(
          'ÀÁÂÃÄÅàáâãäåĀāĂăĄąÇçĆćĈĉĊċČčÐðĎďĐđÈÉÊËèéêëĒēĔĕĖėĘęĚěĜĝĞğĠġĢģĤĥĦħÌÍÎÏìíîïĨĩĪīĬĭĮįİıĴĵĶķĸĹĺĻļĽľĿŀŁłÑñŃńŅņŇňŉŊŋÒÓÔÕÖØòóôõöøŌōŎŏŐőŔŕŖŗŘřŚśŜŝŞşŠšſŢţŤťŦŧÙÚÛÜùúûüŨũŪūŬŭŮůŰűŲųŴŵÝýÿŶŷŸŹźŻżŽž',
          'aaaaaaaaaaaaaaaaaaccccccccccddddddeeeeeeeeeeeeeeeeeegggggggghhhhiiiiiiiiiiiiiiiiiijjkkkllllllllllnnnnnnnnnnnoooooooooooooooooorrrrrrsssssssssttttttuuuuuuuuuuuuuuuuuuuuwwyyyyyyzzzzzz')
      })

      threshold = Float(ENV['WHOSGOTDIRT_THRESHOLD'] || 0.4)
      results = fuzzer.find(params[:q], find_all_with_score: true).select{|result|
        result[1] > threshold
      }.map(&:first)

      etag_and_return(results)
    end
  end
end
