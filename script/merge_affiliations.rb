#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
require 'yaml'
require 'tempfile'

ROOT_PATH = File.expand_path('../../',  __FILE__)
config_path = ARGV[0] || "#{ROOT_PATH}/config/files.yml"

if !File.exists?(config_path)
  puts "can not find configuration file: #{config_path}"
  exit 1
end

config = YAML.load_file(config_path)

# configuration file format example
#
# ---
# submission: submission.txt
# search:
#   ja: search_j.txt
#   en: search_je.txt
# output: final_output.txt
# ---
#
# submission.txt: input file name of paper submission system data (tsv)
# search_j.txt: input file name of paper search system data (japanese, tsv)
# search_e.txt: input file name of paper search system data (english, tsv)

class ArrayHash < Hash
  def []=(key, value)
    if self[key].nil?
      super(key, value)
    else
      if self[key].class != Array
        super(key, [self[key]])
      end
      self[key] << value
    end
  end

  def has_multiple_values?(key)
    self[key].class == Array
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

class SubmissionSystemDataParser < DataParser
  class Record
    def initialize(line)
      @columns = line.gsub(/\r*\n/, "").split("\t")
    end

    # 0: id1　　　　受付番号の西暦部分
    # 1: id2　　　　受付番号4ケタ
    # 2: soccode  特集号コード
    # 3: title_j     　和文タイトル
    # 4: title_e 　　　英文タイトル
    # 5: volume1　掲載号
    # 6: inputnum 著者順番
    # 7: name_j　　著者名（日本語）
    # 8: name_e 　著者名（英語）
    # 9: membernum　会員番号
    # 10: orgcode　　機関コード
    # 11: name_j　　　機関コード名（日本語）
    # 12: name_e　　 機関コード名（英語）

    def id1
      @columns[0]
    end

    def id2
      @columns[1]
    end

    def soccode
      @columns[2]
    end

    def title_j
      @columns[3]
    end

    def title_e
      @columns[4]
    end

    def volume1
      @columns[5]
    end

    def inputnum
      @columns[6]
    end

    def authorname_j
      @authorname_j ||= @columns[7].gsub("　", " ")
    end

    def authorname_e
      @authorname_e ||= @columns[8].gsub("　", " ")
    end

    def membernum
      @columns[9]
    end

    def orgcode
      @columns[10]
    end

    def orgname_j
      @columns[11]
    end

    def orgname_e
      @columns[12]
    end

    # profiles appended after the author's name
    def authorprof_j
      # （member_number）＠affiliation
      "#{membernum.empty? ? "" : "（#{membernum}）"}＠#{orgname_j}"
    end

    def authorprof_e
      # （member_number）＠affiliation
      "#{membernum.empty? ? "" : "（#{membernum}）"}＠#{orgname_e}"
    end
  end

  attr_reader :title_j_hash, :volume_j_hash, :title_e_hash, :volume_e_hash
  attr_reader :empty_authors_j_count, :empty_authors_e_count
  def initialize(filename)
    @target_file = "#{ROOT_PATH}/files/#{filename}"

    # public attributes
    @records = ArrayHash.new
    @title_j_hash = ArrayHash.new
    @volume_j_hash = ArrayHash.new
    @title_e_hash = ArrayHash.new
    @volume_e_hash = ArrayHash.new

    # public statistics attributes
    @empty_authors_j_count = 0
    @empty_authors_e_count = 0

    # private attributes
    # used for parsing multiple lines
    @record = nil
    @title_j = nil
    @title_e = nil
    @volume_no = nil
    @authors_j = []
    @authors_e = []
    @authorprofs_j = []
    @authorprofs_e = []
  end

  def already_parsed?
    !@records.empty?
  end

  def has_previous_parsed_entry?
    !@authors_j.empty? || !@authors_e.empty?
  end

  def paper
    {
      :title_j => @title_j,
      :title_e => @title_e,
      :authors_j => @authors_j,
      :authors_e => @authors_e,
      :volume_no => @volume_no,
      :authorprofs_j => @authorprofs_j,
      :authorprofs_e => @authorprofs_e,
      :record => @record
    }
  end

  def save_previous_paper
    if has_previous_parsed_entry?
      @title_j_hash[@title_j] = paper
      @volume_j_hash[self.class.volume_author(@volume_no, @authors_j)] = paper
      @title_e_hash[@title_e] = paper
      @volume_e_hash[self.class.volume_author(@volume_no, @authors_e)] = paper
      @authors_j = []
      @authors_e = []
      @authorprofs_j = []
      @authorprofs_e = []
    end
  end

  def add_author
    # for debug
    if @record.authorname_j == ""
      @empty_authors_j_count += 1
      # $stderr.puts "authorname_j is empty! {#{@title_j}, #{@title_e}, #{@volume}}"
    end
    @authors_j << @record.authorname_j
    # for debug
    if @record.authorname_e == ""
      @empty_authors_e_count += 1
      # $stderr.puts "authorname_e is empty! {#{@title_j}, #{@title_e}, #{@volume}}"
    end
    @authors_e << @record.authorname_e
    @authorprofs_j << @record.authorprof_j
    @authorprofs_e << @record.authorprof_e
  end

  def parse!
    if already_parsed?
      return false
    end
    open(@target_file) do |f|
      # skip two lines (maybe changed)
      f.readline
      f.readline
      @lines = f.readlines
    end
    @lines.each do |line|
      @record = Record.new(line)
      @records[@record.id1] = @record
      if @record.inputnum == "1" # if this is the first author
        save_previous_paper
        @title_j = @record.title_j
        @title_e = @record.title_e
        @record.volume1 =~ /Vol.(\w+\d+\-\w+),No.(\d+),/
        @volume_no = self.class.volume_no($1, $2)
        add_author
      else
        add_author
      end
    end
    save_previous_paper
    return true
  end
