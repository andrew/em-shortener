require 'rubygems'
require 'em-redis'
require 'uri'
require 'base62'
require 'eventmachine'
require 'evma_httpserver'

class Shortener < EM::Connection
  include EM::HttpServer
  attr_reader :http_request_uri, :http_query_string

   def post_init
     super
     no_environment_strings
   end

  def process_http_request
    redis = EM::Protocols::Redis.connect
    path  = @http_request_uri.to_s
    query = @http_query_string.to_s

    response = EM::DelegatedHttpResponse.new(self)

    case path
    when '/'
      if @http_query_string
        params = URI.decode_www_form(query)
        url = params.assoc('url').last.chomp
        
        redis.keys '*' do |result|
          key = result.size.base62_encode
          redis.set key, url do |result|
            response.status = 200
            response.content_type 'text/html'
            response.content = "http://localhost:9000/#{key}"
            response.send_response
          end
        end
      else
        response.status = 200
        response.content_type 'text/html'
        response.content = 'Hi'
        response.send_response
      end
    else
      redis.get path[1..-1] do |result|
        response.status = 302
        response.headers["Location"] = result
        response.send_response
      end
    end
  end
end

EM.run{
  EM.start_server '0.0.0.0', 9000, Shortener
}