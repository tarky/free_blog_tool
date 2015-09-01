#!/usr/bin/env ruby
require 'pry'
require "capybara"
require "kramdown"
require "nokogiri"
require "csv"
require "yaml"
$config = YAML.load_file(File.expand_path('../.config.yml', __FILE__))

include Capybara::DSL

class FreeBlogger
  attr_reader  :id, :login_id, :password, :title, :articles

  def initialize(id)
    @id       = id
    blog      = self.class.get_blog_info(@id)
    @login_id = blog["ログインID"]
    @password = blog["ブログパス"]
    @title    = blog["ブログ名"]
    @articles = self.class.get_articles
  end

  def self.get_blog_info(id)
    csv = CSV.parse(
      open($config["blog_info_path"], "rb:Shift_JIS:UTF-8").read, headers: true
    )
    csv.find { |row| row["ブログNo."] == id }
  end

  def self.get_articles
    f = open('articles.md')
    html =  Kramdown::Document.new(f.read, input: 'GFM', auto_ids: false).to_html
    f.close

    i = 0
    usable = false
    html.each_line.inject([]) do |arr, line|
      if line.include? '<h1>'
        if usable
          i += 1
        else
          usable = true
        end
        arr[i] = ""
      end
      usable = false if line.include? '<style'
      arr[i] << line if usable
      arr
    end
  end

  def prepare_capybara
    Capybara.register_driver :selenium_chrome do |app|
      Capybara::Selenium::Driver.new(app, :browser => :chrome)
    end
    Capybara.default_driver = :selenium_chrome
  end

  def sign_in
    visit        'http://blog.seesaa.jp'
    click_link   'ログイン'
    fill_in      'email',    with: @login_id
    fill_in      'password', with: @password
    click_button 'サインイン'
    click_link   @title
  end

  def submit(title, body)
    begin
      accept_alert { find(:xpath, "//img[contains(@src, 'editor_on.gif')]").click }
    rescue
    end
    fill_in      'article__subject', with: title
    find('#mce_53').click
    find('#mce_138').set(body)
    click_button 'OK'
    first('.input-save').click
    begin
      click_link '新規投稿'
    rescue ::Selenium::WebDriver::Error::StaleElementReferenceError => e
      puts 'out error'
      retry
    end
  end

  def submit_in_batch
    @articles.each_with_index do |article, i|
      doc =  Nokogiri::HTML(article).css('body')
      title =  doc.css('h1').inner_text
      doc.css('h1').remove
      doc.css('p')[0].remove if i == 0
      body =  doc.inner_html
      submit( title, body )
    end
  end
end

blogger = FreeBlogger.new(ARGV[0])
blogger.prepare_capybara
blogger.sign_in
blogger.submit_in_batch

sleep
