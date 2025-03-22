require 'httparty'
require 'nokogiri'
require 'wicked_pdf'
require 'uri'
require 'set'
require 'tempfile'
require 'multipart/post'

class WebCrawlerService
  def initialize(root_url, user = nil)
    @root_url = root_url
    @visited_urls = Set.new
    @user = user
  end

  def perform
    # Start crawling and collect all content
    all_content = crawl(@root_url)

    if all_content.blank?
      puts "No content was retrieved from #{@root_url}"
      return
    end

    # Generate a PDF from the collected content
    pdf = generate_pdf(all_content)
    puts "pdf generated"

    # Upload the PDF to your assistant
    upload_to_assistant(pdf)
  end

  private

  def crawl(url, depth = 0, max_depth = 1)
    return '' if @visited_urls.include?(url) || depth > max_depth

    puts "Crawling: #{url}"
    @visited_urls.add(url)

    # Encode the URL to handle non-ASCII characters
    encoded_url = URI::DEFAULT_PARSER.escape(url)

    html_content = fetch_content(encoded_url)
    return '' unless html_content

    # Parse content
    parsed_content = parse_content(html_content)

    # Extract links and recursively crawl them
    doc = Nokogiri::HTML(html_content)
    links = doc.css('a[href]').map do |link|
      begin
        href = link['href']
        # Join the link with the base URL and escape it
        URI.join(encoded_url, URI::DEFAULT_PARSER.escape(href)).to_s
      rescue URI::InvalidURIError
        puts "Invalid URI encountered: #{href}"
        nil
      end
    end.compact.uniq

    links.each do |link|
      parsed_content += crawl(link, depth + 1, max_depth) if within_domain?(link)
    end

    parsed_content
  end

  def fetch_content(url)
    response = HTTParty.get(url)
    response.body if response.success?
  rescue StandardError => e
    puts "Error fetching #{url}: #{e.message}"
    nil
  end

  def parse_content(html)
    doc = Nokogiri::HTML(html)
    # Extract <p> tags or other relevant content
    doc.css('p').map(&:text).join("\n")
  end

  def within_domain?(url)
    URI.parse(url).host == URI.parse(@root_url).host
  rescue URI::InvalidURIError
    false
  end

  def generate_pdf(content)
    html_template = ApplicationController.render(
      template: 'pdf_template/pdf_template',
      layout: false,
      locals: { content: content }
    )
    WickedPdf.new.pdf_from_string(html_template)
  end

  def upload_to_assistant(pdf)
    api_key = ENV['PINECONE_API_KEY']
    assistant_name = "#{@user.pinecone_assistant_name}"
    url = "https://prod-1-data.ke.pinecone.io/assistant/files/#{assistant_name}"

    Tempfile.open(['pdf_upload', '.pdf']) do |tempfile|
      tempfile.binmode
      tempfile.write(pdf)
      tempfile.rewind

      begin
        domain = URI.parse(@root_url).host || @root_url
        file_name = "#{domain} (Extracted Website Content).pdf"
      rescue URI::InvalidURIError
        file_name = "#{@root_url} (Extracted Website Content).pdf"
      end

      payload = {
        file: Multipart::Post::UploadIO.new(tempfile, 'application/pdf', file_name)
      }

      response = HTTParty.post(
        url,
        headers: { 'Api-Key' => api_key },
        body: payload
      )

      puts "Response: #{response.body}"

      if response.success?
        puts 'PDF uploaded successfully!'
      else
        puts "Failed to upload PDF: #{response.code} - #{response.message}"
      end
    end
  end
end
