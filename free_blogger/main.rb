#!/usr/bin/env ruby
require 'pry'
require "capybara"
require "kramdown"
require "nokogiri"
require "retriable"
require "csv"
require "yaml"
$config = YAML.load_file(File.expand_path('../.config.yml', __FILE__))

include Capybara::DSL

class FreeBlogger
  attr_reader  :id, :login_id, :password, :title, :articles, :i2i_tag

  def initialize(id)
    @id       = id
    blog      = self.class.get_blog_info(@id)
    @login_id = blog["ログインID"]
    @password = blog["ブログパス"]
    @title    = blog["ブログ名"]
    @url      = blog["ブログURL"]
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
    Retriable.retriable { click_link '新規投稿' }
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

  def get_i2i_tag
    visit        $config['url']['i2i']
    fill_in      'loginId', with: $config['i2i']['user_id']
    fill_in      'loginPw', with: $config['i2i']['password']
    click_button 'ログイン'
    click_link   'i2i WEBパーツ'
    click_link   '管理画面'
    find(:xpath, "//img[contains(@alt, '新規パーツ作成')]").click
    fill_in      'title',   with: @title
    click_button '作成する'
    fill_in      'title',   with: @title
    fill_in      'url',     with: @url
    all('input[type=checkbox]').each { |checkbox| checkbox.click }
    click_button '確認へ進む'
    click_button '登録する'
    click_button 'タグ発行画面'
    @i2i_tag = find('#tag').value
  end

  def configure_blog
    self.sign_in
    Retriable.retriable { find(".navsettings a").click }
    find(:xpath, "//img[contains(@alt, 'ブログ設定')]").click
    find("#blog_ext__common_header_0").click
    click_button "ブログ設定の変更"

    Retriable.retriable { find(".navsettings a").click }
    find(:xpath, "//img[contains(@alt, '記事設定')]").click
    find("#article_setting__accept_comment_0").click
    find("#article_setting__affiliate_link_0").click
    f = open(File.expand_path('../ping_list.txt', __FILE__))
    fill_in 'article_setting__update_ping', with: f.read
    click_button "保存"

    Retriable.retriable { find(".navsettings a").click }
    find(:xpath, "//img[contains(@alt, '広告設定')]").click
    find("#blog__ad_types_0").click
    find("#blog_ext__force_ad_status_2").click
    find("#blog_ext__viasearch_ad_2").click
    click_button "保存"

    Retriable.retriable { find(".navdesign a").click }
    within("#submenu_pc") { click_link "コンテンツ" }
    find(:xpath, "//li[contains(@data-dispatch_name, 'article_search')]/span[contains(@class, 'remove')]").click
    find(:xpath, "//li[contains(@data-dispatch_name, 'blogclick')]/span[contains(@class, 'remove')]").click
    find(:xpath, "//li[contains(@data-dispatch_name, 'blopita')]/span[contains(@class, 'remove')]").click
    find(:xpath, "//li[contains(@data-dispatch_name, 'recent_comment')]/span[contains(@class, 'remove')]").click
    find(:xpath, "//li[contains(@data-dispatch_name, 'rss_affiliate')]/span[contains(@class, 'remove')]").click
    all(:xpath, "//li[contains(@data-dispatch_name, 'free')]")[0].
      drag_to all(:xpath, "//li[contains(@data-dispatch_name, 'rdf_summary')]")[1]
    find(:xpath, "//li[contains(@data-dispatch_name, 'rdf_summary')]/span[contains(@class, 'remove')]").click
    find(:xpath, "//li[contains(@data-dispatch_name, 'free')]/a[contains(@class, 'edit')]").click
    within_frame( find("#content_iframe")) do
       fill_in "content__title", with: "アクセス解析"
       fill_in "content_free__text", with: "accesssssss"
       click_button "保存"
    end
    find(".close").click
    click_button "保存"
  end
end

blogger = FreeBlogger.new(ARGV[0])
blogger.prepare_capybara
blogger.sign_in
blogger.submit_in_batch

sleep
