config = {
  consumer_key:    "INSERT KEY HERE",
  consumer_secret: "INSERT SECRET HERE",
}

client = Twitter::REST::Client.new(config)

targetuser = "gem"

t1 = Time.now

$scrape = client.user_timeline(targetuser,{count: 200, include_rts: true})
tweets = $scrape

while tweets.length > 0
	tweets.each do |t|
		unless Tweet.where(tweet_id_str: t.id.to_s).exists?
			source_name = source_url = "none"
			unless t.source.to_s == ""
				doc = Nokogiri::HTML(t.source)
				source_name = doc.css("a")[0].text
				source_url = doc.css("a")[0]["href"]
			end
			this = Tweet.create(
				user_id_str: t.user.id.to_s,
				created_at: t.created_at,
				tweet_id_str: t.id.to_s,
				text: t.text,
				in_reply_to_status_id_str: t.in_reply_to_status_id.to_s,
				retweet_count: t.retweet_count,
				favorite_count: t.favorite_count,
				possibly_sensitive: t.possibly_sensitive?,
				lang: t.lang,
				source_url: source_url,
				source_name: source_name)
			t.hashtags.each do |h|
				Hashtag.create(
					tweet_id_str: t.id.to_s,
					text: h.text,
					index: h.indices[0],
					endex: h.indices[1])
				this.update_attributes(has_hashtag: true)
			end
			t.urls.each do |h|
				ExtUrl.create(
					tweet_id_str: t.id.to_s,
					url: h.expanded_url.to_s,
					index: h.indices[0],
					endex: h.indices[1])
				this.update_attributes(has_url: true)
			end
		end
	end
	$scrape = client.user_timeline(targetuser,{count: 200, include_rts: true, max_id: tweets.last.id - 1})
	tweets = $scrape
end
t2 = Time.now

puts "PROCESS TOOK #{(($t2-$t1)/60.0).to_s} MINUTES"
puts "TOTAL OF #{Tweet.count.to_s} TWEETS GRABBED"
