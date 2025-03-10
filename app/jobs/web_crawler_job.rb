class WebCrawlerJob < ApplicationJob
  queue_as :default

  def perform(website_url, user_id = nil)
    user = User.find_by(id: user_id)
    WebCrawlerService.new(website_url, user).perform
  end
end