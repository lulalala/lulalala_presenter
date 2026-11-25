# frozen_string_literal: true
require 'active_record'
require 'action_controller/railtie'
require 'action_mailer/railtie'
require 'action_view/railtie'
require 'ostruct'
require 'jbuilder'

# config
ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')

module ActiveDecoratorTestApp
  class Application < Rails::Application
    config.secret_key_base = '"confusion" will be my epitaph.'
    config.hosts.clear # Capybara requests www.example.com, which host authorization (Rails 6+) blocks
    config.session_store :cookie_store, key: '_myapp_session'
    config.active_support.deprecation = :log
    config.eager_load = false
    # Routes are drawn inline below; with reloading on (this runs as 'development'),
    # Rails would discard them after the first request.
    if config.respond_to?(:enable_reloading=)
      config.enable_reloading = false
    else
      config.cache_classes = true
    end
    config.action_dispatch.show_exceptions = false
    config.root = File.dirname(__FILE__)

    config.action_mailer.delivery_method = :test
  end
end
ActiveDecoratorTestApp::Application.initialize!

# routes
ActiveDecoratorTestApp::Application.routes.draw do
  resources :authors, only: [:index, :show] do
    resources :books, only: [:index, :show] do
      member do
        get :error
        post :purchase
      end
    end
  end
  resources :movies, only: :show
end

# models
class Author < ActiveRecord::Base
  has_many :books
end
class Book < ActiveRecord::Base
  belongs_to :author
end
class Movie < ActiveRecord::Base
end

# helpers
module ApplicationHelper; end

# decorators
class AuthorPresenter < LulalalaPresenter::Base
  def reverse_name
    model.name.reverse
  end

  def capitalized_name
    model.name.capitalize
  end
end
class BookPresenter < LulalalaPresenter::Base
  def reverse_title
    model.title.reverse
  end

  def upcased_title
    model.title.upcase
  end

  def link
    h.link_to model.title, "#{h.request.protocol}#{h.request.host_with_port}/assets/sample.png", class: 'title'
  end

  def cover_image
    h.image_tag 'cover.png'
  end

  def error
    "ERROR"
  end
end

# decorator fake
class MoviePresenter < LulalalaPresenter::Base; end

# controllers
class ApplicationController < ActionController::Base
  self.append_view_path File.dirname(__FILE__)
end
class AuthorsController < ApplicationController
  def index
    if Author.respond_to?(:scoped)
      # ActiveRecord 3.x
      if params[:variable_type] == 'array'
        @authors = Author.all
      elsif params[:variable_type] == 'proxy'
        @authors = RelationProxy.new(Author.scoped)
      else
        @authors = Author.scoped
      end
    else
      # ActiveRecord 4.x
      if params[:variable_type] == 'array'
        @authors = Author.all.to_a
      elsif params[:variable_type] == 'proxy'
        @authors = RelationProxy.new(Author.all)
      else
        @authors = Author.all
      end
    end
  end

  def show
    @author = Author.find params[:id]
  end
end
class BooksController < ApplicationController
  class CustomError < StandardError; end

  rescue_from CustomError do
    render :error
  end

  def index
    @author = Author.find params[:author_id]
    @books  = @author.books
  end

  def show
    @book = Author.find(params[:author_id]).books.find(params[:id])
  end

  def error
    @book = Author.find(params[:author_id]).books.find(params[:id])
    raise CustomError, "error"
  end

  def purchase
    @book = Author.find(params[:author_id]).books.find(params[:id])

    @view_context_before_sending_mail = ActiveDecorator::ViewContext.current
    BookMailer.thanks(@book).deliver
    raise 'Wrong ViewContext!' if ActiveDecorator::ViewContext.current != @view_context_before_sending_mail
  end
end
class MoviesController < ApplicationController
  def show
    @movie = Movie.find params[:id]
  end
end

# mailers
class BookMailer < ActionMailer::Base
  def thanks(book)
    @book = book
    mail from: 'nobody@example.com', to: 'test@example.com', subject: 'Thanks'
  end
end

# migrations
class CreateAllTables < ActiveRecord::VERSION::MAJOR >= 5 ? ActiveRecord::Migration[5.0] : ActiveRecord::Migration
  def self.up
    create_table(:authors) {|t| t.string :name}
    create_table(:books) {|t| t.string :title; t.references :author}
    create_table(:movies) {|t| t.string :name}
  end
end

# Proxy for ActiveRecord::Relation
class RelationProxy < BasicObject
  attr_accessor :ar_relation

  def initialize(ar_relation)
    @ar_relation = ar_relation
  end

  def method_missing(method, *args, &block)
    @ar_relation.public_send(method, *args, &block)
  end
end