end

class PaperSearchSystemDataParser < DataParser
  class Record
    attr_reader :authors

    def initialize(line)
      @columns = line.gsub(/\r*\n$/, "").split("\t")
      @authors = @columns[7].gsub("　", " ").split("＠")
    end

    # 0: id, 文献ID
    # 1: vol, 巻 (年, ソサイエティ) Vol
    # 2: num, 号 Num
    # 3: s_page, 開始ページ番号
    # 4: e_page, 終了ページ番号
    # 5: date, 発行年月
    # 6: title, タイトル【検索用】
    # 7: author, 著者【検索用】
    # 8: abstract, 概要【検索用】
    # 9: keyword, キーワード（全角カンマ区切り）【検索用】
    # 10: special, 特集号名
    # 11: category1, 論文種別 (論文, レター)
    # 12: category2, 専門分野分類コード（大項目）
    # 13: category3, 専門分野分類名（大項目）※目次の見出しに利用
    # 14: disp_title, タイトル【表示用】
    # 15: disp_author, 著者名【表示用】
    # 16: disp_abstract, 概要【表示用】
    # 17: disp_keyword, キーワード（全角カンマ区切り）【表示用】
    # 18: err_fname, 正誤Web PDF
    # 19: err_comm, 正誤内容
    # 20: nodisp_comm, 非表示
    # 21: delflg, 削除
    # 22: mmflg, MM情報
    # 23: l_auth_pdf, レター著者PDF
    # 24: l_auth_link, レター著者内容
    # 25: err_1, 訂正元ファイル名
    # 26: err_2, 訂正先ファイル名
    # 27: recommend, 推薦論文
    # 28: 目次脚注正誤PDF

    def id
      @columns[0]
    end

    def vol
      @columns[1]
    end

    def num
      @columns[2]
    end

    def s_page
      @columns[3]
    end

    def e_page
      @columns[4]
    end

    def date
      @columns[5]
    end

    def title
      @columns[6]
    end

    def author
      @columns[7]
    end

    def abstract
      @columns[8]
    end

    def keyword
      @columns[9]
    end

    def special
      @columns[10]
    end

    def category1
      @columns[11]
    end

    def category2
      @columns[12]
    end

    def category3
      @columns[13]
    end

    def disp_title
      @columns[14]
    end
    
    def disp_author
      @columns[15]
    end

    def disp_abstract
      @columns[16]
    end

    def disp_keyword
      @columns[17]
    end

    def err_fname
      @columns[18]
    end
    
    def err_comm
      @columns[19]
    end

    def nodisp_comm
      @columns[20]
    end

    def delflg
      @columns[21]
    end

    def mmflg
      @columns[22]
    end

    def l_auth_pdf
      @columns[23]
    end

    def l_auth_link
      @columns[24]
    end

    def err_1
      @columns[25]
    end
    
    def err_2
      @columns[26]
    end

    def recommend
      @columns[27]
    end
  end

  attr_reader :records, :title_hash, :volume_hash

  def initialize(filenames)
    @target_files = filenames

    # public attributes
    @records = {}
    @title_hash = {}
    @volume_hash = {}
    @target_files.keys.sort.each do |key|
      @records[key] = ArrayHash.new
      @title_hash[key] = ArrayHash.new
      @volume_hash[key] = ArrayHash.new
    end

    # private attributes
    @record = nil
    @lines = {}
  end

  def parse!
    if already_parsed?
      return false
    end
    @target_files.each do |lang, filename|
      open("#{ROOT_PATH}/files/#{filename}") do |f|
        # skip two lines (maybe changed)
        f.readline
        f.readline
        @lines[lang] = f.readlines
      end
    end
    @target_files.keys.each do |lang|
      @lines[lang].each do |line|
        @record = Record.new(line)
        volume_number = self.class.volume_no(@record.vol, @record.num)
        authors = @record.disp_author.gsub("　", " ").split("＠")
        paper = {
          :title => @record.disp_title,
          :authors => authors,
          :volume_no => volume_number,
          :record => @record
        }
        @records[lang][@record.id] = paper
        @title_hash[lang][@record.disp_title] = paper
        @volume_hash[lang][self.class.volume_author(volume_number, authors)] = paper
      end
    end
    return true
  end

  def already_parsed?
    @records.keys.any? {|key| !@records[key].empty?}
  end
