require 'net/http'
require 'json'


class HTTPException < Exception
    attr_accessor :http_response
    def initialize(res)
        @http_response = res
    end
end
class ApiError < Exception; end

class TwitterApi
    attr_reader :api_base
    attr_reader :req_path_buf
    
    def initialize(arg_hash = {})
        @api_base = arg_hash[:api_base] || 'https://api.twitter.com/1' 
        @req_path_buf = ''
    end

    def do_request(query_form = {}, post_data = nil)
        uri = URI(@api_base + @req_path_buf)
        @req_path_buf = ''

        uri.query = URI.encode_www_form(query_form)

        res = nil
        if post_data.nil?
            res = Net::HTTP.get_response(uri)
        else
            res = Net::HTTP.post_form(uri, post_data)
        end

        json = nil
        case res
        when Net::HTTPSuccess then
            json = JSON.parse(res.body)
        when Net::HTTPRedirection then
            json = JSON.parse(Net::HTTP.get_response(URI(res['location'])).body)
        else
            raise HTTPException.new(res)
        end

        if json.has_key? 'error'
            raise ApiError, json['error']
        end
        
        return json
    end

    def method_missing(method, *args)
        @req_path_buf << '/' << method.to_s
        if args.empty?
            return self
        else
            @req_path_buf << '.json'
            return self.send :do_request, *args
        end
    end
end

