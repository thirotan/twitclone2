require 'redis'

class Timeline
  REDIS ||= Redis.new(:host => '127.0.0.1', :port => '6379', :db => 0)
  def self.page(page)
    from = (page-1)*10
    to   = (page)*10
    post_ids = REDIS.lrange("timeline", from, to)
    post_ids.map{|post_id| Post.new(post_id)}
  end
end