end

def merge_authors_and_affiliations(authors, affiliations = [])
  result = []
  authors.each_with_index do |author, i|
    result << "#{author}#{affiliations[i]}"
  end
  result.join("；")
end

CSV = ","
TSV = "\t"

# 出力データ区切り
def line_format(data, delimiter)
  case delimiter
  when CSV
      return data.join(delimiter)
  when TSV
      return data.join(delimiter)
  end
end

# 出力データ・フォーマット
def data_format(_lang, _record, _author, _affiliations)
  [_lang,
   _record.id,
   _record.vol,
   _record.num,
   _record.s_page,
   _record.e_page,
   _record.date,
   _record.title,
   _record.author,
   _record.abstract,
   _record.keyword,
   _record.special,
   _record.category1,
   _record.category2,
   _record.category3,
   _record.disp_title,
   merge_authors_and_affiliations(_author, _affiliations),
   _record.disp_abstract,
   _record.disp_keyword,
   _record.disp_abstract,
   _record.disp_keyword,
   _record.err_fname,
   _record.err_comm,
   _record.nodisp_comm,
   _record.delflg,
   _record.mmflg,
   _record.l_auth_pdf,
   _record.l_auth_link,
   _record.err_1,
   _record.err_2,
   _record.recommend]
end

# 備考欄フォーマット
def note_format(_paper)
  [
   _paper[:record].id1,
   _paper[:record].id2,
   _paper[:volume_no],
   _paper[:title_j],
   _paper[:title_e],
   merge_authors_and_affiliations(_paper[:authors_j], _paper[:authorprofs_j]),
   merge_authors_and_affiliations(_paper[:authors_e], _paper[:authorprofs_e]),
  ].join("｜＋｜")
