#!/usr/bin/env ruby
# API app
require 'sinatra/base'
require 'sinatra/param'
require 'json'
require 'dbm'
require 'fileutils'
require 'yaml'
require_relative 'vtiger'

# for developing
require 'pry'
require 'pry-byebug'
require 'sinatra/reloader'

# configs
require_relative 'config'

class Parser
  def initialize
    @vtiger_api = Vtiger::API.new(REQUEST_URL, VTIGER_USERNAME, VTIGER_ACCESSKEY)
    @vtiger_params = [
      :company,
      :website,
      :description,
      :city,
      :country,
      :state,
      :uid,
      :tags,
      :id
    ]
    @dict = init_dict
  end

  def get_lead(id)
    webservice_id = "#{@vtiger_api.describe('Leads')['idPrefix']}x#{id}" # <object_type_id>x<object_id> => 12x10
    @vtiger_api.retrieve(webservice_id)
  end

  def get_leads(count, offset)
    # TODO: пока не надо
  end

  def process_tags(tags)
    tech = []
    tags.select! do |v|
      if @dict.has_key?(v.downcase)
        tech << @dict[v.downcase]
        false
      else
        true
      end
    end
    {
      tags: tags,
      tech: tech.uniq
    }
  end

  def create_lead(params, lead_params)
    element = params.select { |k| lead_params.index(k.to_sym) }
    element['created_user_id'] = @vtiger_api.user_id
    element['assigned_user_id'] = @vtiger_api.user_id
    element['industry'] = params['source']
    unless params['tags'].nil?
      tech_n_tags = process_tags params['tags']
      element['tags'] = tech_n_tags[:tags].join(' |##| ') unless tech_n_tags[:tags].nil?
      element['tech'] = tech_n_tags[:tech].join(' |##| ') unless tech_n_tags[:tech].nil?
    end
    @vtiger_api.create('Leads', element)
  end

  def update_lead(params, lead_params)
    element = params.select { |k| lead_params.index(k.to_sym) }
    element['assigned_user_id'] = @vtiger_api.user_id
    element['industry'] = params['source']
    element['id'] = get_lead_id params['uid']
    unless params['tags'].nil?
      tech_n_tags = process_tags params['tags']
      element['tags'] = tech_n_tags[:tags].join(' |##| ') unless tech_n_tags[:tags].nil?
      element['tech'] = tech_n_tags[:tech].join(' |##| ') unless tech_n_tags[:tech].nil?
    end
    @vtiger_api.update(element)
  end

  private

  def get_lead_id(uid)
    @vtiger_api.query("SELECT * FROM Leads WHERE uid = '#{uid}' LIMIT 1;")[0]['id']
  end

  def init_dict
    lang = YAML.load_file('lang.yml')
    tech = YAML.load_file('tech.yml')
    tech.merge!(lang)
    dict = {}
    tech.each do |orig, syn|
      if syn.kind_of?(Array)
        syn.each { |v| dict[v.downcase] = orig }
      else
        dict[syn.downcase] = orig
      end
    end
    dict
  end
end

class Upwork_parser < Parser
  def initialize(*args)
    super

    @lead_params = [
      :contract_date,
      :active_assignments_count,
      :feedback_count,
      :hours_count,
      :score,
      :avg_hourly_jobs_rate,
      :total_assignments,
      :total_charges,
      :total_jobs_with_hires,
      :filled_count,
      :open_count,
      :posted_count,
      :is_payment_method_verified
    ].concat @vtiger_params
  end

  def create_lead(data)
    super data, @lead_params
  end

  def update_lead(data)
    super data, @lead_params
  end
end

class Angel_parser < Parser
  def initialize(*args)
    super

    @lead_params = [
      :employees,
      :product,
      :location,
      :status,
      :applicants,
      :why_us
    ].concat @vtiger_params
  end

  def create_lead(data)
    super data, @lead_params
  end

  def update_lead(data)
    super data, @lead_params
  end
end

class Dima_jr_paser < Parser
  def initialize(*args)
    super
  end
end

class App < Sinatra::Base
  helpers Sinatra::Param

  set :show_exceptions, false

  configure :development do
    register Sinatra::Reloader
  end

  helpers do
    def valid_key? (key)
       /^#{key}$/ === APIKEY
    end
  end

  before do
    content_type :json
    @data = JSON.parse(request.body.read) rescue {}
    error 401 unless valid_key? @data['apikey']
  end

  error do
    status 400
    e = env['sinatra.error']
    {
      status: 'ERROR',
      error_message: e.message
    }.to_json
  end

  # GET /lead/123 - view lead
  get '/lead/:id' do
    Parser.new.get_lead(id: params[:id]).to_json
  end

  # GET /leads - view leads
  get '/leads' do
    # TODO: пока не надо
    {
      status: 'ERROR',
      error_message: 'temporary not implemented'
    }.to_json
  end

  # POST /lead - create new Lead
  post '/lead' do
    case @data['source']
    when 'angel.co'
      res = Angel_parser.new.create_lead @data
    when 'upwork.com'
      res = Upwork_parser.new.create_lead @data
    else
      raise "Incorrect `source`."
    end

    {
      status: 'OK',
      results: res
    }.to_json
  end

  # PUT /lead - update Lead
  put '/lead' do
    case @data['source']
    when 'angel.co'
      res = Angel_parser.new.update_lead @data
    when 'upwork.com'
      res = Upwork_parser.new.update_lead @data
    else
      raise "Incorrect `source`."
    end

    {
      status: 'OK',
      results: res
    }.to_json
  end

  # запускаем сервер, если исполняется текущий файл
  run! if app_file == $0
end
