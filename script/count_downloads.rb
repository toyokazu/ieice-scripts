#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
require 'yaml'
require 'tempfile'

ROOT_PATH = File.expand_path('../../',  __FILE__)
config_path = ARGV[0] || "#{ROOT_PATH}/config/count_downloads.yml"

if !File.exists?(config_path)
  puts "can not find configuration file: #{config_path}"
  exit 1
end

config = YAML.load_file(config_path)

# configuration file format example
#
# ---
# log: log.txt
# output: downloads_count.txt
# ---
#
# log.txt: the file name of the paper search system access log (tsv)
# downloads_count.txt: output file name (tsv)

class ArrayHash < Hash
  def []=(key, value)
    if self[key].class != Array
      super(key, [])
    end
    self[key] << value
  end
end

class DataParser
  class Record
    # define the line format specification of the input tsv file
  end

  def parse!
    # define how to parse the input file
  end

  def self.volume_no(volume, num)
    "#{volume.downcase}_#{num}_"
  end

  def self.volume_author(volume, authors)
    "#{volume}；#{authors.join("；")}"
  end
end

class AccessLogParser < DataParser
  class Record
    def initialize(line)
      @columns = line.gsub(/\r*\n$/, "").split("\t")
    end

    # 0: 項番  id  int8    
    # 1: 閲覧日時  log_date  varchar 10  yyyymmdd hhmmss
    # 2: ログインユーザ  user_id varchar 100 "環境変数　REMOTE_USER ID or メールアドレス"
    # 3: 会員ソサイエティ  society varchar 5 
    # 4: 閲覧ファイル名  f_name  varchar 100 
    # 5: 分冊  category  varchar 100 
    # 6: 大分類  type  varchar 100 
    # 7: リモートホストアドレス  remote_addr varchar 200 環境変数　REMOTE_ADDR
    # 8: リモートホスト名  remote_host varchar 200 環境変数　REMOTE_HOST
    # 9:  ユーザエージェント  user_agent  varchar 100 環境変数　HTTP_USER_AGENT
    # 10:  リクエストURI uri varchar 500 
    # 11:  ブラウザ  browser varchar 50  
    # 12:  クライアントOS  os  varchar 500 
    # 13:  閲覧状態  err int   "ファイル閲覧時：1 ログイン成功時：2"
    # 14:  ホスト名  host  varchar 200 ホスト名
    # 15:  アクセス種別  access  varchar 1 "・通常ユーザ認証時 ： 0 ・サイトライセンス認証時 ： 1 ・サイトライセンス認証時＋ユーザ認証 ： 2"
    # 16:  あらまし（Summary)閲覧  summary_view  varchar 1 あらまし閲覧時　：　1
    # 17:  archive閲覧フラグ table_of_contents_view  varchar 1 archive閲覧時：1
    # 18:  最新号閲覧フラグ  index_view  varchar 1 最新号閲覧時：1
    # 19:  環境変数：X-Forwarded-For x_forwarded_for varchar 200 環境変数：X-Forwarded-For

    # not used
    def id
      @columns[0]
    end

    def log_date
      @columns[1]
    end

    def user_id
      @columns[2]
    end

    def society
      @columns[3]
    end

    def f_name
      @columns[4]
    end

    def paper_id
      f_name.downcase.gsub(/\.pdf$/, "")
    end

    def category
      @columns[5]
    end

    def type
      @columns[6]
    end

    def remote_addr
      @columns[7]
    end

    def remote_host
      @columns[8]
    end

    def user_agent
      @columns[9]
    end

    def uri
      @columns[10]
    end

    def browser
      @columns[11]
    end

    def os
      @columns[12]
    end

    def err
      @columns[13]
    end

    def host
      @columns[14]
    end

    def access
      @columns[15]
    end

    def summary_view
      @columns[16]
    end

    def table_of_contents_view
      @columns[17]
    end

    def index_view
      @columns[18]
    end

    def x_forwarded_for
      @columns[19]
    end
  end

  attr_reader :records, :paper_hash, :login_hash
  def initialize(filename)
    @target_file = "#{ROOT_PATH}/files/#{filename}"

    # public attributes
    @records = []
    @paper_hash = ArrayHash.new
    @login_hash = ArrayHash.new

    # private attributes
    # used for parsing multiple lines
    @record = nil
  end

  def already_parsed?
    !@records.empty?
  end

  def parse!
    if already_parsed?
      return false
    end
    open(@target_file) do |f|
      # skip two lines (maybe changed)
      f.readline
      @lines = f.readlines
    end
    @lines.each do |line|
      @record = Record.new(line)
      @records << @record
      case @record.type
      when "type"
        @paper_hash[@record.paper_id] = @record
      when "login"
        @login_hash[@record.user_id] = @record
      end
    end
  end
end

log = AccessLogParser.new(config["log"])
log.parse!

file = open("#{ROOT_PATH}/files/#{config["output"]}", "w")
# 論文ごとの参照回数を出力
log.paper_hash.keys.sort.each do |key|
  file.puts "#{key}\t#{log.paper_hash[key].size}\r\n"
end

#log.login_hash.keys.sort.each do|key|
#  file.puts "#{key}\t#{log.login_hash[key].size}\r\n"
#end
#
file.close
