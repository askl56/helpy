# == Schema Information
#
# Table name: posts
#
#  id         :integer          not null, primary key
#  topic_id   :integer
#  user_id    :integer
#  body       :text
#  kind       :string
#  active     :boolean          default(TRUE)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  points     :integer          default(0)
#

class PostsController < ApplicationController

  before_action :authenticate_user!, :except => ['index', 'create', 'up_vote']
  #before_action :instantiate_tracker
  # after_action :send_message, :only => 'create'

  layout "clean", only: [:index]

  def index
    @topic = Topic.undeleted.ispublic.where(id: params[:topic_id]).first#.includes(:forum)
    if @topic
      @posts = @topic.posts.ispublic.active.all.chronologic.includes(:user)
      @post = @topic.posts.new
      @page_title = "#{@topic.name}"
      add_breadcrumb t(:community, default: "Community"), forums_path
      add_breadcrumb @topic.forum.name, forum_topics_path(@topic.forum)
      add_breadcrumb @topic.name
    end

    respond_to do |format|
      format.html {
        redirect_to root_path unless @topic
      }
    end
  end

  def create
    @topic = Topic.find(params[:topic_id])
    @post = Post.new(:body => params[:post][:body],
                     :topic_id => @topic.id,
                     :user_id => current_user.id,
                     :kind => params[:post][:kind],
                     :screenshots => params[:post][:screenshots])

    respond_to do |format|
      if @post.save
        format.html {
          @posts = @topic.posts.ispublic.chronologic.active
          redirect_to @topic.doc.nil? ? topic_posts_path(@topic.id) : doc_path(@topic.doc_id)
        }
        format.js {
          @posts = @topic.posts.ispublic.chronologic.active
          unless @topic.assigned_user_id.nil?
            agent = User.find(@topic.assigned_user_id)
            @tracker.event(category: "Agent: #{agent.name}", action: "User Replied", label: @topic.to_param) #TODO: Need minutes
          end
        }
      else
        format.html { render :action => "new" }
      end
    end
  end

  def up_vote
    if user_signed_in?
      @post = Post.find(params[:id])
      @post.votes.create(user_id: current_user.id)
      @topic = @post.topic
      @topic.touch
      @post.reload
    end

    respond_to do |format|
      format.js
    end
  end

  protected

  def view_causes_vote
    if logged_in?
      @topic.votes.create unless current_user.admin?
    else
      @topic.votes.create
    end
  end
end
