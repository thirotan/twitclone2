require 'redis'

class Model
  REDIS ||= Redis.new(:host => '127.0.0.1', :port => '6379', :db => 0)
  def initialize(id)
    @id = id
  end

  def ==(other)
    @id.to_s == other.id.to_s
  end

  attr_reader :id

  def self.property(name)
    klass = self.name.downcase
    self.class_eval <<-RUBY
      def #{name}
        _#{name}
      end
      def _#{name}
        REDIS.get("#{klass}:id:" + id.to_s + ":#{name}" )
      end
      def #{name}=(val)
        REDIS.set("#{klass}:id:" + id.to_s + ":#{name}", val )
      end
    RUBY
  end
end

class User < Model

  def self.get_keys(key)
    REDIS.keys(key)
  end

  # user table の user_id を getしてる
  def self.find_by_username(username)
    if id = REDIS.get("user:username:#{username}")
      User.new(id)
    end
  end

  def self.find_by_id(id)
    if REDIS.keys("user:id:#{id}:username")
      User.new(id)
    end
  end

  def self.create(username, password)
    user_id = REDIS.incr("user:uid")
    salt = User.new_salt
    REDIS.set("user:id:#{user_id}:username", username)
    REDIS.set("user:username:#{username}", user_id)
    REDIS.set("user:id:#{user_id}:salt", salt)
    REDIS.set("user:id:#{user_id}:hashed_password", hash_pw(salt, password))
    User.new(user_id)
  end

  def self.new_users
    REDIS.lrange("users", 0, 10).map do |user_id|
      User.new(user_id)
    end
  end

  def self.new_salt
    arr = %w(a b c d e f)
    (0..6).to_a.map{ arr[rand(6)] }.join
  end

  def self.hash_pw(salt, password)
    Digest::MD5.hexdigest(salt + password)
  end

  property :username
  property :salt
  property :hashed_password


  def posts(page=1)
    from, to = (page-1)*10, page*10
    REDIS.lrange("user:id:#{id}:posts", from, to).map do |post_id|
      Post.new(post_id)
    end
  end

  def timeline(page=1)
    from, to = (page-1)*10, page*10
    REDIS.lrange("user:id:#{id}:timeline", from, to).map do |post_id|
      Post.new(post_id)
    end
  end

  def mentions(page=1)
    from, to = (page-1)*10, page*10
    REDIS.lrange("user:id:#{id}:mentions", from, to).map do |post_id|
      Post.new(post_id)
    end
  end

  def add_post(post)
    REDIS.lpush("user:id:#{id}:posts", post.id)
    REDIS.lpush("user:id:#{id}:timeline", post.id)
  end

  def add_timeline_past(post)
    REDIS.lpush("user:id:#{id}:timeline", post.id)
  end

  def add_mention(post)
    REDIS.lpush("user:id:#{id}:mentions", post.id)
  end

  def follow(user)
    return if user == self
    REDIS.sadd("user:id:#{id}:followees", user.id)
    user.add_follower(self)
  end

  def stop_following(user)
    REDIS.srem("user:id:#{id}:followees", user.id)
    user.remove_follower(self)
  end

  def following?(user)
    REDIS.sismember("user:id#{id}:followees", user.id)
  end

  def followers
    REDIS.smembers("user:id:#{id}:followers").map do |user_id|
      User.new(user_id)
    end
  end

  def followees
    REDIS.smembers("user:id:#{id}:followees").map do |user_id|
      User.new(user_id)
    end
  end

  protected
  def add_follower(user)
    REDIS.sadd("user:id:#{id}:followers", user.id)
  end

  def remove_follower(user)
    REDIS.srem("user:id:#{id}:followers", user.id)
  end
end

class Post < Model
  def self.create(user, content)
    post_id = REDIS.incr("post:uid")
    post = Post.new(post_id)
    post.content = content
    post.user_id = user.id
    post.created_at = Time.now.to_s
    post.user.add_post(post)
    REDIS.lpush("timeline", post_id)
    post.user.followers.each do |follower|
      follower.add_timeline_post(post)
    end
    content.scan(/@\w+/).each do |mention|
      if user = User.find_by_username(mention[1..-1])
        user.add_mention(post)
      end
    end 
  end

  property :content
  property :user_id
  property :created_at 
 
  def created_at
    if _created_at
      Time.parse(_created_at)
    end
  end
  
  def user
    User.new(user_id)
  end

  #post dbから user_idを検索して、 user nameを getしてる
  def self.username(id)
    user_id = REDIS.get("post:id:#{id}:user_id")
    REDIS.get("user:id:#{user_id}:username")
  end

end
