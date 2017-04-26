module Vtiger
  require 'net/http'
  require 'uri'
  require 'digest/md5'
  require 'json'

  class API
    attr_reader :user_id

    def initialize(url, username, accesskey)
      script = 'webservice.php'
      @URI = URI.join url, script
      @accesskey = accesskey
      @username = username

      if username && accesskey
        @session_id = login getchallenge
      else
        raise 'Please set username and accesskey.'
      end
    end

    # Sync will return a SyncResult object containing details of changes after modifiedTime.
    def sync(modified_time)
      query = {
        operation: :sync,
        modifuedTime: modified_time,
        elementType: element_type
      }
      params = {sessionName: @session_id}
      res = post_request query, params
      res['result']
    end

    # Logout from the webservices session, this leaves
    # the webservice session invalid for further use.
    def logout
      query = {operation: :logout}
      params = {sessionName: @session_id}
      res = post_request query, params
      res['message']
    end

    # List the names of all the Vtiger objects available through the api.
    def listtypes
      query = {
        operation: 'listtypes',
        sessionName: @session_id
      }
      res = get_request query
      res['result']
    end

    # Get the type information about a given Vtiger object.
    def describe(element_type)
      query = {
        operation: :describe,
        elementType: element_type,
        sessionName: @session_id
      }
      res = get_request query
      res['result']
    end

    # Create a new entry on the server.
    def create(element_type, element)
      query = {operation: :create}
      params = {
        sessionName: @session_id,
        elementType: element_type, # Module Name
        element: JSON.generate(element) # JSON Map of (fieldname=fieldvalue)
      }
      res = post_request query, params
      res['result']
    end

    # Retrieve an existing entry from the server.
    def retrieve(id)
      query = {
        operation: :retrieve,
        sessionName: @session_id,
        id: id
      }
      res = get_request query
      res['result']
    end

    # Update an existing entry on the vtiger crm object.
    def update(element)
      query = {operation: :update}
      params = {
        sessionName: @session_id,
        element: JSON.generate(element)
      }
      res = post_request query, params
      res['result']
    end

    # Delete an entry from the server.
    def delete(id)
      query = {operation: :delete}
      params = {
        sessionName: @session_id,
        id: id
      }
      res = post_request query, params
      res['result']
    end

    # The query operation provides a way to query vtiger for data.
    def query(query_string)
      query = {
        operation: :query,
        query: query_string
      }
      params = {sessionName: @session_id}
      res = post_request query, params
      res['result']
    end

    private

    def get_request(query)
      @URI.query = URI.encode_www_form(query)
      begin
        res = JSON.parse Net::HTTP.get_response(@URI).body
      rescue Net::HTTPServerError
        raise 'Server error.'
      rescue JSON::ParserError, TypeError => e
        raise 'Server response is not valid JSON.'
      end

      raise res['error']['message'] unless res['success']
      res
    end

    def post_request(query, params={})
      @URI.query = URI.encode_www_form(query)
      http = Net::HTTP.new(@URI.host, @URI.port)
      req = Net::HTTP::Post.new(@URI.request_uri)
      req.content_type = 'application/x-www-form-urlencoded'
      req.body = URI.encode_www_form(params)
      begin
        res = JSON.parse(http.request(req).body)
      rescue Net::HTTPServerError
        raise 'Server error.'
      rescue JSON::ParserError, TypeError => e
        raise 'Server response is not valid JSON'
      end

      raise res['error']['message'] unless res['success']
      res
    end

    # Get a challenge token from the server.
    def getchallenge
      query = {
        operation: :getchallenge,
        username: @username
      }
      res = get_request query
      res['result']['token']
    end

    # Login to the server using the challenge token obtained
    # in get challenge operation.
    def login(token)
      query = {operation: :login}
      params = {
        username: @username,
        accessKey: Digest::MD5.hexdigest(token + @accesskey)
      }
      res = post_request query, params
      @user_id = res['result']['userId']
      res['result']['sessionName']
    end

    def valid_json?(json)
        JSON.parse(json)
        return true
      rescue JSON::ParserError => e
        return false
    end

  end
end