end

# 完全一致 (一つの言語のみ（英語 or 日本語の初回比較で一致）)
FULL_MATCH = "FULL_MATCH"
# 完全一致 (一つの言語のみ（日本語に失敗した場合の英語のみ）)
EN_FULL_MATCH = "EN_FULL_MATCH"
# 巻号，著者リスト一致
VOL_AUTHOR_MATCH = "VOL_AUTHOR_MATCH"
# 巻号，著者リスト一致
EN_VOL_AUTHOR_MATCH = "EN_VOL_AUTHOR_MATCH"
# 巻号，著者リスト一致（ただし，一つの巻号に複数存在）
# タイトルの辞書順で一致候補を備考欄に提示
MULTI_VOL_AUTHOR_MATCH = "MULTI_VOL_AUTHOR_MATCH"
# マッチしないもの．10年前までの範囲ではおそらくタイトル，著者名に微妙に修正が入っている
# 巻号，タイトルの辞書順で一致候補を備考欄に提示
NOT_MATCHED = "NOT_MATCHED"

def notes(result, note)
  [result, note, "\r\n"]
end

def line_output(_file, _lang, _paper, _authorprofs, _result, _note)
  # 単一言語 (日本語 or 英語) の場合
  _file.puts line_format(["1",
                          *data_format(_lang, _paper[:record], _paper[:authors], _authorprofs),
                          notes(_result, _note)
                         ], TSV)
end

def line_outputs(_file, _lang1, _paper1, _authorprofs1, _lang2, _paper2, _authorprofs2, _result, _note)
  # 複数言語 (日本語＋英語) の場合
  _file.puts line_format(["2",
                          *data_format(_lang1, _paper1[:record], _paper1[:authors], _authorprofs1),
                          *data_format(_lang2, _paper2[:record], _paper2[:authors], _authorprofs2),
                         notes(_result, _note)
                         ], TSV)
end

# main routine

# example usage of Parser classes
#
#subsys = SubmissionSystemDataParser.new("toukou-2010-utf8.txt")
#subsys.parse!
#
#searchsys_j = PaperSearchSystemDataParser.new("ja" => "output_j.txt")
#searchsys_j.parse!
#
#searchsys_j_e = PaperSearchSystemDataParser.new("ja" => "output_j.txt", "en" => "output_je.txt")
#searchsys_j_e.parse!
#
#searchsys_e =  PaperSearchSystemDataParser.new("en" => "output_e.txt")
#searchsys_e.parse!

subsys = SubmissionSystemDataParser.new(config["submission"])
subsys.parse!

searchsys = PaperSearchSystemDataParser.new(config["search"])
searchsys.parse!

subsys_volume_j = subsys.volume_j_hash
subsys_volume_e = subsys.volume_e_hash
searchsys_records = searchsys.records
searchsys_volume = searchsys.volume_hash

# 出力ファイル (temporary file)
file = Tempfile.new(config["output"], "#{ROOT_PATH}/files")

