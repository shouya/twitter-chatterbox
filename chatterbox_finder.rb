require 'date'
require 'set'
require_relative 'twitter_api'


@checked = {}
@not_chinese = Set.new
@protected = Set.new
@chatterboxes = {}

@data_file = './data/saved.data'

@starter = 'meowdan'

MAX_DEPTH = 1

@today = Date.today

# you can use your presonal twitter api base
@api = TwitterApi.new(:api_base => 'http://api.twitter.com/1')

def get_user_by_id(id)
    return @api.users.show(:user_id => id)
end

def check_chinese_circle(user)
    return true if user['lang'] == 'zh-cn'
    return true if user['lang'] == 'en' && user['time_zone'] == 'Beijing'
    # The following rule will contains hongkong users, right?
    return true if user['lang'] == 'en' && user['utc_offset'] == 28800
    #return true if check_chinese(user['name'])
    return false
end

def determine_chatter(user)
    return false unless user['followers_count'] > 100 # has 100+ followers
    return false unless user['followers_count'] < 800 # has <800 followers
    return false unless user['statuses_count'] > 20000 # 20000+ tweets
    return false unless user['listed_count'] > 3 # enough focused as 3+ lists
    return false unless \
        (@today - Date.parse(user['status']['created_at'])) < 3
                 # last updated less than 3 days

    daily_tweets = \
        user['statuses_count'].to_f / (@today - Date.parse(user['created_at']))
    return false unless daily_tweets > 60 # daily tweets > 60
    follow_back_rate = user['followers_count'] / user['friends_count'].to_f
    return false unless follow_back_rate > 0.1 # has not enough focus, omit
    return false unless follow_back_rate < 3 # has enough audiences, pass

    return true
end

def check_one(id, depth)
    return if depth == MAX_DEPTH

    @api.friends.ids(:user_id => id)['ids'].each do |id|
        next if @checked.has_key?(id)
        next if @not_chinese.include?(id)
        next if @protected.include?(id)
        
        user = get_user_by_id(id)

        puts "Checking..." + user['screen_name']
        if user['protected']
            @protected << id
            next
        end

        unless check_chinese_circle(user)
            @not_chinese << id
            next
        end

        if determine_chatter(user)
            # would you like to print it out?
            puts 'Chatterbox:' + user['screen_name']
            @chatterboxes[id] = user
        end

        @checked[id] = {
            :screen_name => user['screen_name'],
            :check_time => @today
        }

        check_one(id, depth + 1)
    end
end

def store_data
    tmp = {
        :checked => @checked,
        :not_chinese => @not_chinese,
        :protected => @protected,
        :chatterboxes => @chatterboxes
    }
    File.open(@data_file, 'w') do |f|
        f.write(Marshal.dump(tmp))
    end
end

def load_data
    return unless File.exist? @data_file
    tmp = Marshal.load(File.open(@data_file).read)
    @checked = tmp[:checked]
    @not_chinese = tmp[:not_chinese]
    @protected = tmp[:protected]
    @chatterboxes = tmp[:chatterboxes]
end

def start_from_someone(screen_name)
    user_id = @api.users.show(:screen_name => screen_name)['id']
    check_one(user_id, 0)
end

def main
    load_data
    begin
        start_from_someone(@starter)
    rescue HTTPException => e
        res = e.http_response
        if res.code.to_i == 400 and res['X-Ratelimit-Remaining'] == '0'
            puts "Congrats, your api's rate limit is exceeded."
            puts "Try to change api or wait until %s." % \
                Time.at(res['X-Ratelimit-Reset']).to_s
        end
    ensure
        store_data
    end
end

if __FILE__ == $0
    main
end

