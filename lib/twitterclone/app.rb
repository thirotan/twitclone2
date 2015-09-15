require 'sinatra/base'
require 'sinatra/contrib'
require 'slim'
require 'mysql2-cs-bind'
require 'rack-flash'
require 'json'


module TwitterClone
  class Application < Sinatra::Base

    configure  do
      enable :sessions
      use Rack::Session::Cookie, secret: ENV['twit_session_secret'] || 'teitsql'
      use Rack::Flash
      set :root, File.dirname(__FILE__) + '/../../'
    end

    def db
      Thread.current[:twit_db] ||= Mysql2::Client.new(
        host: ENV['twit_db_host'] || 'localhost',
        port: ENV['twit_db_port'] ? ENV['twit_db_port'].to_i : nil,
        username: ENV['twit_db_user'] || 'dev',
        password: ENV['twit_db_password'] || 'abcdefg',
        database: ENV['twit_db_name'] || 'twit_db',
        reconnect: true,
      )
    end
    
    def calculate_password_hash(password, salt)
      Digest::SHA256.hexdigest "#{password}:#{salt}"
    end

    def hash_pw(salt, password)
      Digest::MD5.hexdigest(salt + password)
    end
 

    helpers do
      def link_to_user(user)
        f = <<-HTML
<a href="/user/#{user}">#{user}</a>
        HTML
      end

      def link_to_post_user(user)
        db.xquery("SELECT * FROM users WHERE id = (select user_id from posts where id = ?);", user)
        #Post.username(user.id)
      end

      def pluralize(singular, plural, count)
        if count == 1
          count.to_s + " " + singular
        else
          count.to_s + " " + plural
        end
      end

    end

    def display_post(post)
      if post.content
        post.content.to_s.gsub(/@\w+/) do |mention|
          # change to mysql query
          if user = db.xquery("SELECT * FROM users WHERE username = ?;", mention[1..-1])
          # if user = User.find_by_username(mention[1..-1])
            "@" + link_to_user(user)
          else
            mention
          end
        end
      end 
    end 

    def time_ago_in_words(time)
      distance_in_seconds = (Time.now - time).round
      case distance_in_seconds
      when 0..10
        return "just now"
      when 10..60
        return "less then a minite age"
      end
      distance_in_minutes = (distance_in_seconds/60).round
      case distance_in_minutes
      when 0..1
        return "a minute age"
      when 2..45
        return distance_in_minutes.round.to_s + " minutes ago"
      when 46..89
        return "about an hour ago"
      when 90..1439
        return (distance_in_minutes/60).round.to_s + " hours ago"
      when 1440..2879
        return "about a day ago"
      when 2890..43199
        return (distance_in_minutes/1440).round.to_s + "days ago" 
      when 43200..86399
        return "abount a month ago"
      when 86400..525599
        return (distance_in_minutes/43200).round.to_s + "months ago"
      when 525600..1051199
        return "about a year ago"
      else
        "over " + (distance_in_minutes/525600).round.to_s + " years ago"
      end
    end
 
    before do
      # change to mysql query
      #keys = User.get_keys("*")
      unless %w(/login /signup).include?(request.path_info) or 
          request.path_info =~ /\.css$/ or session["user_id"]
        redirect '/login', 303
      end
      @logged_in_user = db.xquery("SELECT username FROM users WHERE id = ?;", session["user_id"])
    end


    get '/' do
      @posts = @logged_in_user.timeline
      slim :index
    end

    get '/timeline' do
      @posts = db.xquery("SELECT message FROM posts where posts BETWEEN last_post_id TO last_opst_id-10 ")
      slim :timeline
    end

    post '/post' do 
      if params[:content].length == 0
        @posting_error = "You didn't enter anything."
      elsif params[:content].length > 140
        @posting_error = "Keep it to 140 characters please!"
      end
      if @posting_error
        @posts = @logged_in_user.timeline
        slim :index
      else
        posted_time = Time.now
        db.xquery("INSERT into posts (user_id, message, created_at), values(?, ?, ?)", session["user_id"]. params[:content], posted_time)
        redirect '/'
      end
    end

    get '/:follower/follow/:followee' do |follower_username, followee_username|
      follower = db.xquery("SELECT * FROM users WHERE username = ?;", follower_username)
      follwoees = db.xquery("SELECT * FROM users WHERE username = ?;", followee_username)
      redirect '/' unless @logged_in_user == follower
      follower.follow(followee)
      redirect "/user/" + followee_username
    end

    get '/:follower/stopfollow/:followee' do |follower_username, followee_username|
      follower = db.xquery("SELECT * FROM users WHERE username = ?;", follower_username)
      follwoees = db.xquery("SELECT * FROM users WHERE username = ?;", followee_username)
      redirect '/' unless @logged_in_user == follower
      follower.stop_following(followee)
      redirect '/' + followee_username
    end

    get '/user/:username' do |username|
      @user = db.xquery("SELECT * FROM users WHERE username = ?;", usernmae)
      @posts = @user.posts
      @followers = @user.followers
      @followees = @user.followees
      slim :profile
    end

    get '/:username/mentions' do |username|
      @user = db.xquery("SELECT * FROM users WHERE username = ?;", usernmae)
      @user = User.find_by_username(username)
      @posts = @user.mentions
      slim :mentions
    end

    get '/login' do 
      slim :login
    end

    post '/login' do 
      if user = db.xquery("SELECT * FROM users WHERE username = ?;", usernmae) and
          hash_pw(user.salt, params[:password]) == user.hashed_password
        session['user_id'] = user.id
        redirect '/'
      else
        @login_error = "Incorrect username or password"
        slim :login
      end
    end

    post '/signup' do
      if params[:username] !~ /^\w+$/
        @signup_error = "Username must only contain letters, number and underscores"
      elsif !db.xquery("SELECT id FROM users WHERE username = ?;", params[:usernmae])
        @signup_error = "That username is taken"
      elsif params[:username].length < 4
        @signup_error = "Username must be at least 4 characters"
      elsif params[:password].length < 6 
        @signup_error = "Password must be at least 6 characters" 
      elsif params[:password] != params[:password_confirmation]
        @signup_error = "Password do not match!"
      end
      if @signup_error
        slim :login
      else
        user = db.xquery("INSERT INTO users (username, password_hash) values(?, ?);", params[:username], params[:password])
        session['user_id'] = user.id
        redirect '/'
      end
    end
    get '/logout' do
      session["user_id"] = nil
      redirect '/'
    end
  end
end
