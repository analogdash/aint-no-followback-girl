config = {
  consumer_key:    "INSERT KEY HERE",
  consumer_secret: "INSERT SECRET HERE",
}

client = Twitter::REST::Client.new(config)

targetuser = "gem"

me = client.user(targetuser)
TargetedUser.create(id_str: me.attrs[:id_str])
User.create(
      id_str: me.attrs[:id_str],
      name: me.attrs[:name],
      screen_name: me.attrs[:screen_name],
      location: me.attrs[:location],
      description: me.attrs[:description],
      url: me.attrs[:url],
      protected: me.attrs[:protected],
      followers_count: me.attrs[:followers_count],
      friends_count: me.attrs[:friends_count],
      listed_count: me.attrs[:listed_count],
      created_at: me.attrs[:created_at],
      favourites_count: me.attrs[:favourites_count],
      utc_offset: me.attrs[:utc_offset],
      time_zone: me.attrs[:time_zone],
      geo_enabled: me.attrs[:geo_enabled],
      verified: me.attrs[:verified],
      statuses_count: me.attrs[:statuses_count],
      default_profile: me.attrs[:default_profile],
      default_profile_image: me.attrs[:default_profile_image]
  )

$t1 = Time.now

next_cursor = -1
while next_cursor != 0
  puts "NOW DOING ITERATION WITH NEXT CURSOR AT #{next_cursor.to_s}"
  sleep(60)
  followerlist = client.follower_ids(targetuser, {cursor: next_cursor})
  next_cursor = followerlist.attrs[:next_cursor]
  followerlist.attrs[:ids].each do |t|
  	unless Follower.where(id_str: me.attrs[:id_str], follower_id_str: t.to_s).exists?
      Follower.create(
        id_str: me.attrs[:id_str],
        follower_id_str: t.to_s,
        scraped: false)
    end
  end
end

$t2 = Time.now

followlist = Follower.where(scraped: false, scrape_attempts: 0).take(100)
while followlist.length != 0
  followlist.each {|f| f.update_attributes(scrape_attempts: 1)}
  sleep (3)
  userlist = client.users(followlist.map {|f| f.follower_id_str.to_i})
  userlist.each do |u|
    unless User.where(id_str: u.attrs[:id_str]).exists?
      Follower.where(follower_id_str: u.attrs[:id_str])[0].update_attributes(scraped: true) ### DONT FORGET TO ADD FOLLOWEE/TARGET USER ID
      User.create(
        id_str: u.attrs[:id_str],
        name: u.attrs[:name],
        screen_name: u.attrs[:screen_name],
        location: u.attrs[:location],
        description: u.attrs[:description],
        url: u.attrs[:url],
        protected: u.attrs[:protected],
        followers_count: u.attrs[:followers_count],
        friends_count: u.attrs[:friends_count],
        listed_count: u.attrs[:listed_count],
        created_at: u.attrs[:created_at],
        favourites_count: u.attrs[:favourites_count],
        utc_offset: u.attrs[:utc_offset],
        time_zone: u.attrs[:time_zone],
        geo_enabled: u.attrs[:geo_enabled],
        verified: u.attrs[:verified],
        statuses_count: u.attrs[:statuses_count],
        default_profile: u.attrs[:default_profile],
        default_profile_image: u.attrs[:default_profile_image])
      unless u.attrs[:status] == nil
        unless u.attrs[:status][:source] == (nil || "")
          doc = Nokogiri::HTML(u.attrs[:status][:source])
          source_name = doc.css("a")[0].text
          source_url = doc.css("a")[0]["href"]
        end
        thistweet = Tweet.create(
          user_id_str: u.attrs[:id_str],
          created_at: u.attrs[:status][:created_at],
          tweet_id_str: u.attrs[:status][:id_str],
          text: u.attrs[:status][:text],
          in_reply_to_status_id_str: u.attrs[:status][:in_reply_to_status_id_str],
          retweet_count: u.attrs[:status][:retweet_count],
          favorite_count: u.attrs[:status][:favorite_count],
          possibly_sensitive: u.attrs[:status][:possibly_sensitive],
          lang: u.attrs[:status][:lang],
          source_url: source_url,
          source_name: source_name,
          has_hashtag: false,
          has_url: true)
        u.attrs[:status][:entities][:hashtags].each do |h|
          Hashtag.create(
            tweet_id_str: u.attrs[:id_str],
            text: h[:text],
            index: h[:indices][0],
            endex: h[:indices][1])
          thistweet.update_attributes(has_hashtag: true)
        end
        u.attrs[:status][:entities][:urls].each do |h|
          ExtUrl.create(
            tweet_id_str: u.attrs[:id_str],
            url: h[:expanded_url],
            index: h[:indices][0],
            endex: h[:indices][1])
          thistweet.update_attributes(has_url: true)
        end
      end
    end
  end
  followlist = Follower.where(scraped: false, scrape_attempts: 0).take(100)
end

$t3 = Time.now

puts "GETTING FOLLOWERLIST TOOK #{(($t2-$t1)/60.0).to_s} MINUTES"
puts "GETTING USERLIST TOOK #{(($t3-$t2)/60.0).to_s} MINUTES"
puts "TOTAL OPERATION TIME WAS #{(($t3-$t1)/60.0).to_s} MINUTES"
puts "ALL DONE"

=begin

User.delete_all
Follower.delete_all
TargetedUser.delete_all
Tweet.delete_all
Hashtag.delete_all
ExtUrl.delete_all


=end