# 出力ロジック
if searchsys_volume["ja"].nil?
  # 英文論文誌の場合 (searchsys 側で "ja" 指定がない場合)
  searchsys_volume["en"].keys.sort.each do |key|
    if subsys_volume_e[key].nil?
      # 英語でマッチしなかった場合
      if searchsys_volume["en"].has_multiple_values?(key)
        # かつ，複数エントリある場合はソートして出力 NOT_MATCHED
        searchsys_volume["en"][key].sort {|a, b| a[:title] <=> b[:title]}.each do |pe|
          # title でソートして提示
          line_output(file, "en", pe, [], NOT_MATCHED, "sorry, no hints")
          next
        end
      else
        pe = searchsys_volume["en"][key]
        # 単一エントリの場合は単純に出力 NOT_MATCHED
        line_output(file, "en", pe, [], NOT_MATCHED, "sorry, no hints")
        next
      end
    elsif searchsys_volume["en"].has_multiple_values?(key)
      # 英語でマッチした場合で，
      # 複数マッチした場合は，対応する投稿システムデータの候補を備考欄に提示
      searchsys_volume["en"][key].sort {|a, b| a[:title] <=> b[:title]}.each_with_index do |pe, i|
        sp = subsys_volume_e[key].sort {|a, b| a[:title_e] <=> b[:title_e]}
        authorprofs_e = []
        # 著者数が複数の場合は，所属も埋めておく
        if pe[:authors].size > 1
          authorprofs_e = sp[i][:authorprofs_e]
        end
        # 英語のみ
        line_output(file, "en", pe, authorprofs_e, MULTI_VOL_AUTHOR_MATCH, note_format(sp[i]))
        next
      end
    else
      # 英語でマッチして，対象が単一エントリの場合は，タイトルもチェック
      pe = searchsys_volume["en"][key]
      if subsys_volume_e[key][:title_e] == pe[:title]
        # タイトルも一致した場合
        # 英語のみ
        line_output(file, "en", pe, subsys_volume_e[key][:authorprofs_e], FULL_MATCH, note_format(subsys_volume_e[key]))
        next
      else
        # タイトルは一致しなかった場合
        # 英語のみ
        line_output(file, "en", pe, subsys_volume_e[key][:authorprofs_e], VOL_AUTHOR_MATCH, note_format(subsys_volume_e[key]))
        next
      end
    end
  end
