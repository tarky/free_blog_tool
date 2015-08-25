#!/usr/local/bin/ruby
# -*- coding: utf-8 -*-

IP       = '0.0.0.0'             #IPは変えること
PORT     = '8080'                #port は1024以下にしないこと、する場合はroot権限
DOC      =  './'

require 'webrick'
opts  = {
  :BindAddress    => IP,
  :Port           => PORT,
  :DocumentRoot   => DOC,
}

srv = WEBrick::HTTPServer.new(opts)

#コマンドラインでCtrl+Cした場合止めるイベントハンドラ
Signal.trap(:INT){ srv.shutdown}

#サーバースタート
srv.start
