class WebCrawlerJob < ApplicationJob
  queue_as :default

  def perform(website_url)
    WebCrawlerService.new(website_url).perform
  end
end