else
  # 和文論文誌の場合 ("ja" がある場合)
  searchsys_volume["ja"].keys.sort.each do |key|
    if subsys_volume_j[key].nil?
      # 日本語でマッチしなかった場合
      if searchsys_volume["ja"].has_multiple_values?(key)
        # かつ，複数エントリある場合は単純に出力 NOT_MATCHED
        searchsys_volume["ja"][key].sort {|a, b| a[:title] <=> b[:title]}.each do |pj|
          # title でソートして提示
          if searchsys_records["en"].nil?
            # 日本語のみの場合
            line_output(file, "ja", pj, [], NOT_MATCHED, "sorry, no hints")
            next
          else
            # 英語ありの場合
            pe = searchsys_records["en"][pj[:record].id]
            # for debug
            # puts "id = #{pj[:record].id}"
            if pe.nil?
              line_output(file, "ja", pj, [], NOT_MATCHED, "sorry, no hints")
            else
              line_outputs(file, "ja", pj, [], "en", pe, [], NOT_MATCHED, "sorry, no hints")
            end
            next
          end
        end
      else
        pj = searchsys_volume["ja"][key]
        if searchsys_records["en"].nil?
          # 英語データがない場合
          line_output(file, "ja", pj, [], NOT_MATCHED, "sorry, no hints")
          next
        end
        pe = searchsys_records["en"][pj[:record].id]
        # for debug
        # puts "id = #{pj[:record].id}"
        if pe.nil?
          # 英語エントリがない場合は
          # 英語でもマッチなしとして，ヒントなしで出力 NOT_MATCHED
          # 英語エントリがないので，日本語のみ
          line_output(file, "ja", pj, [], NOT_MATCHED, "sorry, no hints")
          next
        end
        k = DataParser.volume_author(pe[:volume_no], pe[:authors])
        # 日本語でマッチせず，対象が単一エントリの場合は，英語でも確認
        if subsys_volume_e[k].nil?
          # 英語でもマッチしなかった場合ヒントなしで出力 NOT_MATCHED
          line_outputs(file, "ja", pj, [], "en", pe, [], NOT_MATCHED, "sorry, no hints")
        else
          # 英語でマッチした場合タイトルもチェック
          if subsys_volume_e[k][:title_e] == pe[:title]
            # 英語タイトルもマッチした場合は EN_FULL_MATCH で日本語情報を併記して出力
            line_outputs(file, "ja", pj, subsys_volume_e[k][:authorprofs_j], "en", pe, subsys_volume_e[k][:authorprofs_e], EN_FULL_MATCH, note_format(subsys_volume_e[k]))
          else
            # 英語タイトルはマッチしなかった場合は EN_VOL_AUTHOR_MATCH
            line_outputs(file, "ja", pj, subsys_volume_j[k][:authorprofs_j], "en", pe, subsys_volume_e[k][:authorprofs_e], EN_VOL_AUTHOR_MATCH, note_format(subsys_volume_e[k]))
          end
        end
      end
    elsif searchsys_volume["ja"].has_multiple_values?(key)
      # 日本語ではマッチしたが，
      # 複数マッチした場合は，対応する投稿システムデータの候補を備考欄に提示
      searchsys_volume["ja"][key].sort {|a, b| a[:title] <=> b[:title]}.each_with_index do |pj, i|
        sp = subsys_volume_j[key].sort {|a, b| a[:title_j] <=> b[:title_j]}
        authorprofs_j = []
        authorprofs_e = []
        # 著者数が複数の場合は，所属も埋めておくか？
        if pj[:authors].size > 1
          authorprofs_j = sp[i][:authorprofs_j]
          authorprofs_e = sp[i][:authorprofs_e]
        end
        if searchsys_records["en"].nil?
          # 日本語のみの場合
          line_output(file, "ja", pj, authorprofs_j, MULTI_VOL_AUTHOR_MATCH, note_format(sp[i]))
          next
        else
          # 英語ありの場合
          pe = searchsys_records["en"][pj[:record].id]
          if pe.nil?
            # 英語の対応するエントリがない場合は
            line_output(file, "ja", pj, authorprofs_j, MULTI_VOL_AUTHOR_MATCH, note_format(sp[i]))
          else
            line_outputs(file, "ja", pj, authorprofs_j, "en", pe, authorprofs_e, MULTI_VOL_AUTHOR_MATCH, note_format(sp[i]))
          end
          next
        end
      end
    else
      # 日本語でマッチして，対象が単一エントリの場合は，タイトルもチェック
      pj = searchsys_volume["ja"][key]
      if subsys_volume_j[key][:title_j] == pj[:title]
        # タイトルも一致した場合
        if searchsys_records["en"].nil?
          # 日本語のみの場合
          line_output(file, "ja", pj, subsys_volume_j[key][:authorprofs_j], FULL_MATCH, note_format(subsys_volume_j[key]))
          next
        else
          # 英語ありの場合
          pe = searchsys_records["en"][pj[:record].id]
          if pe.nil?
            # 英語の対応するエントリなしの場合
            line_output(file, "ja", pj, subsys_volume_j[key][:authorprofs_j], FULL_MATCH, note_format(subsys_volume_j[key]))
          else
            line_outputs(file, "ja", pj, subsys_volume_j[key][:authorprofs_j], "en", pe, subsys_volume_j[key][:authorprofs_e], FULL_MATCH, note_format(subsys_volume_j[key]))
          end
          next
        end
      else
        # タイトルは一致しなかった場合
        if searchsys_records["en"].nil?
          # 日本語のみの場合
          line_output(file, "ja", pj, subsys_volume_j[key][:authorprofs_j], VOL_AUTHOR_MATCH, note_format(subsys_volume_j[key]))
          next
        else
          # 英語ありの場合
          pe = searchsys_records["en"][pj[:record].id]
          if pe.nil?
            # 英語の対応するエントリなしの場合
            line_output(file, "ja", pj, subsys_volume_j[key][:authorprofs_j], VOL_AUTHOR_MATCH, note_format(subsys_volume_j[key]))
          else
            line_outputs(file, "ja", pj, subsys_volume_j[key][:authorprofs_j], "en", pe, subsys_volume_j[key][:authorprofs_e], VOL_AUTHOR_MATCH, note_format(subsys_volume_j[key]))
          end
          next
        end
      end
    end
  end
