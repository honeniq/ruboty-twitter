require "active_support/core_ext/object/try"
require "mem"
require "twitter"

module Ruboty
  module Adapters
    class Twitter < Base
      include Mem

      env :TWITTER_ACCESS_TOKEN, "Twitter access token"
      env :TWITTER_ACCESS_TOKEN_SECRET, "Twitter access token secret"
      env :TWITTER_AUTO_FOLLOW_BACK, "Pass 1 to follow back followers (optional)", optional: true
      env :TWITTER_CONSUMER_KEY, "Twitter consumer key (a.k.a. API key)"
      env :TWITTER_CONSUMER_SECRET, "Twitter consumer secret (a.k.a. API secret)"

      def run
        Ruboty.logger.debug("#{self.class}##{__method__} started")
        abortable
        wait(10)
        listen
        Ruboty.logger.debug("#{self.class}##{__method__} finished")
      end

      def say(message)
        client.update(message[:body], in_reply_to_status_id: message[:original][:tweet].try(:id))
      end

      private

      def enabled_to_auto_follow_back?
        ENV["TWITTER_AUTO_FOLLOW_BACK"] == "1"
      end

      def listen
        # ToDo: auto follow back
        loop do
          mentions = client.mentions(:since_id => since_id)
          mentions.each do | tweet |
            Ruboty.logger.debug("#{tweet.user.screen_name} tweeted #{tweet.text.inspect}")
            robot.receive(
              body: tweet.text,
              from: tweet.user.screen_name,
              tweet: tweet
            )
            robot.brain.data['since_id'] = tweet.id
          end
          wait(polling_cycle)
        end
      end

      def client
        ::Twitter::REST::Client.new do |config|
          config.consumer_key        = ENV["TWITTER_CONSUMER_KEY"]
          config.consumer_secret     = ENV["TWITTER_CONSUMER_SECRET"]
          config.access_token        = ENV["TWITTER_ACCESS_TOKEN"]
          config.access_token_secret = ENV["TWITTER_ACCESS_TOKEN_SECRET"]
        end
      end
      memoize :client

      def stream
        ::Twitter::Streaming::Client.new do |config|
          config.consumer_key        = ENV["TWITTER_CONSUMER_KEY"]
          config.consumer_secret     = ENV["TWITTER_CONSUMER_SECRET"]
          config.access_token        = ENV["TWITTER_ACCESS_TOKEN"]
          config.access_token_secret = ENV["TWITTER_ACCESS_TOKEN_SECRET"]
        end
      end
      memoize :stream

      def wait(second)
        Ruboty.logger.debug(format("Waiting for %d seconds", second))
        sleep(second)
      end

      def since_id
        # ToDo: メンションがひとつも無い場合を考慮する
        brain.data['since_id'] ||= client.mentions[0].id
      end

      def polling_cycle
        ENV.has_key?("POLLING_CYCLE") ? ENV["POLLING_CYCLE"].to_i : 20
      end
      memoize :polling_cycle

      def abortable
        Thread.abort_on_exception = true
      end

      def brain
        robot.brain
      end
      memoize :brain
    end
  end
end
