ENV['RACK_ENV'] = 'test'

require './spec/spec_helper'
require 'twitterclone/app'

describe 'twitterclone' do
  include Rack::Test::Methods
  def app
    TwitterClone::Application
  end


  describe 'display login page' do
    it 'status code 200' do
      get '/login'
      expect(last_response).to be_ok
      expect(last_response.status).to eq(200)
    end
  end

  describe 'When you are not login' do 
 
    before(:each) { get '/' }

    it 'status code 303' do
      expect(last_response.status).to eq(303)
    end
    it 'redirect to /login' do
      expect(last_response.redirect?).to be_truthy
      follow_redirect!
      expect(last_request.path).to eq('/login')
    end
  end

  describe 'Authorization' do
    describe 'should be failure in login' do
      before(:each) { post '/login' }
      it 'redirect to /login' do
        expect(last_request.path).to eq('/login')
      end
      it 'display error message' do 
        expect(last_response.body).to include('Incorrect username or password')
      end
    end
    describe 'should be success in login' do
      #let!(:user) { { username: 'testuser1', password: 'testtest' } }
      #let!(:user) {  FactoryGirl.create(:user) }
      before(:each) { post '/login', username: 'testuser1', password: 'testtest' }
      it 'status code 200' do 
        expect(last_response.status).to eq(200)
      end
      it 'success logged in' do
        #skip
        #expect(last_response.redirect?).to be_truthy
        #follow_redirect!
        expect(last_request.path).to eq('/')
      end
    end
  end
end