end

file.close

# for debug
# system("cp #{file.path} #{ROOT_PATH}/files/#{config["output"]}")

# sort lines by paper id
system("sort -o #{ROOT_PATH}/files/#{config["output"]} -k 4,6 #{file.path}")

=begin
# the followings are statistics of source data
subsys = SubmissionSystemDataParser.new("toukou-2010-utf8.txt")
subsys.parse!
$stderr.puts "empty author_name_e count: #{subsys.empty_authors_e_count}"

searchsys = PaperSearchSystemDataParser.new("output_j.txt")
searchsys.parse!
$stderr.puts "Submission System: volume_j_hash.keys.size = #{subsys.volume_j_hash.keys.size}"
$stderr.puts "Submission System: volume_e_hash.keys.size = #{subsys.volume_e_hash.keys.size}"
$stderr.puts "Paper Search System: volume_hash.keys.size = #{searchsys.volume_hash.keys.size}"

$stderr.puts "-----src-jp-----"
$stderr.puts subsys.volume_j_hash.keys.join("\n")
$stderr.puts "-----src-en-----"
$stderr.puts subsys.volume_e_hash.keys.join("\n")
$stderr.puts "-----dst-----"
$stderr.puts searchsys.volume_hash.keys.join("\n")
$stderr.puts "-----"

# check source title duplication
$stderr.puts "----source title duplications-----"
count = 0
subsys.title_j_hash.each do |key, value|
  if value.class == Array
    count += value.size
    $stderr.puts "#{key}: #{value}"
  end
end
$stdout.puts "source title duplication: #{count}"

# check destination title duplication
$stderr.puts "----destination title duplications-----"
count = 0
searchsys.title_hash.each do |key, value|
  if value.class == Array
    count += value.size
    $stderr.puts "#{key}: #{value}"
  end
end
$stdout.puts "destination title duplication: #{count}"

# check source volume_author duplication
$stderr.puts "----source volume_author duplications-----"
count = 0
uniq_count = 0
subsys.volume_j_hash.each do |key, value|
  if value.class == Array
    count += value.size
    $stderr.puts "#{key}: #{value}"
    # unique count of v[:title]
    uniq_count += value.map {|v| v[:title_j]}.uniq.size
  end
end
$stdout.puts "source volume_author duplication: #{count}"
$stdout.puts "source volume_author duplication unique count: #{uniq_count}"

# check destination volume_author duplication
$stderr.puts "----destination volume_author duplications-----"
count = 0
uniq_count = 0
searchsys.volume_hash.each do |key, value|
  if value.class == Array
    count += value.size
    $stderr.puts "#{key}: #{value}"
    # unique count of v[:title]
    uniq_count += value.map {|v| v[:title]}.uniq.size
  end
end
$stdout.puts "destination volume_author duplication: #{count}"
$stdout.puts "destination volume_author duplication unique count: #{uniq_count}"

# match with title (14)
count = 0
subsys.title_j_hash.keys.each do |key|
  if !dst_title_hash[key].nil?
    count += 1
  end
end
$stdout.puts "match with title: #{count}"

# match with journal vol and number and authors
count = 0
unmatched = []
subsys.volume_j_hash.keys.each do |key|
  if !search_sys_parser.volume_hash[key].nil?
    count += 1
    if subsys_parser.volume_j_hash[key][:title_j] != searchsys_parser.volume_hash[key][:title]
      $stderr.puts "#{key}: #{subsys_parser.volume_hash[key]} #{searchsys_parser.volume_hash[key]}"
    end
  else
    unmatched << subsys_parser.volume_j_hash[key]
  end
end
$stdout.puts "match with volume_author: #{count}"
$stderr.puts "---ummatched---"
$stderr.puts unmatched.join("\n")
$stderr.puts "---ummatched---"
=end
